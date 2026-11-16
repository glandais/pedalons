package fr.pedalons.repository.route;

import fr.pedalons.service.route.network.Fingerprint;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import java.util.stream.Stream;
import org.jspecify.annotations.Nullable;

/**
 * What the nightly deposit of the route generator reads (docs/LEDGER_*.md API-198, lot 3b plan
 * §6.3): the teams, the fingerprint of a team's tracks, and the streamed read of the tracks' street
 * edges documents. The last two are bound to the team and to its domain.
 */
@ApplicationScoped
public class GeneratorSourceRepository {

  /** Documents buffered by the JDBC driver at once: the largest known weighs 4.2 MB. */
  static final int FETCH_SIZE = 8;

  @Inject EntityManager entityManager;

  /**
   * A team, whatever its state. {@code served}: not deleted, planner on, domain active and not
   * deleted; {@code gone}: the team or its domain is deleted or inactive.
   */
  public record TeamRow(long id, String slug, long domainId, boolean served, boolean gone) {}

  /** Every team of every domain, by id: one statement, whatever their number. */
  public List<TeamRow> listTeams() {
    List<?> rows =
        entityManager
            .createNativeQuery(
                """
                select tm.id, tm.slug, tm.domain_id,
                       (not tm.deleted and tm.enable_route_planner
                        and d.active and not d.deleted) as served,
                       (tm.deleted or d.deleted or not d.active) as gone
                  from teams tm
                  join domains d on d.id = tm.domain_id
                 order by tm.id
                """)
            .getResultList();
    List<TeamRow> out = new ArrayList<>(rows.size());
    for (Object o : rows) {
      Object[] r = (Object[]) o;
      out.add(
          new TeamRow(
              ((Number) r[0]).longValue(),
              (String) r[1],
              ((Number) r[2]).longValue(),
              Boolean.TRUE.equals(r[3]),
              Boolean.TRUE.equals(r[4])));
    }
    return out;
  }

  /** One track of a live route of the team, with its raw document. */
  public record TrackRow(
      long trackId,
      long routeId,
      @Nullable String surfaceType,
      boolean excluded,
      @Nullable Long original,
      @Nullable String document) {}

  /**
   * Deleted routes are counted on purpose, with a hash of the three route columns the graph depends
   * on (deleted, excluded from the generator, surface type): not the route's version, which the HD
   * catch-up bumps a minute after a save and would defeat the deferral. {@code pg_column_size} reads the stored size without detoasting the document.
   */
  public Fingerprint fingerprint(long teamId, long domainId) {
    Object[] row =
        (Object[])
            entityManager
                .createNativeQuery(
                    """
                    with r as (
                      select te.id,
                             hashtext(te.deleted::text || te.excluded_from_generator::text
                                      || coalesce(te.surface_type, '')) as state
                        from team_entities te
                        join teams tm on tm.id = te.team_id
                       where te.team_id = :teamId and tm.domain_id = :domainId
                         and te.entity_type = 2)
                    select (select count(*) from r),
                           (select coalesce(sum(state::bigint), 0) from r),
                           count(t.id),
                           coalesce(sum(t.id::numeric), 0),
                           coalesce(sum(t.version), 0),
                           count(t.network_edges),
                           coalesce(sum(pg_column_size(t.network_edges)), 0)
                      from r join gpx_tracks t on t.route_id = r.id
                    """)
                .setParameter("teamId", teamId)
                .setParameter("domainId", domainId)
                .getSingleResult();
    return new Fingerprint(
        ((Number) row[0]).longValue(),
        ((Number) row[1]).longValue(),
        ((Number) row[2]).longValue(),
        toBigInteger(row[3]),
        ((Number) row[4]).longValue(),
        ((Number) row[5]).longValue(),
        ((Number) row[6]).longValue());
  }

  /**
   * Streams every track of every non-deleted route of the team, by track id, through a cursor (fetch
   * size {@value #FETCH_SIZE}): the documents are never held at once. Call it inside a transaction,
   * with a timeout that covers the deposit (the default 60 s would cut the largest team's).
   */
  public void streamTracks(long teamId, long domainId, Consumer<TrackRow> consumer) {
    try (Stream<?> stream =
        entityManager
            .createNativeQuery(
                """
                select t.id, te.id, te.surface_type, te.excluded_from_generator,
                       (select a.file_id from assets a
                         where a.team_entity_id = te.id and a.type = 'ROUTE_ORIGINAL_GPX'
                         order by a.id desc limit 1),
                       t.network_edges::text
                  from team_entities te
                  join teams tm on tm.id = te.team_id
                  join gpx_tracks t on t.route_id = te.id
                 where te.team_id = :teamId and tm.domain_id = :domainId
                   and te.entity_type = 2 and not te.deleted
                 order by t.id
                """)
            .setParameter("teamId", teamId)
            .setParameter("domainId", domainId)
            .setHint("org.hibernate.fetchSize", FETCH_SIZE)
            .getResultStream()) {
      stream.forEach(o -> {
        Object[] r = (Object[]) o;
        consumer.accept(
            new TrackRow(
                ((Number) r[0]).longValue(),
                ((Number) r[1]).longValue(),
                (String) r[2],
                Boolean.TRUE.equals(r[3]),
                r[4] == null ? null : ((Number) r[4]).longValue(),
                (String) r[5]));
      });
    }
  }

  private static BigInteger toBigInteger(Object o) {
    if (o instanceof BigDecimal d) {
      return d.toBigInteger();
    }
    if (o instanceof BigInteger b) {
      return b;
    }
    return BigInteger.valueOf(((Number) o).longValue());
  }
}
