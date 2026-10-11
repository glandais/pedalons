package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.dto.routes.response.ClimbDto;
import fr.pedalons.dto.routes.response.TrackDto;
import fr.pedalons.service.route.ClimbNaming.NamedPoint;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * A climb is named after the waypoint the route's author put at its top, and only that
 * (docs/LEDGER_*.md API-10).
 */
class ClimbNamingTest {

  /** A straight track heading north, one point every 100 m (about 0.0009° of latitude). */
  private static final double STEP_DEG = 100 / 111_195.0;

  private static List<TrackPoint> track(int points) {
    List<TrackPoint> track = new ArrayList<>();
    for (int i = 0; i < points; i++) {
      track.add(new TrackPoint(45.0 + i * STEP_DEG, 6.0, 100 + i * 5.0, i * 100.0));
    }
    return track;
  }

  private static ClimbData climb(double startDist, double endDist) {
    double length = endDist - startDist;
    return new ClimbData(
        startDist,
        100,
        endDist,
        100 + length * 0.05,
        length,
        length * 0.05,
        length * 0.05,
        0,
        5,
        5,
        List.of());
  }

  private static NamedPoint near(TrackPoint p, double metersEast, String name) {
    return new NamedPoint(
        name, p.lat(), p.lng() + metersEast / (111_195.0 * Math.cos(Math.toRadians(p.lat()))));
  }

  @Test
  void aWaypointAtTheSummit_namesTheClimb() {
    List<TrackPoint> track = track(50);
    ClimbData climb = climb(1000, 3000);

    assertEquals(
        "Col du Test",
        ClimbNaming.nameOf(climb, track, List.of(near(track.get(30), 120, "  Col du Test  "))));
  }

  @Test
  void theClosestWaypointToTheSummitWins() {
    List<TrackPoint> track = track(50);

    assertEquals(
        "Col",
        ClimbNaming.nameOf(
            climb(1000, 3000),
            track,
            List.of(near(track.get(30), 250, "Café"), near(track.get(30), 20, "Col"))));
  }

  @Test
  void aWaypointFartherThanTheThreshold_namesNothing() {
    List<TrackPoint> track = track(50);

    assertNull(
        ClimbNaming.nameOf(
            climb(1000, 3000), track, List.of(near(track.get(30), 400, "Hameau d'en bas"))));
    // Nor does a waypoint at the foot of the climb.
    assertNull(
        ClimbNaming.nameOf(climb(1000, 3000), track, List.of(near(track.get(10), 0, "Départ"))));
  }

  @Test
  void aBlankWaypointName_namesNothing() {
    List<TrackPoint> track = track(50);

    assertNull(ClimbNaming.nameOf(climb(1000, 3000), track, List.of(near(track.get(30), 0, "  "))));
  }

  @Test
  void trackDto_namesEachClimbOnItsOwn_andLeavesTheOthersNull() {
    List<TrackPoint> track = track(80);
    TrackDto dto =
        TrackDto.of(
            track,
            List.of(climb(500, 2000), climb(4000, 6000)),
            List.of(near(track.get(60), 50, "Côte de la Fin")));

    List<String> names = dto.climbs().stream().map(ClimbDto::name).toList();
    assertNull(names.get(0));
    assertEquals("Côte de la Fin", names.get(1));
  }
}
