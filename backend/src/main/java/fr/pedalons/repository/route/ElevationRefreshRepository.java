package fr.pedalons.repository.route;

import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.dto.admin.ElevationRefreshKind;
import io.hypersistence.tsid.TSID;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

/**
 * The queue of tracks waiting for their HD elevation (docs/LEDGER_*.md API-131). Every write is a
 * native upsert or a conditional update keyed on the revision the caller worked on, so a save made
 * while the worker was computing is never overwritten by the worker's bookkeeping.
 */
@ApplicationScoped
public class ElevationRefreshRepository implements PanacheRepository<ElevationRefresh> {

  /** A request taken by the worker, detached from the claiming transaction. */
  public record Claim(Long id, Long routeId, Long teamId, long sourceRevision, int attempts) {}

  /**
   * Asks for the HD recompute of a route's track, or postpones the pending request: the next save
   * within {@code quiet} pushes the due time back, never beyond {@code maxWait} after the first
   * one. A new request forgets the failures of the previous one. The lease, if the worker holds
   * one, is kept: it ends by itself, or when the worker realigns the row. A row that is not in an open
   * window any more (failed, given up, or older than {@code maxWait}) starts a new one, so a
   * long-forgotten {@code first_requested_at} never makes the request due at once.
   *
   * @param sourceRevision the {@code file_id} of the route's original GPX
   */
  public void requestForRoute(
      Long routeId, long sourceRevision, Instant now, Duration quiet, Duration maxWait) {
    request("route_id", routeId, sourceRevision, now, quiet, maxWait);
  }

  /**
   * As {@link #requestForRoute}, for a GPX-tool preview.
   *
   * @param sourceRevision the preview's {@code files_revision}
   */
  public void requestForPreview(
      Long previewId, long sourceRevision, Instant now, Duration quiet, Duration maxWait) {
    request("preview_id", previewId, sourceRevision, now, quiet, maxWait);
  }

  /** {@code column} is one of two constants of this class, never user input. */
  private void request(
      String column,
      Long targetId,
      long sourceRevision,
      Instant now,
      Duration quiet,
      Duration maxWait) {
    getEntityManager()
        .createNativeQuery(
            """
            insert into elevation_refresh
              (id, {col}, source_revision, first_requested_at, due_at, attempts)
            values (:id, :targetId, :revision, :now, :due, 0)
            on conflict ({col}) where {col} is not null do update set
              source_revision = excluded.source_revision,
              first_requested_at = case
                when elevation_refresh.attempts > 0
                  or elevation_refresh.first_requested_at + make_interval(secs => :maxWait)
                       <= excluded.first_requested_at
                then excluded.first_requested_at
                else elevation_refresh.first_requested_at end,
              due_at = least(excluded.due_at,
                             case
                               when elevation_refresh.attempts > 0
                                 or elevation_refresh.first_requested_at
                                      + make_interval(secs => :maxWait)
                                      <= excluded.first_requested_at
                               then excluded.first_requested_at
                               else elevation_refresh.first_requested_at end
                               + make_interval(secs => :maxWait)),
              attempts = 0,
              last_error = null
            """
                .replace("{col}", column))
        .setParameter("id", TSID.Factory.getTsid().toLong())
        .setParameter("targetId", targetId)
        .setParameter("revision", sourceRevision)
        .setParameter("now", Timestamp.from(now))
        .setParameter("due", Timestamp.from(now.plus(quiet)))
        .setParameter("maxWait", (double) maxWait.toSeconds())
        .executeUpdate();
  }

  /** A preview request taken by the worker, detached from the claiming transaction. */
  public record PreviewClaim(Long id, Long previewId, long sourceRevision, int attempts) {}

