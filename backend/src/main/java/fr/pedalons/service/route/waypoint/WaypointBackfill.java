package fr.pedalons.service.route.waypoint;

import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.WaypointType;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import java.util.Comparator;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * Types and places the waypoints written before C3c, or by the previous release during a rolling
 * deploy (docs/LEDGER_*.md WEB-100, C3c): a row whose {@code type} is null is typed INFO and gets
 * its distance along the track (the first passage: nothing says which one was meant). A row off
 * the track stays without a distance but is typed, so it is not picked again.
 *
 * <p>A system job across the domains, like {@code SurfaceBackfill}: it works by route id only.
 * Deleted routes are included, or they would be selected at every pass. Idempotent (a deterministic
 * computation, filtered on {@code type is null}), and it rewrites <b>no file</b>: no mass write to
 * S3, no route sent again to the GPS services. The files of an old route get their types at its
 * next save.
 */
@ApplicationScoped
public class WaypointBackfill {

  private static final Logger LOG = Logger.getLogger(WaypointBackfill.class);

  /** Routes handled by one pass. */
  static final int BATCH = 200;

  @ConfigProperty(name = "pedalons.waypoint.backfill.enabled", defaultValue = "true")
  boolean enabled;

  @Inject EntityManager entityManager;

  /** For the tests: the switch. */
  public void setForTest(boolean enabled) {
    this.enabled = enabled;
  }

  @Scheduled(every = "5m", delayed = "3m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void run() {
    try {
      runOnce();
    } catch (Exception e) {
      LOG.error("Waypoint catch-up failed", e);
    }
  }

  /**
   * One pass. Public for the tests.
   *
   * @return how many routes were handled
   */
  public int runOnce() {
    if (!enabled) {
      return 0;
    }
    List<Long> routeIds =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    entityManager
                        .createQuery(
                            "select distinct w.route.id from GpxWaypoint w where w.type is null",
                            Long.class)
                        .setMaxResults(BATCH)
                        .getResultList());
    for (Long routeId : routeIds) {
      try {
        QuarkusTransaction.requiringNew().run(() -> backfill(routeId));
      } catch (Exception e) {
        LOG.errorf(e, "Waypoint catch-up failed for route %d", routeId);
      }
    }
    if (!routeIds.isEmpty()) {
      LOG.infof("Waypoint catch-up: %d route(s) typed", routeIds.size());
    }
    return routeIds.size();
  }

  private void backfill(Long routeId) {
    // Same lock order as the saves: the route first
    Route route = entityManager.find(Route.class, routeId, LockModeType.PESSIMISTIC_WRITE);
    if (route == null) {
      return;
    }
    List<GpxTrack> tracks =
        route.getTracks().stream().sorted(Comparator.comparing(GpxTrack::getId)).toList();
    TrackAxis axis = TrackAxis.ofTracks(tracks);
    for (GpxWaypoint row : route.getWaypoints()) {
      if (row.getType() != null) {
        continue;
      }
      if (row.getDistanceM() != null) {
        // Already placed, by an HD catch-up that knew the passage: keep it
        row.setType(WaypointType.INFO);
        continue;
      }
      List<AnchoredWaypoint> placed =
          WaypointAnchoring.anchor(
              axis,
              List.of(
                  new WaypointDraft(
                      row.getId(),
                      row.getGeometry().getPosition().getLat(),
                      row.getGeometry().getPosition().getLon(),
                      row.getName(),
                      row.getDescription(),
                      WaypointType.INFO,
                      row.getOrigin(),
                      null,
                      null)));
      row.setType(WaypointType.INFO);
      row.setDistanceM(placed.getFirst().distance());
    }
  }
}
