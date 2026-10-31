package fr.pedalons.repository.route;

import fr.pedalons.domain.route.RawTrackBackfillSkip;
import fr.pedalons.domain.route.RawTrackBackfillSkip.Reason;
import io.quarkus.hibernate.orm.panache.PanacheRepositoryBase;
import jakarta.enterprise.context.ApplicationScoped;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The catch-up of the raw line of the tracks saved before it existed (docs/LEDGER_*.md API-147,
 * phase D): its candidates and the routes it gave up on. Native queries, across the domains, like
 * the surface catch-up's ({@code SurfaceRefreshRepository}).
 */
@ApplicationScoped
public class RawTrackBackfillRepository
    implements PanacheRepositoryBase<RawTrackBackfillSkip, Long> {

  /**
   * A route to catch up: its team (the storage key of its files) and the {@code file_id} of its
   * current original GPX, null when it has none.
   */
  public record Candidate(Long routeId, Long teamId, @Nullable Long originalFileId) {}

  /**
   * Routes with a track without a raw line, neither deleted nor given up, most recent first. The
   * team is the original asset's when there is one (the key its file is stored under), else the
   * route's.
   */
  public List<Candidate> findCandidates(int limit) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        getEntityManager()
            .createNativeQuery(
                """
                with candidates as (
                  select t.id, t.team_id, t.created_at
                    from team_entities t
                    join teams tm on tm.id = t.team_id
                   where t.id in (select g.route_id from gpx_tracks g where g.raw_geometry is null)
                     and t.deleted = false
                     and tm.deleted = false
                     and not exists (select 1 from raw_track_backfill_skip s where s.route_id = t.id)
                   order by t.created_at desc, t.id desc
                   limit :limit)
                select c.id, coalesce(o.team_id, c.team_id), o.file_id
                  from candidates c
                  left join lateral (
                    select a.team_id, a.file_id from assets a
                     where a.team_entity_id = c.id and a.type = 'ROUTE_ORIGINAL_GPX'
                     order by a.id desc limit 1) o on true
                 order by c.created_at desc, c.id desc
                """)
            .setParameter("limit", limit)
            .getResultList();
    return rows.stream()
        .map(
            r ->
                new Candidate(
                    ((Number) r[0]).longValue(),
                    ((Number) r[1]).longValue(),
                    r[2] == null ? null : ((Number) r[2]).longValue()))
        .toList();
  }

  /** Gives a route up, unless it already is: no pass picks it again. */
  public void skip(Long routeId, Reason reason, Instant now) {
    getEntityManager()
        .createNativeQuery(
            """
            insert into raw_track_backfill_skip (route_id, reason, skipped_at)
            values (:routeId, :reason, :now)
            on conflict (route_id) do nothing
            """)
        .setParameter("routeId", routeId)
        .setParameter("reason", reason.name())
        .setParameter("now", Timestamp.from(now))
        .executeUpdate();
  }

  /**
   * Records that a route's surface is worth asking again, its raw line read from the original
   * {@code sourceRevision}; a row already there follows the new revision.
   */
  public void wantResurface(Long routeId, long sourceRevision, Instant now) {
    getEntityManager()
        .createNativeQuery(
            """
            insert into raw_track_resurface (route_id, source_revision, wanted_at)
            values (:routeId, :revision, :now)
            on conflict (route_id) do update set
              source_revision = excluded.source_revision,
              wanted_at = excluded.wanted_at
            """)
        .setParameter("routeId", routeId)
        .setParameter("revision", sourceRevision)
        .setParameter("now", Timestamp.from(now))
        .executeUpdate();
  }
}