  /**
   * Takes the next due route request and leases it, in the caller's transaction: {@code FOR UPDATE
   * SKIP LOCKED}, so the second backend of a rolling deploy takes another one. Requests that used
   * up their attempts stay in the table for diagnosis and are not taken again.
   */
  public Optional<Claim> claimNextRoute(Instant now, Instant lease, int maxAttempts) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                """
                select e.id, e.route_id, t.team_id, e.source_revision, e.attempts
                  from elevation_refresh e
                  join team_entities t on t.id = e.route_id
                  join teams tm on tm.id = t.team_id
                  where e.route_id is not null
                    and t.deleted = false
                    and tm.deleted = false
                    and e.attempts < :maxAttempts
                    and e.due_at <= :now
                    and (e.claimed_until is null or e.claimed_until < :now)
                  order by e.due_at, e.id
                  limit 1
                  for update of e skip locked
                """)
            .setParameter("now", Timestamp.from(now))
            .setParameter("maxAttempts", maxAttempts)
            .getResultList();
    if (rows.isEmpty()) {
      return Optional.empty();
    }
    Object[] r = rows.getFirst();
    long id = ((Number) r[0]).longValue();
    update("claimedUntil = ?1 where id = ?2", lease, id);
    return Optional.of(
        new Claim(
            id,
            ((Number) r[1]).longValue(),
            ((Number) r[2]).longValue(),
            ((Number) r[3]).longValue(),
            ((Number) r[4]).intValue()));
  }

  /**
   * As {@link #claimNextRoute}, for the next due GPX-tool preview request. A preview is hard
   * deleted, with its request, so there is no deleted flag to join on.
   */
  public Optional<PreviewClaim> claimNextPreview(Instant now, Instant lease, int maxAttempts) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                """
                select e.id, e.preview_id, e.source_revision, e.attempts
                  from elevation_refresh e
                  join gpx_previews p on p.id = e.preview_id
                  where e.preview_id is not null
                    and e.attempts < :maxAttempts
                    and e.due_at <= :now
                    and (e.claimed_until is null or e.claimed_until < :now)
                  order by e.due_at, e.id
                  limit 1
                  for update of e skip locked
                """)
            .setParameter("now", Timestamp.from(now))
            .setParameter("maxAttempts", maxAttempts)
            .getResultList();
    if (rows.isEmpty()) {
      return Optional.empty();
    }
    Object[] r = rows.getFirst();
    long id = ((Number) r[0]).longValue();
    update("claimedUntil = ?1 where id = ?2", lease, id);
    return Optional.of(
        new PreviewClaim(
            id,
            ((Number) r[1]).longValue(),
            ((Number) r[2]).longValue(),
            ((Number) r[3]).intValue()));
  }

  /**
   * Records a failed attempt of the claimed revision and releases the lease. When the request has
   * moved on to another revision in the meantime (a save), only the lease is released: the new
   * request keeps its own due time and attempts.
   */
  public boolean recordFailure(Claim claim, Instant dueAt, @Nullable String error) {
    return recordFailure(claim.id(), claim.sourceRevision(), dueAt, error);
  }

  /** As {@link #recordFailure(Claim, Instant, String)}, for a request of either kind. */
  public boolean recordFailure(
      Long id, long sourceRevision, Instant dueAt, @Nullable String error) {
    long updated =
        update(
            "attempts = attempts + 1, dueAt = ?1, lastError = ?2, claimedUntil = null"
                + " where id = ?3 and sourceRevision = ?4",
            dueAt,
            error,
            id,
            sourceRevision);
    if (updated == 0) {
      update("claimedUntil = null where id = ?1", id);
    }
    return updated > 0;
  }

  /**
   * Points the request at the revision now current and makes it due {@code dueAt}, lease released,
   * in a new window started {@code now}. Used when the track changed while the worker was
   * computing the previous one.
   */
  public void realign(Long id, long currentRevision, Instant now, Instant dueAt) {
    update(
        "sourceRevision = ?1, dueAt = ?2, firstRequestedAt = ?3, attempts = 0, lastError = null,"
            + " claimedUntil = null where id = ?4",
        currentRevision,
        dueAt,
        now,
        id);
  }

  /** Removes the request, unless a save has asked for another revision since. */
  public boolean deleteIfRevision(Long id, long sourceRevision) {
    return delete("id = ?1 and sourceRevision = ?2", id, sourceRevision) > 0;
  }

  public Optional<ElevationRefresh> findByPreviewId(Long previewId) {
    return find("preview.id", previewId).firstResultOptional();
  }

  public Optional<ElevationRefresh> findByRouteId(Long routeId) {
    return find("route.id", routeId).firstResultOptional();
  }

  // ------------------------------------------------------------------ admin retry

  /** An abandoned request (attempts used up), with what the admin needs to find its target. */
  public record AbandonedRefresh(
      Long id,
      ElevationRefreshKind kind,
      Long targetId,
      @Nullable String teamSlug,
      @Nullable String routeSlug,
      @Nullable String previewPublicId,
      int attempts,
      @Nullable String lastError,
      Instant firstRequestedAt) {}

  /**
   * The abandoned requests of a domain, oldest first: routes through their team's domain (neither
   * the route nor the team deleted), previews through their own domain.
   */
  public List<AbandonedRefresh> findAbandoned(
      Long domainId, int maxAttempts, int limit, @Nullable ElevationRefreshKind kind) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                ABANDONED
                    + """
                    select id, kind, target_id, team_slug, route_slug, preview_public_id,
                           attempts, last_error, first_requested_at
                      from abandoned
                      where (:kind = 'ALL' or kind = :kind)
                      order by first_requested_at, id
                      limit :limit
                    """)
            .setParameter("domainId", domainId)
            .setParameter("maxAttempts", maxAttempts)
            .setParameter("kind", kind == null ? "ALL" : kind.name())
            .setParameter("limit", limit)
            .getResultList();
    return rows.stream()
        .map(
            r ->
                new AbandonedRefresh(
                    ((Number) r[0]).longValue(),
                    ElevationRefreshKind.valueOf((String) r[1]),
                    ((Number) r[2]).longValue(),
                    (String) r[3],
                    (String) r[4],
                    r[5] == null ? null : r[5].toString(),
                    ((Number) r[6]).intValue(),
                    (String) r[7],
                    toInstant(r[8])))
        .toList();
  }

  /** A timestamptz column read natively: Hibernate hands back an {@link Instant}, older drivers a {@link Timestamp}. */
  private static Instant toInstant(Object value) {
    return value instanceof Timestamp ts ? ts.toInstant() : (Instant) value;
  }

  /** How many abandoned requests {@link #findAbandoned} would list without its limit. */
  public int countAbandoned(Long domainId, int maxAttempts, @Nullable ElevationRefreshKind kind) {
    return ((Number)
            getEntityManager()
                .createNativeQuery(
                    ABANDONED
                        + """
                        select count(*) from abandoned
                          where (:kind = 'ALL' or kind = :kind)
                        """)
                .setParameter("domainId", domainId)
                .setParameter("maxAttempts", maxAttempts)
                .setParameter("kind", kind == null ? "ALL" : kind.name())
                .getSingleResult())
        .intValue();
  }

  private static final String ABANDONED =
      """
      with abandoned as (
        select e.id, 'ROUTE' as kind, e.route_id as target_id, tm.slug as team_slug,
               t.slug as route_slug, cast(null as uuid) as preview_public_id,
               e.attempts, e.last_error, e.first_requested_at
          from elevation_refresh e
          join team_entities t on t.id = e.route_id
          join teams tm on tm.id = t.team_id
          where e.route_id is not null
            and e.attempts >= :maxAttempts
            and t.deleted = false
            and tm.deleted = false
            and tm.domain_id = :domainId
            and t.elevation_state = 'FAST'
        union all
        select e.id, 'PREVIEW', e.preview_id, null, null, p.public_id,
               e.attempts, e.last_error, e.first_requested_at
          from elevation_refresh e
          join gpx_previews p on p.id = e.preview_id
          where e.preview_id is not null
            and e.attempts >= :maxAttempts
            and p.domain_id = :domainId
            and p.elevation_state = 'FAST'
      )
      """;

  /**
   * Starts the given abandoned requests again, in one statement: attempts and error forgotten,
   * lease released, a new window opened at {@code now}, and the due times spread {@code spacing}
   * apart in the order of the oldest request. Idempotent — only requests still at {@code
   * maxAttempts} are touched — and the targets go back to PENDING in the same transaction.
   *
   * @return the number of requests restarted
   */
  public int resetAbandoned(List<Long> ids, Instant now, Duration spacing, int maxAttempts) {
    int reset =
        getEntityManager()
            .createNativeQuery(
                """
                update elevation_refresh e
                  set attempts = 0, last_error = null, claimed_until = null,
                      first_requested_at = :now,
                      due_at = cast(:now as timestamptz) + n.rn * make_interval(secs => :spacing)
                  from (select id, row_number() over (order by first_requested_at, id) - 1 as rn
                          from elevation_refresh
                          where id in (:ids) and attempts >= :maxAttempts) n
                  where e.id = n.id and e.attempts >= :maxAttempts
                """)
            .setParameter("now", Timestamp.from(now))
            .setParameter("spacing", (double) spacing.toSeconds())
            .setParameter("ids", ids)
            .setParameter("maxAttempts", maxAttempts)
            .executeUpdate();
    // The requests just restarted (attempts back to 0, their window opened now) name the targets
    getEntityManager()
        .createNativeQuery(
            """
            update team_entities set elevation_state = 'PENDING'
              where id in (select route_id from elevation_refresh
                             where id in (:ids) and route_id is not null
                               and attempts = 0)
              and elevation_state = 'FAST'
            """)
        .setParameter("ids", ids)
        .executeUpdate();
    getEntityManager()
        .createNativeQuery(
            """
            update gpx_previews set elevation_state = 'PENDING'
              where id in (select preview_id from elevation_refresh
                             where id in (:ids) and preview_id is not null
                               and attempts = 0)
              and elevation_state = 'FAST'
            """)
        .setParameter("ids", ids)
        .executeUpdate();
    return reset;
  }
}
