package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import fr.pedalons.enums.TrackSurface;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Surface;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;

/** The table of plan §5.2 (decision D6), and a track's answer turned into its stored document. */
class RouteDetailsSurfacesTest {

  private static final Instant NOW = Instant.parse("2026-11-06T08:00:00Z");

  private static Surface surface(String surfaceClass, String detail) {
    return new Surface(surfaceClass, detail, "tagged");
  }

  private static Segment segment(double from, double to, Surface surface, String wayKind) {
    return new Segment(from, to, 0, 0, "ground", null, surface, wayKind, true);
  }

  private static Segment paved(double from, double to) {
    return segment(from, to, surface("paved", "asphalt"), "minor_road");
  }

  private static Segment unmatched(double from, double to) {
    return new Segment(from, to, 0, 0, null, null, new Surface("unknown", null, null), null, false);
  }

  /** An answer whose axis is the stored one. */
  private static RouteSurfaceAnswer sameAxis(double length, Segment... segments) {
    return new RouteSurfaceAnswer(
        List.of(segments), new double[] {0, length}, new double[] {0, length}, null, true);
  }

  private static TrackSurfaceDocument document(RouteSurfaceAnswer answer) {
    return RouteDetailsSurfaces.document(answer, List.of(), NOW);
  }

  // ==================== The table ====================

  @ParameterizedTest
  @CsvSource({
    "paved,asphalt,PAVED",
    "paved,concrete,PAVED",
    "paved,paving_stones,PAVED",
    "unpaved,wood,PAVED",
    "paved,sett,PAVED_ROUGH",
    "paved,cobblestone,PAVED_ROUGH",
    "unpaved,compacted,GRAVEL",
    "unpaved,fine_gravel,GRAVEL",
    "unpaved,gravel,GRAVEL",
    "unpaved,dirt,DIRT",
    "unpaved,sand,DIRT",
    "unpaved,grass,DIRT",
    "unpaved,rock,PATH"
  })
  void aDetailDecides(String surfaceClass, String detail, TrackSurface expected) {
    // Whatever the way: the detail is what the tag said
    assertEquals(expected, RouteDetailsSurfaces.project(surface(surfaceClass, detail), "path"));
    assertEquals(expected, RouteDetailsSurfaces.project(surface(surfaceClass, detail), "track"));
  }

  @ParameterizedTest
  @CsvSource(
      nullValues = "null",
      value = {
        "paved,null,PAVED",
        "paved,path,PAVED",
        "unpaved,path,PATH",
        "unpaved,footway,PATH",
        "unpaved,steps,PATH",
        "unpaved,track,GRAVEL",
        "unpaved,minor_road,GRAVEL",
        "unpaved,null,GRAVEL",
        "unknown,path,UNKNOWN",
        "null,path,UNKNOWN"
      })
  void withoutDetail_theClassAndTheWayDecide(
      String surfaceClass, String wayKind, TrackSurface expected) {
    assertEquals(expected, RouteDetailsSurfaces.project(surface(surfaceClass, null), wayKind));
  }

  @Test
  void anUnknownDetail_fallsBackOnTheClass() {
    assertEquals(
        TrackSurface.PAVED,
        RouteDetailsSurfaces.project(surface("paved", "a_later_value"), "minor_road"));
    assertEquals(
        TrackSurface.PATH,
        RouteDetailsSurfaces.project(surface("unpaved", "a_later_value"), "path"));
    assertEquals(
        TrackSurface.GRAVEL,
        RouteDetailsSurfaces.project(surface("unpaved", "a_later_value"), "track"));
    assertEquals(
        TrackSurface.UNKNOWN,
        RouteDetailsSurfaces.project(surface("unknown", "a_later_value"), "track"));
  }

  @Test
  void noTypology_isUnknown() {
    assertEquals(TrackSurface.UNKNOWN, RouteDetailsSurfaces.project(null, "track"));
    assertEquals(TrackSurface.UNKNOWN, RouteDetailsSurfaces.project(null, null));
  }

  @Test
  void aWayClosedToBicycles_keepsItsSurface() {
    Segment closed =
        new Segment(0, 500, 0, 0, null, null, surface("paved", "asphalt"), "cycleway", false);
    TrackSurfaceDocument doc = document(sameAxis(500, closed));

    assertTrue(doc.ok());
    assertEquals(List.of(new SurfaceRange(0, 500, "paved")), doc.surfaces());
    assertEquals(Boolean.FALSE, doc.ways().getFirst().matched());
  }

  @Test
  void offTheNetworkWithoutTypology_isUnknown() {
    TrackSurfaceDocument doc = document(sameAxis(1000, paved(0, 500), unmatched(500, 1000)));

    assertEquals(
        List.of(new SurfaceRange(0, 500, "paved"), new SurfaceRange(500, 1000, "unknown")),
        doc.surfaces());
  }

  @ParameterizedTest
  @EnumSource(TrackSurface.class)
  void everyClass_readsBackFromItsCode(TrackSurface surface) {
    assertEquals(surface, TrackSurface.ofCode(surface.code()));
  }

  // ==================== The axis ====================

  @Test
  void aBoundary_followsTheAnchorsAroundIt() {
    // A stop: 100 m of jitter in d_m between 1000 and 1100 m, nothing on the stored line
    double[] answer = {0, 1000, 1100, 2100};
    double[] stored = {0, 1000, 1000, 2000};

    assertEquals(0, RouteDetailsSurfaces.toStored(0, answer, stored), 1e-9);
    assertEquals(500, RouteDetailsSurfaces.toStored(500, answer, stored), 1e-9);
    assertEquals(1000, RouteDetailsSurfaces.toStored(1050, answer, stored), 1e-9);
    // A rescale of the whole length would put this at about 1524 m
    assertEquals(1500, RouteDetailsSurfaces.toStored(1600, answer, stored), 1e-9);
    assertEquals(2000, RouteDetailsSurfaces.toStored(2100, answer, stored), 1e-9);
  }

