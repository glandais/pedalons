package fr.pedalons.service.route.waypoint;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import fr.pedalons.infrastructure.gpx.CoursePoint;
import io.github.glandais.engine.gpx.GpxWaypoint;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Which waypoints a file or a device gets (docs/LEDGER_*.md WEB-100, C3c). */
class WaypointExportsTest {

  private static AnchoredWaypoint wp(
      String name, WaypointType type, WaypointOrigin origin, Double distance) {
    return new AnchoredWaypoint(null, 45.0, 6.0, name, null, type, origin, distance);
  }

  @Test
  void coursePoints_skipOffTrack_authorFirst_cappedAt200_sortedByDistance() {
    List<AnchoredWaypoint> all = new ArrayList<>();
    for (int i = 0; i < 250; i++) {
      all.add(wp("imported " + i, WaypointType.INFO, WaypointOrigin.IMPORTED, i * 10.0));
    }
    for (int i = 0; i < 10; i++) {
      all.add(wp("author " + i, WaypointType.WATER, WaypointOrigin.AUTHOR, 5000.0 + i));
    }
    all.add(wp("off", WaypointType.DANGER, WaypointOrigin.AUTHOR, null));

    List<CoursePoint> points = WaypointExports.coursePoints(all);

    assertEquals(200, points.size());
    assertEquals(
        10, points.stream().filter(p -> p.name().startsWith("author")).count(), "all the author's");
    assertTrue(points.stream().noneMatch(p -> p.name().equals("off")), "off the track: GPX only");
    for (int i = 1; i < points.size(); i++) {
      assertTrue(points.get(i - 1).distanceM() <= points.get(i).distanceM(), "by distance");
    }
  }

  @Test
  void coursePoints_namesAreCutForFit() {
    List<CoursePoint> points =
        WaypointExports.coursePoints(
            List.of(
                wp("Ravitaillement Intermarché", WaypointType.SUPPLY, WaypointOrigin.AUTHOR, 100.0),
                wp("", WaypointType.WATER, WaypointOrigin.AUTHOR, 200.0)));

    assertEquals("Ravitaillement", points.get(0).name());
    assertEquals("Eau", points.get(1).name());
  }

  @Test
  void gpx_includesOffTrack_withSymTypeDesc() {
    List<GpxWaypoint> gpx =
        WaypointExports.gpx(
            List.of(
                wp("far", WaypointType.DANGER, WaypointOrigin.AUTHOR, null),
                new AnchoredWaypoint(
                    null,
                    45.0,
                    6.0,
                    "Source",
                    "Eau potable",
                    WaypointType.WATER,
                    WaypointOrigin.AUTHOR,
                    300.0),
                wp("", WaypointType.INFO, WaypointOrigin.IMPORTED, 100.0)));

    assertEquals(3, gpx.size());
    assertNull(gpx.get(0).getName(), "an empty name is written as none");
    assertEquals("Information", gpx.get(0).getSymbol());
    assertEquals("info", gpx.get(0).getType());
    assertEquals("Source", gpx.get(1).getName());
    assertEquals("Eau potable", gpx.get(1).getDescription());
    assertEquals("Drinking Water", gpx.get(1).getSymbol());
    assertEquals("water", gpx.get(1).getType());
    assertEquals("far", gpx.get(2).getName(), "off the track, last");
    assertEquals("Danger Area", gpx.get(2).getSymbol());
  }
}
