package fr.pedalons.infrastructure.gps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;

import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxWaypoint;
import io.github.glandais.engine.gpx.GpxWriterJvm;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

/**
 * The GPX Hammerhead is sent has its waypoint types reduced to the nine it keeps (docs/LEDGER_*.md
 * WEB-100, C3a and C3c).
 */
class HammerheadGpxTest {

  private static final Set<String> NINE =
      Set.of(
          "Food",
          "Water",
          "Parking",
          "Camping",
          "Lodging",
          "Geocache",
          "Summit",
          "Generic",
          "Danger");

  private static byte[] gpx(List<GpxWaypoint> waypoints) {
    GpxDocument doc =
        GpxModelJvm.document(
            List.of(
                GpxModelJvm.track(
                    List.of(
                        GpxModelJvm.trackPoint(45.0, 6.0, 100.0),
                        GpxModelJvm.trackPoint(45.01, 6.0, 120.0)),
                    "Track")),
            "Route",
            waypoints);
    return GpxWriterJvm.write(doc).getBytes(StandardCharsets.UTF_8);
  }

  private static GpxWaypoint wpt(String name, String desc, String sym, String type) {
    return GpxModelJvm.waypoint(45.005, 6.001, null, name, desc, sym, type, null);
  }

  private static List<GpxWaypoint> parse(byte[] bytes) {
    return GpxParserJvm.parse(new String(bytes, StandardCharsets.UTF_8)).getWaypoints();
  }

  @Test
  void rewritesTypeAndSymToTheNineValues() {
    byte[] sent =
        HammerheadGpx.withHammerheadTypes(
            gpx(
                List.of(
                    wpt("Source", null, "Drinking Water", "water"),
                    wpt("Boulangerie", null, "Restaurant", "food"),
                    wpt("Danger", null, "Danger Area", "danger"),
                    wpt("Col", null, "Summit", "summit"),
                    wpt("Rendez-vous", null, "Flag, Blue", "meeting_spot"),
                    wpt("Vieux", null, null, null))));

    List<GpxWaypoint> waypoints = parse(sent);

    assertEquals(6, waypoints.size());
    for (GpxWaypoint w : waypoints) {
      assertEquals(w.getSymbol(), w.getType(), "sym and type agree");
      assertEquals(true, NINE.contains(w.getType()), w.getType());
    }
    assertEquals("Water", waypoints.get(0).getType());
    assertEquals("Food", waypoints.get(1).getType());
    assertEquals("Danger", waypoints.get(2).getType());
    assertEquals("Summit", waypoints.get(3).getType());
    assertEquals("Generic", waypoints.get(4).getType());
    assertEquals("Generic", waypoints.get(5).getType(), "a waypoint with a name only");
  }

  @Test
  void keepsNamesDescriptionsAndOffTrackPoints() {
    GpxWaypoint offTrack =
        GpxModelJvm.waypoint(46.5, 7.5, null, "Loin", "À 200 km", "Information", "info", null);

    List<GpxWaypoint> waypoints =
        parse(
            HammerheadGpx.withHammerheadTypes(
                gpx(List.of(wpt("Source", "Eau potable", "Drinking Water", "water"), offTrack))));

    assertEquals(2, waypoints.size());
    assertEquals("Source", waypoints.get(0).getName());
    assertEquals("Eau potable", waypoints.get(0).getDescription());
    assertEquals("Loin", waypoints.get(1).getName());
    assertEquals("À 200 km", waypoints.get(1).getDescription());
    assertEquals(46.5, waypoints.get(1).getLatitudeDeg(), 1e-9);
  }

  @Test
  void unreadableGpx_isSentUnchanged() {
    byte[] garbage = "this is not a gpx file".getBytes(StandardCharsets.UTF_8);

    assertSame(garbage, HammerheadGpx.withHammerheadTypes(garbage));
  }
}
