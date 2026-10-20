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
              (id, {col}, source_revision, first_requested_at, due_at, attempts, backfill)
            values (:id, :targetId, :revision, :now, :due, 0, false)
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
              last_error = null,
              backfill = false
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
   * up their attempts stay in the table for diagnosis and are not taken again. {@code backfill}
   * selects the kind: the requests of the catch-up (C1c) or the normal ones.
   */
  public Optional<Claim> claimNextRoute(
      Instant now, Instant lease, int maxAttempts, boolean backfill) {
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
                    and e.backfill = :backfill
                    and e.attempts < :maxAttempts
                    and e.due_at <= :now
                    and (e.claimed_until is null or e.claimed_until < :now)
                  order by e.due_at, e.id
                  limit 1
                  for update of e skip locked
                """)
            .setParameter("now", Timestamp.from(now))
            .setParameter("maxAttempts", maxAttempts)
            .setParameter("backfill", backfill)
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
  public Optional<PreviewClaim> claimNextPreview(
      Instant now, Instant lease, int maxAttempts, boolean backfill) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                """
                select e.id, e.preview_id, e.source_revision, e.attempts
                  from surface_refresh e
                  join gpx_previews p on p.id = e.preview_id
                  where e.preview_id is not null
                    and e.backfill = :backfill
                    and e.attempts < :maxAttempts
                    and e.due_at <= :now
                    and (e.claimed_until is null or e.claimed_until < :now)
                  order by e.due_at, e.id
                  limit 1
                  for update of e skip locked
                """)
            .setParameter("now", Timestamp.from(now))
            .setParameter("maxAttempts", maxAttempts)
            .setParameter("backfill", backfill)
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

  // ------------------------------------------------------------------ catch-up (C1c)

  /** Serialises the catch-up across backends: transaction-scoped, released at commit. */
  public void lockBackfill() {
    getEntityManager()
        .createNativeQuery("select 1 from pg_advisory_xact_lock(hashtextextended(:key, 0))")
        .setParameter("key", "surface-backfill")
        .getSingleResult();
  }

  /**
   * What the catch-up has queued and not done: the provider calls it still holds (a request weighs
   * one call per slice of track), and the first free due time.
   */
  public record BackfillBudget(int pending, @Nullable Instant nextFree) {}

  /**
   * The catch-up requests still to come (not given up, target alive), weighted by their number of
   * provider calls, and the first due time free after the ones not yet tried.
   */
  public BackfillBudget backfillBudget(double spacingSeconds, double sliceMetres, int maxAttempts) {
    Object[] row =
        (Object[])
            getEntityManager()
                .createNativeQuery(
                    """
                    select coalesce(sum(greatest(1, ceil(coalesce(t.distance, p.distance, 0) / :slice))), 0),
                           max(e.due_at + make_interval(secs =>
                                 :spacing * greatest(1, ceil(coalesce(t.distance, p.distance, 0) / :slice))))
                             filter (where e.attempts = 0)
                      from surface_refresh e
                      left join team_entities t on t.id = e.route_id
                      left join teams tm on tm.id = t.team_id
                      left join gpx_previews p on p.id = e.preview_id
                     where e.backfill
                       and e.attempts < :maxAttempts
                       and (e.preview_id is not null or (t.deleted = false and tm.deleted = false))
                    """)
                .setParameter("spacing", spacingSeconds)
                .setParameter("slice", sliceMetres)
                .setParameter("maxAttempts", maxAttempts)
                .getSingleResult();
    Object next = row[1];
    Instant nextFree = next == null ? null : toInstant(next);
    return new BackfillBudget(((Number) row[0]).intValue(), nextFree);
  }

  private static Instant toInstant(Object value) {
    if (value instanceof Instant i) {
      return i;
    }
    if (value instanceof java.time.OffsetDateTime o) {
      return o.toInstant();
    }
    if (value instanceof java.time.LocalDateTime l) {
      return l.atZone(java.time.ZoneId.systemDefault()).toInstant();
    }
    return ((java.util.Date) value).toInstant();
  }

  /** A track the catch-up may queue: its id, its length (the weight), the revision to ask for. */
  public record BackfillCandidate(Long id, double distance, long sourceRevision) {}

  /** Routes without a surface nor any request, most recent first. */
  public List<BackfillCandidate> findBackfillRoutes(int limit) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                """
                with candidates as (
                  select t.id, t.distance, t.created_at
                    from team_entities t
                    join teams tm on tm.id = t.team_id
                   where t.id in (select g.route_id from gpx_tracks g where g.surfaces is null)
                     and t.deleted = false
                     and tm.deleted = false
                     and not exists (select 1 from surface_refresh r where r.route_id = t.id)
                     and exists (select 1 from assets a
                                  where a.team_entity_id = t.id and a.type = 'ROUTE_ORIGINAL_GPX')
                   order by t.created_at desc, t.id desc
                   limit :limit)
                select c.id, c.distance,
                       (select a.file_id from assets a
                         where a.team_entity_id = c.id and a.type = 'ROUTE_ORIGINAL_GPX'
                         order by a.id desc limit 1)
                  from candidates c
                 order by c.created_at desc, c.id desc
                """)
            .setParameter("limit", limit)
            .getResultList();
    return candidates(rows);
  }

  /**
   * Previews without a current surface nor any request, created after {@code createdAfter}, most
   * recent first.
   */
  public List<BackfillCandidate> findBackfillPreviews(int limit, Instant createdAfter) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                """
                select p.id, p.distance, p.files_revision
                  from gpx_previews p
                 where p.files_revision is not null
                   and p.created_at > :createdAfter
                   and (p.surfaces is null
                        or (p.surfaces ->> 'trackRevision')::bigint is distinct from p.files_revision)
                   and not exists (select 1 from surface_refresh r where r.preview_id = p.id)
                 order by p.created_at desc, p.id desc
                 limit :limit
                """)
            .setParameter("createdAfter", Timestamp.from(createdAfter))
            .setParameter("limit", limit)
            .getResultList();
    return candidates(rows);
  }

  private static List<BackfillCandidate> candidates(List<Object[]> rows) {
    return rows.stream()
        .map(
            r ->
                new BackfillCandidate(
                    ((Number) r[0]).longValue(),
                    r[1] == null ? 0 : ((Number) r[1]).doubleValue(),
                    ((Number) r[2]).longValue()))
        .toList();
  }

  /** Queues a catch-up request, unless the route has one by now. @return whether it was inserted */
  public boolean insertBackfillRoute(BackfillCandidate c, Instant now, Instant dueAt) {
    return insertBackfill("route_id", c, now, dueAt);
  }

  /** As {@link #insertBackfillRoute}, for a preview. */
  public boolean insertBackfillPreview(BackfillCandidate c, Instant now, Instant dueAt) {
    return insertBackfill("preview_id", c, now, dueAt);
  }

  /** {@code column} is one of two constants of this class, never user input. */
  private boolean insertBackfill(String column, BackfillCandidate c, Instant now, Instant dueAt) {
    return getEntityManager()
            .createNativeQuery(
                """
                insert into surface_refresh
                  (id, {col}, source_revision, first_requested_at, due_at, attempts, backfill)
                values (:id, :targetId, :revision, :now, :due, 0, true)
                on conflict ({col}) where {col} is not null do nothing
                """
                    .replace("{col}", column))
            .setParameter("id", TSID.Factory.getTsid().toLong())
            .setParameter("targetId", c.id())
            .setParameter("revision", c.sourceRevision())
            .setParameter("now", Timestamp.from(now))
            .setParameter("due", Timestamp.from(dueAt))
            .executeUpdate()
        > 0;
  }

  /** Drops the normal request a bulk import made for a route, so the capped catch-up takes it. */
  public int dropNormalRequest(Long routeId) {
    return (int) delete("route.id = ?1 and backfill = false and attempts = 0", routeId);
  }
}