  @Test
  void aBoundaryOutsideTheAnchors_isClamped() {
    double[] answer = {10, 110};
    double[] stored = {0, 100};

    assertEquals(0, RouteDetailsSurfaces.toStored(-5, answer, stored), 1e-9);
    assertEquals(100, RouteDetailsSurfaces.toStored(500, answer, stored), 1e-9);
  }

  @Test
  void twoPointsAtTheSameDistance_doNotDivideByZero() {
    double[] answer = {0, 50, 50, 100};
    double[] stored = {0, 40, 60, 100};

    assertEquals(60, RouteDetailsSurfaces.toStored(50, answer, stored), 1e-9);
    assertEquals(80, RouteDetailsSurfaces.toStored(75, answer, stored), 1e-9);
  }

  @Test
  void theDocument_isOnTheStoredAxis() {
    RouteSurfaceAnswer answer =
        new RouteSurfaceAnswer(
            List.of(paved(0, 1600), segment(1600, 2100, surface("unpaved", "gravel"), "track")),
            new double[] {0, 1000, 1100, 2100},
            new double[] {0, 1000, 1000, 2000},
            null,
            true);

    TrackSurfaceDocument doc = document(answer);

    assertEquals(2000, doc.distance(), 1e-9);
    assertEquals(
        List.of(new SurfaceRange(0, 1500, "paved"), new SurfaceRange(1500, 2000, "gravel")),
        doc.surfaces());
  }

  // ==================== The document ====================

  @Test
  void aDocument_isVersion2_andKeepsTheRawValues() {
    JsonNode versions = JsonNodeFactory.instance.objectNode().put("versatiles", "2026-10-27");
    Segment bridge =
        new Segment(
            0,
            1000,
            0,
            0,
            "bridge",
            "osm",
            new Surface("unpaved", "fine_gravel", "tagged"),
            "track",
            true);

    TrackSurfaceDocument doc =
        document(
            new RouteSurfaceAnswer(
                List.of(bridge), new double[] {0, 1000}, new double[] {0, 1000}, versions, true));

    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, doc.version());
    assertTrue(doc.ok());
    assertEquals("bicycle", doc.costing());
    assertNull(doc.osmChangeset());
    assertEquals(versions, doc.dataVersions());
    assertEquals(NOW, doc.computedAt());
    assertEquals(List.of(new SurfaceRange(0, 1000, "gravel")), doc.surfaces());
    assertEquals(
        List.of(new WayRange(0, 1000, "track", null, "bridge", true, "unpaved", "fine_gravel")),
        doc.ways());
  }

  @Test
  void aStretchTooShort_isAbsorbedOnTheClassesTheClientsSee() {
    TrackSurfaceDocument doc =
        document(
            sameAxis(
                1000,
                paved(0, 500),
                segment(500, 510, surface("unpaved", "gravel"), "track"),
                segment(510, 1000, surface("paved", "concrete"), "minor_road")));

    // asphalt and concrete are one class: without the gravel, one span
    assertEquals(List.of(new SurfaceRange(0, 1000, "paved")), doc.surfaces());
  }

  @Test
  void aPieceDrawnOffTheNetwork_isLaidOver() {
    TrackSurfaceDocument doc =
        RouteDetailsSurfaces.document(
            sameAxis(1000, paved(0, 1000)), List.of(new double[] {300, 600}), NOW);

    assertEquals(
        List.of(
            new SurfaceRange(0, 300, "paved"),
            new SurfaceRange(300, 600, "off_network"),
            new SurfaceRange(600, 1000, "paved")),
        doc.surfaces());
    assertEquals("off_network", doc.ways().get(1).use());
    assertEquals(TrackSurface.OFF_NETWORK, TrackSurface.ofCode(doc.surfaces().get(1).code()));
  }

  @Test
  void aTrackDrawnEntirelyOffTheNetwork_isReady() {
    TrackSurfaceDocument doc =
        RouteDetailsSurfaces.document(
            sameAxis(1000, unmatched(0, 1000)), List.of(new double[] {0, 1000}), NOW);

    assertTrue(doc.ok());
    assertEquals(List.of(new SurfaceRange(0, 1000, "off_network")), doc.surfaces());
  }

  @Test
  void nothingKnownOfTheWholeTrack_isUnavailable() {
    TrackSurfaceDocument doc = document(sameAxis(1000, unmatched(0, 1000)));

    assertFalse(doc.ok());
    assertEquals(RouteDetailsSurfaces.NO_TYPOLOGY, doc.reason());
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, doc.version());
    assertEquals(1000, doc.distance(), 1e-9);
  }

  @Test
  void aDegenerateTrack_isTooShort() {
    TrackSurfaceDocument doc = document(RouteSurfaceAnswer.degenerate(0.4, null, true));

    assertFalse(doc.ok());
    assertEquals(RouteDetailsSurfaces.TOO_SHORT, doc.reason());
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, doc.version());
  }

  @Test
  void underAMetre_isTooShort_evenWithSegments() {
    assertEquals(RouteDetailsSurfaces.TOO_SHORT, document(sameAxis(0.5, paved(0, 0.5))).reason());
  }

  @Test
  void whatTheSegmentsLeaveUncovered_isUnknown() {
    TrackSurfaceDocument doc = document(sameAxis(1000, paved(0, 800)));

    assertEquals(
        List.of(new SurfaceRange(0, 800, "paved"), new SurfaceRange(800, 1000, "unknown")),
        doc.surfaces());
    assertEquals(new WayRange(800, 1000, null, null), doc.ways().get(1));
  }
}
