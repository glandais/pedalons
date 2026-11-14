package fr.pedalons.repository.route;

import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.service.route.GpxPipeline;
import io.hypersistence.tsid.TSID;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The native queries of {@code NetworkEdgesBackfill} (docs/LEDGER_*.md API-198, lot 1): the team
 * routes whose tracks have no street edges document, or an older one, queued into {@code
 * elevation_refresh} as {@code backfill} requests. Neither domain nor query context: a system job
 * across the domains, by id. The versions are inlined in the SQL, like the predicate of the partial
 * index {@code gpx_tracks_network_edges_behind} (V91) they must match.
 */
@ApplicationScoped
public class NetworkEdgesBackfillRepository {

  @Inject EntityManager entityManager;

  /** A route the backfill may queue: its id, its length (the weight), the revision to ask for. */
  public record Candidate(Long id, double distance, long sourceRevision) {}

  /** What is queued and not done: the service calls it still holds, the first free due time. */
  public record Budget(int pending, @Nullable Instant nextFree) {}

  /** What the backfill still has to do, as one pass sees it. */
  public record Remaining(int routes, double routeMetres, int givenUp) {}

  /**
   * Takes the advisory lock of the backfill for the rest of the transaction: the two backends of a
   * rolling deploy run their passes one after the other.
   */
  public void lock() {
    entityManager
        .createNativeQuery("select 1 from pg_advisory_xact_lock(hashtextextended(:key, 0))")
        .setParameter("key", "network-edges-backfill")
        .getSingleResult();
  }

  /**
   * The backfill requests still to come (not given up, route alive), weighted by their number of
   * calls, and the first due time free after the ones not yet tried.
   */
  public Budget budget(double spacingSeconds, double sliceMetres, int maxAttempts) {
    Object[] row =
        (Object[])
            entityManager
                .createNativeQuery(
                    """
                    select coalesce(sum(greatest(1, ceil(coalesce(t.distance, 0) / :slice))), 0),
                           max(e.due_at + make_interval(secs =>
                                 :spacing * greatest(1, ceil(coalesce(t.distance, 0) / :slice))))
                             filter (where e.attempts = 0)
                      from elevation_refresh e
                      join team_entities t on t.id = e.route_id
                      join teams tm on tm.id = t.team_id
                     where e.backfill
                       and e.attempts < :maxAttempts
                       and t.deleted = false and tm.deleted = false
                    """)
                .setParameter("spacing", spacingSeconds)
                .setParameter("slice", sliceMetres)
                .setParameter("maxAttempts", maxAttempts)
                .getSingleResult();
    return new Budget(((Number) row[0]).intValue(), row[1] == null ? null : toInstant(row[1]));
  }

  /**
   * Live routes of live teams, HD (or without a state) at the current pipeline, with a track that
   * has no document or an older one, an original, and no request of any kind, most recent first.
   * Any row excludes a route: an open one brings the full catch-up, which writes the edges, and one
   * given up is not queued again, so the loop ends by itself. A route that is {@code FAST} or
   * {@code PENDING}, or behind the pipeline, is left to its own catch-up.
   */
  public List<Candidate> findCandidates(int limit) {
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        entityManager
            .createNativeQuery(
                inline(
                    """
                    select t.id, t.distance,
                           (select a.file_id from assets a
                             where a.team_entity_id = t.id and a.type = 'ROUTE_ORIGINAL_GPX'
                             order by a.id desc limit 1)
                      from team_entities t
                      join teams tm on tm.id = t.team_id
                     where t.entity_type = 2 and t.deleted = false and tm.deleted = false
                       and (t.elevation_state is null or t.elevation_state = 'HD')
                       and t.elevation_pipeline = {pipeline}
                       and not exists (select 1 from elevation_refresh e where e.route_id = t.id)
                       and exists (select 1 from gpx_tracks g where g.route_id = t.id
                                     and (g.network_edges is null
                                          or (g.network_edges->>'v')::int < {edgesVersion}))
                       and exists (select 1 from assets a
                                    where a.team_entity_id = t.id
                                      and a.type = 'ROUTE_ORIGINAL_GPX')
                     order by t.created_at desc, t.id desc
                     limit :limit
                    """))
            .setParameter("limit", limit)
            .getResultList();
    return rows.stream()
        .map(r ->
            new Candidate(
                ((Number) r[0]).longValue(),
                r[1] == null ? 0 : ((Number) r[1]).doubleValue(),
                ((Number) r[2]).longValue()))
        .toList();
  }

  /**
   * Queues a request, unless the route has one by now: a save made meanwhile wins (its upsert
   * makes the row a normal one). Idempotent.
   *
   * @return whether it was inserted
   */
  public boolean insert(Candidate c, Instant now, Instant dueAt) {
    return entityManager
            .createNativeQuery(
                """
                insert into elevation_refresh
                  (id, route_id, source_revision, first_requested_at, due_at, attempts, backfill)
                values (:id, :routeId, :revision, :now, :due, 0, true)
                on conflict (route_id) where route_id is not null do nothing
                """)
            .setParameter("id", TSID.Factory.getTsid().toLong())
            .setParameter("routeId", c.id())
            .setParameter("revision", c.sourceRevision())
            .setParameter("now", Timestamp.from(now))
            .setParameter("due", Timestamp.from(dueAt))
            .executeUpdate()
        > 0;
  }

  /**
   * What is still to do, on the filters of {@link #findCandidates} but for the request: the routes
   * (and their metres) with no request or an open backfill one, and those whose request gave up.
   */
  public Remaining remaining(int maxAttempts) {
    Object[] row =
        (Object[])
            entityManager
                .createNativeQuery(
                    inline(
                        """
                        select count(*) filter (where e.id is null
                                                   or (e.backfill and e.attempts < :maxAttempts)),
                               coalesce(sum(cast(t.distance as double precision))
                                 filter (where e.id is null
                                            or (e.backfill and e.attempts < :maxAttempts)), 0),
                               count(*) filter (where e.attempts >= :maxAttempts)
                          from team_entities t
                          join teams tm on tm.id = t.team_id
                          left join elevation_refresh e on e.route_id = t.id
                         where t.entity_type = 2 and t.deleted = false and tm.deleted = false
                           and (t.elevation_state is null or t.elevation_state = 'HD')
                           and t.elevation_pipeline = {pipeline}
                           and exists (select 1 from gpx_tracks g where g.route_id = t.id
                                         and (g.network_edges is null
                                              or (g.network_edges->>'v')::int < {edgesVersion}))
                           and exists (select 1 from assets a
                                        where a.team_entity_id = t.id
                                          and a.type = 'ROUTE_ORIGINAL_GPX')
                        """))
                .setParameter("maxAttempts", maxAttempts)
                .getSingleResult();
    return new Remaining(
        ((Number) row[0]).intValue(),
        ((Number) row[1]).doubleValue(),
        ((Number) row[2]).intValue());
  }

  private static String inline(String sql) {
    return sql.replace("{pipeline}", String.valueOf(GpxPipeline.VERSION))
        .replace("{edgesVersion}", String.valueOf(NetworkEdgesDocument.VERSION));
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
}
