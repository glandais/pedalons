package fr.pedalons.repository.notification;

import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.enums.NotificationEventStatus;
import fr.pedalons.enums.NotificationType;
import io.hypersistence.tsid.TSID;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class NotificationEventRepository implements PanacheRepository<NotificationEventEntry> {

  /**
   * Queues an event unless one with the same dedup key already exists. Returns whether a row was
   * written.
   *
   * <p>Native on purpose. A JPA {@code persist} of a duplicate would fail at flush with a constraint
   * violation, and that failure would belong to the caller's transaction — the one cancelling the
   * ride. {@code ON CONFLICT DO NOTHING} makes the duplicate a no-op instead, race included.
   */
  public boolean insertIfAbsent(
      Long domainId,
      NotificationType type,
      String dedupKey,
      String payloadJson,
      @Nullable Long actorId,
      @Nullable Long teamId,
      Instant now) {
    return insertIfAbsent(domainId, type, dedupKey, payloadJson, actorId, teamId, now, now);
  }

  /** As above, not claimed before {@code notBefore} — a delay in which later edits fold in. */
  public boolean insertIfAbsent(
      Long domainId,
      NotificationType type,
      String dedupKey,
      String payloadJson,
      @Nullable Long actorId,
      @Nullable Long teamId,
      Instant now,
      Instant notBefore) {
    return getEntityManager()
            .createNativeQuery(
                """
                insert into notification_events
                  (id, domain_id, type, status, dedup_key, payload, actor_id, team_id, attempts,
                   created_at, next_attempt_at, version)
                values
                  (:id, :domainId, :type, :status, :dedupKey, cast(:payload as jsonb), :actorId,
                   :teamId, 0, :now, :notBefore, 0)
                on conflict (dedup_key) do nothing
                """)
            .setParameter("id", TSID.Factory.getTsid().toLong())
            .setParameter("domainId", domainId)
            .setParameter("type", type.name())
            .setParameter("status", NotificationEventStatus.PENDING.name())
            .setParameter("dedupKey", dedupKey)
            .setParameter("payload", payloadJson)
            .setParameter("actorId", actorId)
            .setParameter("teamId", teamId)
            .setParameter("now", Timestamp.from(now))
            .setParameter("notBefore", Timestamp.from(notBefore))
            .executeUpdate()
        == 1;
  }

  /**
   * Locks, for the caller's transaction, the PENDING event holding {@code dedupKey}. Returns
   * whether there was one.
   *
   * <p>For an event that coalesces while pending: an edit that folds into a waiting row holds it
   * until it commits, so the dispatcher ({@code skip locked}) cannot claim it and read the subject
   * before the edit is visible. No PENDING row means the key was given back by a claim in between
   * — the caller inserts again. See docs/LEDGER_*.md NOTIF-10.
   */
  public boolean lockPending(String dedupKey) {
    return !getEntityManager()
        .createNativeQuery(
            """
            select id from notification_events
            where dedup_key = :dedupKey and status = 'PENDING'
            for update
            """)
        .setParameter("dedupKey", dedupKey)
        .getResultList()
        .isEmpty();
  }

  /**
   * Head of the due queue, locked for this transaction. An event backing off after a failure is not
   * due, so the drain loop moves on to the next one rather than retrying it at once. Same two-part claim as {@code
   * UserExportRepository}: {@code skip locked} for throughput, the compare-and-set in {@link #claim}
   * for correctness.
   */
  public @Nullable Long findNextDueIdSkipLocked(Instant now) {
    Object id =
        getEntityManager()
            .createNativeQuery(
                """
                select id from notification_events
                where status = 'PENDING' and next_attempt_at <= :now
                order by next_attempt_at
                limit 1
                for update skip locked
                """)
            .setParameter("now", Timestamp.from(now))
            .getResultStream()
            .findFirst()
            .orElse(null);
    return id == null ? null : ((Number) id).longValue();
  }

  /** Compare-and-set from PENDING to PROCESSING. True if this caller won the row. */
  public boolean claim(Long id, Instant now) {
    return update(
            "status = ?1, startedAt = ?2, attempts = attempts + 1 where id = ?3 and status = ?4",
            NotificationEventStatus.PROCESSING,
            now,
            id,
            NotificationEventStatus.PENDING)
        == 1;
  }

  /** Events claimed but never finished — a crash between claim and completion. */
  public List<NotificationEventEntry> findStuck(Instant startedBefore) {
    return list(
        "status = ?1 and startedAt < ?2", NotificationEventStatus.PROCESSING, startedBefore);
  }

  /** Ids of the events older than the retention window, oldest first, at most {@code limit}. */
  public List<Long> findIdsCreatedBefore(Instant cutoff, int limit) {
    return getEntityManager()
        .createQuery(
            "select e.id from NotificationEventEntry e where e.createdAt < :cutoff"
                + " order by e.createdAt",
            Long.class)
        .setParameter("cutoff", cutoff)
        .setMaxResults(limit)
        .getResultList();
  }
}
