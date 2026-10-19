package fr.pedalons.repository.route;

import fr.pedalons.domain.route.SurfaceRefresh;
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
 * The queue of tracks waiting for their surface (docs/LEDGER_*.md WEB-100, C1b), copied from {@code
 * ElevationRefreshRepository} less its admin retry. Every write is a
 * native upsert or a conditional update keyed on the revision the caller worked on, so a save made
 * while the worker was computing is never overwritten by the worker's bookkeeping.
 */
@ApplicationScoped
public class SurfaceRefreshRepository implements PanacheRepository<SurfaceRefresh> {

  /** A request taken by the worker, detached from the claiming transaction. */
  public record Claim(Long id, Long routeId, long sourceRevision, int attempts) {}

  /**
   * Asks for the surface of a route's track, or postpones the pending request: the next save
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
            insert into surface_refresh
              (id, {col}, source_revision, first_requested_at, due_at, attempts)
            values (:id, :targetId, :revision, :now, :due, 0)
            on conflict ({col}) where {col} is not null do update set
              source_revision = excluded.source_revision,
              first_requested_at = case
                when surface_refresh.attempts > 0
                  or surface_refresh.first_requested_at + make_interval(secs => :maxWait)
                       <= excluded.first_requested_at
                then excluded.first_requested_at
                else surface_refresh.first_requested_at end,
              due_at = least(excluded.due_at,
                             case
                               when surface_refresh.attempts > 0
                                 or surface_refresh.first_requested_at
                                      + make_interval(secs => :maxWait)
                                      <= excluded.first_requested_at
                               then excluded.first_requested_at
                               else surface_refresh.first_requested_at end
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
                select e.id, e.route_id, e.source_revision, e.attempts
                  from surface_refresh e
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
            ((Number) r[3]).intValue()));
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
                  from surface_refresh e
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

  public Optional<SurfaceRefresh> findByPreviewId(Long previewId) {
    return find("preview.id", previewId).firstResultOptional();
  }

  public Optional<SurfaceRefresh> findByRouteId(Long routeId) {
    return find("route.id", routeId).firstResultOptional();
  }

  /**
   * The HD catch-up of a preview moved it to another {@code files_revision}: a request still
   * waiting for the old one follows, so that the surface computed for it is not computed twice.
   *
   * @return how many requests were moved (0 or 1)
   */
  public int forwardPreviewRevision(Long previewId, long from, long to) {
    return update(
        "sourceRevision = ?1 where preview.id = ?2 and sourceRevision = ?3", to, previewId, from);
  }

  /** Whether a computation is still to come for a route: queued and not given up. */
  public boolean isPendingForRoute(Long routeId, int maxAttempts) {
    return count("route.id = ?1 and attempts < ?2", routeId, maxAttempts) > 0;
  }

  /** As {@link #isPendingForRoute}, for a preview. */
  public boolean isPendingForPreview(Long previewId, int maxAttempts) {
    return count("preview.id = ?1 and attempts < ?2", previewId, maxAttempts) > 0;
  }
}
