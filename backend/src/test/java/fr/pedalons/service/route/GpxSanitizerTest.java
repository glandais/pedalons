package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.util.GpxPrivacyAssertions;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.gpx.GpxWaypoint;
import io.github.glandais.engine.gpx.GpxWriterJvm;
import io.github.glandais.engine.path.Path;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-44: what survives {@link GpxSanitizer} — geometry and waypoint names — and
 * what does not — timestamps, heart rate, cadence, power, temperature, document metadata. A plain
 * unit test: the parser and writer are the library's, no Quarkus needed.
 */
class GpxSanitizerTest {

  static GpxDocument parseActivity() throws Exception {
    return GpxParserJvm.parse(
        Files.readString(GpxPrivacyAssertions.activityGpx(), StandardCharsets.UTF_8));
  }

  /** Both ways the pipeline serializes: the document as-is, and its paths (what it stores). */
  static List<String> serializations(GpxDocument doc) {
    return List.of(
        GpxWriterJvm.write(doc),
        GpxWriterJvm.write(
            GpxToPathJvm.tracksAsPaths(doc), doc.getName(), null, doc.getWaypoints()));
  }

  @Test
  void fixtureReallyCarriesTheDataToStrip() throws Exception {
    // Guards the test itself: if the parser stopped picking these up, every other test here
    // would pass for the wrong reason.
    for (String raw : serializations(parseActivity())) {
      assertTrue(raw.contains("<time>2025-11-22T07:00:00Z</time>"), raw);
      assertTrue(raw.contains("<gpxtpx:hr>"), raw);
      assertTrue(raw.contains("<power>"), raw);
    }
  }

  @Test
  void sanitize_stripsTimestampsAndSensorsFromEverySerialization() throws Exception {
    GpxDocument doc = GpxSanitizer.sanitize(parseActivity());

    for (String written : serializations(doc)) {
      GpxPrivacyAssertions.assertGpxHasNoPersonalData(written);
      // docs/LEDGER_*.md API-50: no epoch placeholder either, and no borrowed creator.
      assertFalse(written.contains("<time>"), written);
      assertFalse(written.contains("mapstogpx"), written);
    }
  }

  @Test
  void sanitize_keepsGeometry() throws Exception {
    GpxDocument raw = parseActivity();
    GpxDocument doc = GpxSanitizer.sanitize(raw);

    List<GpxTrackPoint> before = raw.getTracks().getFirst().getPoints();
    List<GpxTrackPoint> after = doc.getTracks().getFirst().getPoints();
    assertEquals(before.size(), after.size());
    for (int i = 0; i < before.size(); i++) {
      assertEquals(before.get(i).getLatitudeDeg(), after.get(i).getLatitudeDeg());
      assertEquals(before.get(i).getLongitudeDeg(), after.get(i).getLongitudeDeg());
      assertEquals(before.get(i).getElevationM(), after.get(i).getElevationM());
      assertNull(after.get(i).getTimeEpochMs());
      assertNull(after.get(i).getHeartRate());
      assertNull(after.get(i).getCadence());
      assertNull(after.get(i).getTemperatureC());
      assertNull(after.get(i).getPowerW());
    }
    Path rawPath = GpxToPathJvm.tracksAsPaths(raw).getFirst();
    Path path = GpxToPathJvm.tracksAsPaths(doc).getFirst();
    assertEquals(rawPath.getTotalDistance(), path.getTotalDistance(), 0.001, "distance");
  }

  @Test
  void sanitize_keepsNamesAndWaypoints() throws Exception {
    GpxDocument doc = GpxSanitizer.sanitize(parseActivity());

    assertEquals("Morning Ride", doc.getName());
    assertEquals("Morning Ride", doc.getTracks().getFirst().getName());
    assertEquals(1, doc.getWaypoints().size());
    GpxWaypoint waypoint = doc.getWaypoints().getFirst();
    assertEquals("Café stop", waypoint.getName());
    assertEquals(47.21, waypoint.getLatitudeDeg(), 1e-9);
    assertEquals(-1.545, waypoint.getLongitudeDeg(), 1e-9);
    assertNull(waypoint.getTimeEpochMs());
    assertNull(waypoint.getDescription());
  }

  @Test
  void sanitize_isIdempotent() throws Exception {
    GpxDocument once = GpxSanitizer.sanitize(parseActivity());

    assertEquals(once, GpxSanitizer.sanitize(once));
  }

  @Test
  void sanitize_acceptsADocumentWithNoWaypoints() {
    // What GpxProcessingService.fromPoints builds for a drawn route.
    GpxDocument drawn =
        GpxModelJvm.document(
            List.of(GpxModelJvm.track(List.of(GpxModelJvm.trackPoint(47.2, -1.5)), "drawn")),
            "drawn");

    GpxDocument doc = assertDoesNotThrow(() -> GpxSanitizer.sanitize(drawn));
    assertEquals(drawn, doc);
  }
}
