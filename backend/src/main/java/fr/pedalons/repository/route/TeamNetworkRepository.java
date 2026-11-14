package fr.pedalons.repository.route;

import fr.pedalons.service.route.network.Fingerprint;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.util.function.Consumer;
import java.util.stream.Stream;
import org.jspecify.annotations.Nullable;

/**
 * The two native statements of the team route generator's graph cache (docs/LEDGER_*.md API-198,
 * lot 3 plan §2.2): the fingerprint read on every request, and the streamed read of the tracks'
 * street edges documents. Both are bound to the team and to its domain.
 */
@ApplicationScoped
public class TeamNetworkRepository {

  @Inject EntityManager entityManager;

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
   * size 32): the documents are never held at once. Call it inside a transaction.
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
            .setHint("org.hibernate.fetchSize", 32)
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
