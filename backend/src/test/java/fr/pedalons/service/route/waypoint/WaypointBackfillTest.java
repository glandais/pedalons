package fr.pedalons.service.route.waypoint;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The typing of the waypoints written before C3c, or by the previous release of a rolling deploy
 * (docs/LEDGER_*.md WEB-100, C3c).
 */
@QuarkusTest
class WaypointBackfillTest extends AbstractResourceTest {

  private static final double STEP = 100 / 111_195.0;

  @Inject WaypointBackfill backfill;
  @Inject EntityManager entityManager;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    backfill.setForTest(true);
  }

  @AfterEach
  void switchOff() {
    backfill.setForTest(false);
  }

  private Route routeWithLegacyWaypoints() {
    List<GpxTrack.TrackPoint> points = new ArrayList<>();
    for (int i = 0; i < 30; i++) {
      points.add(new GpxTrack.TrackPoint(45.0 + i * STEP, 6.0, 100, i * 100.0));
    }
    Route route = dataService.createRouteWithClimbs(team1, user1, "Ancien", points, List.of());
    // On the track at 1 500 m, then 5 km east of it
    dataService.addWaypoint(route, user1, "Sur le tracé", 45.0 + 15 * STEP, 6.0003);
    dataService.addWaypoint(route, user1, "Hors tracé", 45.0 + 15 * STEP, 6.07);
    return route;
  }

  private List<GpxWaypoint> rows(Long routeId) {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                entityManager
                    .createQuery(
                        "select w from GpxWaypoint w where w.route.id = :id", GpxWaypoint.class)
                    .setParameter("id", routeId)
                    .getResultList());
  }

  @Test
  void legacyRows_becomeInfo_withADistance() {
    Route route = routeWithLegacyWaypoints();

    assertEquals(1, backfill.runOnce());

    GpxWaypoint onTrack =
        rows(route.getId()).stream()
            .filter(w -> "Sur le tracé".equals(w.getName()))
            .findFirst()
            .orElseThrow();
    assertEquals(WaypointType.INFO, onTrack.getType());
    assertNotNull(onTrack.getDistanceM());
    assertEquals(1500, onTrack.getDistanceM(), 5.0);
    assertEquals(WaypointOrigin.IMPORTED, onTrack.getOrigin());
  }

  @Test
  void offTrackLegacyRow_isTypedAndNotRetried() {
    Route route = routeWithLegacyWaypoints();

    backfill.runOnce();

    GpxWaypoint offTrack =
        rows(route.getId()).stream()
            .filter(w -> "Hors tracé".equals(w.getName()))
            .findFirst()
            .orElseThrow();
    assertEquals(WaypointType.INFO, offTrack.getType());
    assertNull(offTrack.getDistanceM(), "kept where it is, without a distance");
    assertEquals(0, backfill.runOnce(), "typed, so not picked again");
  }

  @Test
  void deletedRoute_isProcessed() {
    Route route = routeWithLegacyWaypoints();
    dataService.deleteRoute(route);

    assertEquals(1, backfill.runOnce());

    assertTrue(rows(route.getId()).stream().allMatch(w -> w.getType() == WaypointType.INFO));
    assertEquals(0, backfill.runOnce());
  }

  @Test
  void secondRun_changesNothing() {
    Route route = routeWithLegacyWaypoints();
    backfill.runOnce();
    List<Double> first = rows(route.getId()).stream().map(GpxWaypoint::getDistanceM).toList();

    assertEquals(0, backfill.runOnce());

    assertEquals(first.size(), rows(route.getId()).size());
    assertEquals(
        first.stream().filter(d -> d != null).count(),
        rows(route.getId()).stream().filter(w -> w.getDistanceM() != null).count());
  }

  @Test
  void disabled_doesNothing() {
    routeWithLegacyWaypoints();
    backfill.setForTest(false);

    assertEquals(0, backfill.runOnce());
  }
}
