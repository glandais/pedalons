package fr.pedalons.repository.thumbnail;

import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The native statements around {@code team_entities.thumbnail_version} (docs/LEDGER_*.md OPS-71):
 * stamping an entity whose thumbnails were drawn in full, and the queries of {@code
 * ThumbnailBackfill}, the catch-up that redraws the ones drawn before the current {@code
 * MapThumbnailRenderer.VERSION}. Neither domain nor query context: a system job across the
 * domains, by id. The version is inlined in the SQL, like the predicate of the partial index {@code
 * team_entities_thumbnail_behind} (V94) it must match.
 *
 * <p>The three columns are written <b>only</b> here, by native updates: the entity does not map
 * them as updatable, so a user editing a ride while it is stamped gets no optimistic-lock failure.
 */
@ApplicationScoped
public class ThumbnailBackfillRepository {

  private static final String LIGHT_TYPES =
      "'ROUTE_THUMBNAIL_LIGHT', 'RIDE_THUMBNAIL_LIGHT', 'TRIP_THUMBNAIL_LIGHT'";
  private static final String DARK_TYPES =
      "'ROUTE_THUMBNAIL_DARK', 'RIDE_THUMBNAIL_DARK', 'TRIP_THUMBNAIL_DARK'";

  /**
   * Live entities of live teams behind the current drawing, with both their thumbnails (the
   * catch-up replaces files, it never creates a row). The assets reference their owner by {@code
   * team_entity_id}.
   */
  private static final String BEHIND =
      """
        from team_entities t
        join teams tm on tm.id = t.team_id
       where t.deleted = false and tm.deleted = false
         and (t.thumbnail_version is null or t.thumbnail_version < {version})
         and exists (select 1 from assets a
                      where a.team_entity_id = t.id and a.type in ({light}))
         and exists (select 1 from assets a
                      where a.team_entity_id = t.id and a.type in ({dark}))
      """;

  /**
   * Live entities of live teams behind the current drawing with at least one thumbnail, the ones
   * the admin « outdated » criterion selects (a lone thumbnail is redrawn in full by the admin
   * regeneration, which creates the missing row).
   */
  private static final String BEHIND_ANY =
      """
        from team_entities t
        join teams tm on tm.id = t.team_id
       where t.deleted = false and tm.deleted = false
         and (t.thumbnail_version is null or t.thumbnail_version < {version})
         and exists (select 1 from assets a
                      where a.team_entity_id = t.id and a.type in ({light}, {dark}))
      """;

  /** What the catch-up still has to do: entities to redraw, and those it gave up on. */
  public record Remaining(int left, int givenUp) {}

  @Inject EntityManager entityManager;

  /**
   * Records that the thumbnails of {@code ownerId} were drawn in full with the current version, and
   * clears its failures. Runs in the caller's transaction (the native query flushes what is pending
   * first, so the row exists).
   */
  public void stamp(Long ownerId) {
    entityManager
        .createNativeQuery(
            """
            update team_entities
               set thumbnail_version = :version, thumbnail_attempts = 0, thumbnail_retry_at = null
             where id = :id
            """)
        .setParameter("version", (short) MapThumbnailRenderer.VERSION)
        .setParameter("id", ownerId)
        .executeUpdate();
  }

  /**
   * Claims the most recent entity to redraw that is not waiting for a retry nor given up, locking
   * its row until the end of the transaction: the other backend of a rolling deploy skips it.
   *
   * @return its id, or null when there is none
   */
  public @Nullable Long claim(Instant now, int maxAttempts, Duration quiet) {
    var rows =
        entityManager
            .createNativeQuery(
                inline(
                    "select t.id "
                        + BEHIND
                        + """
                             and t.thumbnail_attempts < :maxAttempts
                             and (t.thumbnail_retry_at is null or t.thumbnail_retry_at <= :now)
                             and t.updated_at <= :quietSince
                           order by t.created_at desc, t.id desc
                           limit 1
                           for update of t skip locked
                        """))
            .setParameter("maxAttempts", maxAttempts)
            .setParameter("now", Timestamp.from(now))
            .setParameter("quietSince", Timestamp.from(now.minus(quiet)))
            .getResultList();
    if (rows.isEmpty()) {
      return null;
    }
    long id = ((Number) rows.getFirst()).longValue();
    // The thumbnail rows too, in the same order as a save (owner, then assets): a save that took
    // them first makes the claim wait instead of the two deadlocking
    entityManager
        .createNativeQuery("select a.id from assets a where a.team_entity_id = :id for update")
        .setParameter("id", id)
        .getResultList();
    return id;
  }

