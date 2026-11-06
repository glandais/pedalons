package fr.pedalons.service.surface;

import fr.pedalons.repository.route.SurfaceRefreshRepository;
import io.hypersistence.tsid.TSID;
import io.quarkus.narayana.jta.QuarkusTransaction;
import java.sql.Timestamp;
import java.time.Instant;

/**
 * A row of {@code surface_refresh} as a previous release leaves it: due, never attempted
 * (docs/LEDGER_*.md API-150). This release writes none. Goes with the table in phase F.
 */
public final class LegacySurfaceRequests {

  private LegacySurfaceRequests() {}

  public static void leaveForRoute(
      SurfaceRefreshRepository repository, Long routeId, long revision) {
    leave(repository, "route_id", routeId, revision);
  }

  public static void leaveForPreview(
      SurfaceRefreshRepository repository, Long previewId, long revision) {
    leave(repository, "preview_id", previewId, revision);
  }

  /** {@code column} is one of the two constants above. */
  private static void leave(
      SurfaceRefreshRepository repository, String column, Long targetId, long revision) {
    Instant now = Instant.now();
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                repository
                    .getEntityManager()
                    .createNativeQuery(
                        "insert into surface_refresh"
                            + " (id, "
                            + column
                            + ", source_revision, first_requested_at, due_at, attempts, backfill)"
                            + " values (:id, :target, :revision, :first, :due, 0, false)")
                    .setParameter("id", TSID.Factory.getTsid().toLong())
                    .setParameter("target", targetId)
                    .setParameter("revision", revision)
                    .setParameter("first", Timestamp.from(now.minusSeconds(120)))
                    .setParameter("due", Timestamp.from(now.minusSeconds(1)))
                    .executeUpdate());
  }
}
