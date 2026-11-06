package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.OutputPoint;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Structure;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Freezes the parsing of a real answer (plan §8, docs/LEDGER_*.md API-150): {@code full}, api 1.6,
 * rules 2026.11.13, recorded on 2026-11-06 from a local osm-route-details for the 875 m from Rezé to
 * the north end of the Pont de Pirmil, in Nantes — two bridges (Pont de Pont-Rousseau over the
 * Sèvre, Pont de Pirmil over the Loire), both read on the IGN surface model. The request is beside
 * it ({@code nantes-reze-pirmil-request.json}), what {@link RouteDetailsOptions#of} sends, as a
 * polyline6. No tunnel on that route: the tunnels of the fixture set are all in the Vercors.
 */
class RouteDetailsFixtureTest {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  static RouteDetailsResponse fixture() throws IOException {
    try (InputStream in =
        RouteDetailsFixtureTest.class.getResourceAsStream(
            "/routedetails/nantes-reze-pirmil-full.json")) {
      assertNotNull(in);
      return MAPPER.readValue(in, RouteDetailsResponse.class);
    }
  }

  @Test
  void aRecordedFullAnswer_isRead() throws IOException {
    RouteDetailsResponse r = fixture();
    assertEquals("1.6", r.meta().apiVersion());
    assertEquals("2026.11.13", r.meta().rulesVersion());
    assertEquals("full", r.meta().profile());
    assertNotNull(r.meta().dataVersions());
    assertEquals(RouteDetailsResponse.STATUS_COMPLETE, r.status());
    assertFalse(r.isPartial());

    List<OutputPoint> points = r.points();
    assertEquals(10, points.size());
    OutputPoint inserted = points.get(5);
    assertTrue(inserted.isInserted());
    assertEquals(4, inserted.index());
    assertEquals(List.of("local_min"), inserted.reasons());
    assertEquals(47.197051, inserted.lat(), 1e-9);
    assertEquals(-1.543315, inserted.lon(), 1e-9);
    OutputPoint deck = points.get(7);
    assertEquals(6, deck.index());
    assertEquals("dsm_deck", deck.eleMethod());
    assertEquals(12.35, deck.ele(), 1e-9);
    assertEquals(11.61, deck.eleSmoothed(), 1e-9);
    assertEquals(5.28, deck.gainCumM(), 1e-9);
    OutputPoint end = points.getLast();
    assertEquals(8, end.index());
    assertEquals(874.64, end.dM(), 1e-9);
    assertEquals(r.summary().gainM(), end.gainCumM(), 1e-9);
    assertEquals(r.summary().lossM(), end.lossCumM(), 1e-9);
    assertNull(points.getFirst().lat());

    List<Segment> segments = r.segments();
    assertEquals(6, segments.size());
    Segment pirmil = segments.get(4);
    assertEquals("bridge", pirmil.structure());
    assertEquals("osm_heuristic", pirmil.structureSource());
    assertEquals("paved", pirmil.surface().surfaceClass());
    assertEquals("asphalt", pirmil.surface().detail());
    assertEquals("tagged", pirmil.surface().source());
    assertEquals("major_road", pirmil.wayKind());
    assertTrue(pirmil.matched());
    assertEquals(5, pirmil.fromIndex());
    assertEquals(7, pirmil.toIndex());
    assertNull(segments.getFirst().structureSource());

    assertEquals(874.64, r.summary().lengthM(), 1e-9);
    List<Structure> structures = r.summary().structures();
    assertEquals(2, structures.size());
    assertEquals("dsm_deck", structures.get(1).method());
    assertEquals(221.91, structures.get(1).lengthM(), 1e-9);
    assertEquals(874.64, r.summary().terrainM().get("ign_lidar_hd"), 1e-9);

    assertEquals(1, r.quality().terrain().size());
    assertEquals("ign_lidar_hd", r.quality().terrain().getFirst().origin());
    assertFalse(r.quality().terrain().getFirst().fallbackAfterError());
    assertTrue(r.quality().warnings().isEmpty());
    assertEquals("applied", r.quality().structureCorrection().get("bridges").asText());
  }

  @Test
  void theRecordedRequest_isTheOneTheOptionsWrite() throws IOException {
    try (InputStream in =
        RouteDetailsFixtureTest.class.getResourceAsStream(
            "/routedetails/nantes-reze-pirmil-request.json")) {
      assertNotNull(in);
      RouteDetailsRequest request =
          RouteDetailsRequest.ofPolyline6(
              MAPPER.readTree(in).get("polyline").asText(),
              RouteDetailsOptions.of(RouteDetailsProfile.FULL, false));
      assertEquals(
          MAPPER.readTree(
              RouteDetailsFixtureTest.class.getResourceAsStream(
                  "/routedetails/nantes-reze-pirmil-request.json")),
          MAPPER.valueToTree(request));
    }
  }
}