  /**
   * A redraw failed: one more attempt, and the next one no sooner than 15 minutes times two to the
   * number of attempts so far, at most 24 hours.
   */
  public void recordFailure(Long ownerId, Instant now) {
    entityManager
        .createNativeQuery(
            """
            update team_entities
               set thumbnail_retry_at = cast(:now as timestamptz)
                     + least(interval '24 hours', interval '15 minutes' * power(2, thumbnail_attempts)),
                   thumbnail_attempts = thumbnail_attempts + 1
             where id = :id
            """)
        .setParameter("now", Timestamp.from(now))
        .setParameter("id", ownerId)
        .executeUpdate();
  }

  /** What is behind, those waiting for a retry included, and what was given up. */
  public Remaining remaining(int maxAttempts) {
    Object[] row =
        (Object[])
            entityManager
                .createNativeQuery(
                    inline(
                        "select count(*) filter (where t.thumbnail_attempts < :maxAttempts),"
                            + " count(*) filter (where t.thumbnail_attempts >= :maxAttempts) "
                            + BEHIND))
                .setParameter("maxAttempts", maxAttempts)
                .getSingleResult();
    return new Remaining(((Number) row[0]).intValue(), ((Number) row[1]).intValue());
  }

  /** Counts of the catch-up in one domain, for the admin status. */
  public record DomainCounts(int behind, int waiting, int givenUp) {}

  /**
   * The catch-up's backlog in a domain: behind and not given up (of which waiting for a retry at
   * {@code now}), and given up.
   */
  public DomainCounts counts(Long domainId, int maxAttempts, Instant now) {
    Object[] row =
        (Object[])
            entityManager
                .createNativeQuery(
                    inline(
                        "select count(*) filter (where t.thumbnail_attempts < :maxAttempts),"
                            + " count(*) filter (where t.thumbnail_attempts < :maxAttempts"
                            + " and t.thumbnail_retry_at > :now),"
                            + " count(*) filter (where t.thumbnail_attempts >= :maxAttempts) "
                            + BEHIND
                            + " and tm.domain_id = :domainId"))
                .setParameter("maxAttempts", maxAttempts)
                .setParameter("now", Timestamp.from(now))
                .setParameter("domainId", domainId)
                .getSingleResult();
    return new DomainCounts(
        ((Number) row[0]).intValue(), ((Number) row[1]).intValue(), ((Number) row[2]).intValue());
  }

  /** Ids of the entities of a domain behind the current drawing with a thumbnail, recent first. */
  public List<Long> findOutdated(Long domainId) {
    return ids(
        "select t.id "
            + BEHIND_ANY
            + " and tm.domain_id = :domainId"
            + " order by t.created_at desc, t.id desc",
        domainId,
        null);
  }

  /** Ids of the entities of a domain the catch-up gave up on, recent first. */
  public List<Long> findGivenUp(Long domainId, int maxAttempts) {
    return ids(
        "select t.id "
            + BEHIND
            + " and tm.domain_id = :domainId"
            + " and t.thumbnail_attempts >= :maxAttempts"
            + " order by t.created_at desc, t.id desc",
        domainId,
        maxAttempts);
  }

  private List<Long> ids(String sql, Long domainId, @Nullable Integer maxAttempts) {
    var query = entityManager.createNativeQuery(inline(sql)).setParameter("domainId", domainId);
    if (maxAttempts != null) {
      query.setParameter("maxAttempts", maxAttempts);
    }
    return ((List<?>) query.getResultList()).stream().map(o -> ((Number) o).longValue()).toList();
  }

  private static String inline(String sql) {
    return sql.replace("{version}", String.valueOf(MapThumbnailRenderer.VERSION))
        .replace("{light}", LIGHT_TYPES)
        .replace("{dark}", DARK_TYPES);
  }
}
