package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.GeoDistance;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.infrastructure.routedetails.RouteDetailsCapabilities;
import fr.pedalons.infrastructure.routedetails.RouteDetailsOptions;
import fr.pedalons.infrastructure.routedetails.RouteDetailsProfile;
import fr.pedalons.infrastructure.routedetails.RouteDetailsRequest;
import fr.pedalons.infrastructure.routedetails.RouteDetailsSection;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import fr.pedalons.service.surface.RouteSurfaceAnswer;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * The pipeline on the fake osm-route-details (docs/LEDGER_*.md API-150): the profile is chosen per
 * call and each one answers its own flat relief, unless a test gives the fake a terrain.
 */
@QuarkusTest
class GpxPipelineTest extends AbstractBaseTest {

  @Inject GpxPipeline gpxPipeline;

  // ------------------------------------------------------------------ the request

  @Test
  void process_fast_readsTheFastProfile() {
    assertAllElevations(
        gpxPipeline.process(nantesLine(), "test", ElevationQuality.FAST),
        FakeRouteDetailsClient.FAST_ELEVATION);

    RouteDetailsOptions options = FakeRouteDetailsClient.REQUESTS.getLast().options();
    assertEquals(RouteDetailsProfile.FAST, options.profile());
    assertEquals(
        List.of(RouteDetailsSection.ELEVATION, RouteDetailsSection.SUMMARY), options.sections());
    assertEquals(RouteDetailsOptions.INPUT_WITH_BREAKPOINTS, options.sampling().mode());
    assertEquals(150.0, options.elevation().smoothingM());
    assertEquals(Boolean.TRUE, options.acceptPartial());
  }

  @Test
  void process_hd_readsTheFullProfile() {
    assertAllElevations(
        gpxPipeline.process(nantesLine(), "test", ElevationQuality.HD),
        FakeRouteDetailsClient.FULL_ELEVATION);

    RouteDetailsOptions options = FakeRouteDetailsClient.REQUESTS.getLast().options();
    assertEquals(RouteDetailsProfile.FULL, options.profile());
    assertEquals(Boolean.FALSE, options.acceptPartial(), "an outage must be a 503, retried");
  }

  @Test
  void aSparseLine_isDensifiedBeforeTheCall_itsEndsKept() {
    Path source = line(47.2184, -1.5536, 47.2184, -1.5536 + 0.0265);
    assertEquals(2, source.getSize());
    assertTrue(source.getTotalDistance() > 1990, "about 2 km: " + source.getTotalDistance());

    gpxPipeline.process(source, "test", ElevationQuality.FAST);

    List<double[]> sent = sent(FakeRouteDetailsClient.REQUESTS.getLast());
    assertTrue(sent.size() >= 41, "points sent: " + sent.size());
    for (int i = 1; i < sent.size(); i++) {
      double[] a = sent.get(i - 1);
      double[] b = sent.get(i);
      double gap = GeoDistance.haversineMeters(a[1], a[0], b[1], b[0]);
      // Over the 50 m bound by the polyline6 rounding at most
      assertTrue(gap <= 50.2, "gap " + gap + " before point " + i);
    }
    assertEquals(source.longitudeDeg(0), sent.getFirst()[0], 1e-6);
    assertEquals(source.longitudeDeg(1), sent.getLast()[0], 1e-6);
  }

  /** A planner source carries 0 m: without a read, the profile would dip to sea level there. */
  @Test
  void aLineWithoutLength_keepsItsTwoPoints_atTheAltitudeOfTheService() {
    Path source = line(47.2184, -1.5536, 47.2184, -1.5536);

    GpxPipeline.ProcessedWithClimb result =
        gpxPipeline.processWithClimb(source, "test", ElevationQuality.FAST);

    List<double[]> sent = sent(FakeRouteDetailsClient.REQUESTS.getLast());
    assertEquals(2, sent.size());
    double[] a = sent.getFirst();
    double[] b = sent.getLast();
    assertTrue(
        GeoDistance.haversineMeters(a[1], a[0], b[1], b[0]) > 9,
        "two distinct points, or the service would answer a 400");
    assertEquals(2, result.processed().path().getSize());
    assertAllElevations(result.processed().path(), FakeRouteDetailsClient.FAST_ELEVATION);
    assertEquals(47.2184, result.processed().path().latitudeDeg(1), 1e-9);
    assertEquals(0.0, result.processed().fallbackAfterErrorKm());
    assertEquals(0.0, result.processed().path().getReportedElevationGain());
    assertEquals(2, result.climb().length);
  }

  /** 0 m is not a result: the caller must be told, and the HD catch-up must try again. */
  @Test
  void aLineWithoutLength_whoseCallFails_isAFallback() {
    FakeRouteDetailsClient.failFull = true;
    Path source = line(47.2184, -1.5536, 47.2184, -1.5536);

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(source, "test", ElevationQuality.HD);

    assertEquals(2, processed.path().getSize());
    assertTrue(processed.fallbackAfterErrorKm() > 0.0);
  }

  @Test
  void aRouteOverTheBounds_isSliced_andComesBackWhole() {
    // A length bound under the 1.5 km of the line, which is what cuts it: its 41 points fit
    FakeRouteDetailsClient.limits = new RouteDetailsCapabilities.Limits(500, 1_000);
    Path source = nantesLine();

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(source, "test", ElevationQuality.FAST);

    assertTrue(FakeRouteDetailsClient.REQUESTS.size() > 1, "sliced");
    assertAllElevations(processed.path(), FakeRouteDetailsClient.FAST_ELEVATION);
    assertEquals(0.0, processed.fallbackAfterErrorKm());
    assertEquals(source.getTotalDistance(), processed.path().getTotalDistance(), 1.0);
  }

  // ------------------------------------------------------------------ the ascent

  @Test
  void processWithClimb_keepsTheSamePointsAndTheReportedAscent() {
    Path source = nantesLine();
    GpxPipeline.Processed reported =
        gpxPipeline.processReported(source, "test", ElevationQuality.FAST);
    GpxPipeline.ProcessedWithClimb withClimb =
        gpxPipeline.processWithClimb(source, "test", ElevationQuality.FAST);

    Path path = withClimb.processed().path();
    assertEquals(reported.path().getSize(), path.getSize());
    for (int i = 0; i < path.getSize(); i++) {
      assertEquals(reported.path().latitudeDeg(i), path.latitudeDeg(i), 1e-9);
      assertEquals(reported.path().longitudeDeg(i), path.longitudeDeg(i), 1e-9);
      assertEquals(reported.path().elevation(i), path.elevation(i), 1e-9);
    }
    assertEquals(reported.path().getReportedElevationGain(), path.getReportedElevationGain(), 1e-9);
    assertEquals(reported.fallbackAfterErrorKm(), withClimb.processed().fallbackAfterErrorKm());

    double[] climb = withClimb.climb();
    assertEquals(path.getSize(), climb.length);
    assertEquals(0.0, climb[0], 1e-9);
    for (int i = 1; i < climb.length; i++) {
      assertTrue(climb[i] >= climb[i - 1], "climb is non-decreasing at " + i);
    }
    assertEquals(path.getReportedElevationGain(), climb[climb.length - 1], 1e-6);
    assertAllElevations(path, FakeRouteDetailsClient.FAST_ELEVATION);
  }

  @Test
  void processWithClimb_onARealClimb_mapsTheDenseAscentToTheRetainedPoints() {
    // The flat profiles have an ascent of 0, which cannot tell a wrong index mapping from a right
    // one: this terrain climbs to 750 m, then much less steeply, a kink Douglas-Peucker has to
    // keep, and still below the final ascent, or a wrong index would give the same value.
    FakeRouteDetailsClient.terrain = d -> d < 750 ? 0.1 * d : 75.0 + 0.01 * (d - 750);

    GpxPipeline.ProcessedWithClimb withClimb =
        gpxPipeline.processWithClimb(nantesLine(), "test", ElevationQuality.FAST);
    Path path = withClimb.processed().path();
    double[] climb = withClimb.climb();
    int last = climb.length - 1;

    assertEquals(path.getSize(), climb.length);
    assertTrue(path.getReportedElevationGain() > 0.0, "the profile really climbs");
    assertEquals(path.getReportedElevationGain(), climb[last], 1e-6);
    assertEquals(0.0, climb[0], 1e-9);
    assertTrue(path.getSize() >= 3, "a point inside the path to check");
    // The terrain only goes up, so the ascent accumulated up to a point is the rise up to it:
    // climb[k] = gain_cum_m[indices[k]], not gain_cum_m[k].
    boolean inside = false;
    for (int k = 0; k <= last; k++) {
      double rise = path.elevation(k) - path.elevation(0);
      assertEquals(rise, climb[k], 1e-6, "climb at retained point " + k);
      if (k > 0 && k < last && climb[k] > 0.0 && climb[k] < climb[last]) {
        inside = true;
      }
    }
    assertTrue(inside, "an interior point with a partial ascent");
  }

  /**
   * The service's ascent and loss, read before Douglas-Peucker and carried through it: these
   * ripples of 0.6 m (a point every 37.8 m, ten up and ten down) are under its tolerance, so
   * measured on the simplified path they would be gone.
   */
  @Test
  void theReportedAscent_isTheServices_andSurvivesTheSimplification() {
    FakeRouteDetailsClient.terrain = d -> Math.floor(d / 75.0) % 2 == 0 ? 0.0 : 0.6;

    GpxPipeline.ProcessedWithClimb withClimb =
        gpxPipeline.processWithClimb(nantesLine(), "test", ElevationQuality.FAST);
    Path path = withClimb.processed().path();

    assertTrue(path.getSize() <= 3, "the ripples are simplified away: " + path.getSize());
    assertEquals(6.0, path.getReportedElevationGain(), 1e-6);
    assertEquals(-6.0, path.getReportedElevationLoss(), 1e-6);
    assertEquals(6.0, withClimb.climb()[withClimb.climb().length - 1], 1e-6);
  }

  // ------------------------------------------------------------------ degraded answers

  @Test
  void aFastCallThatFails_keepsTheOriginalElevations_overTheWholeLength() {
    FakeRouteDetailsClient.failFast = true;
    Path source = nantesLine();

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(source, "test", ElevationQuality.FAST);

    assertAllElevations(processed.path(), 0.0);
    assertEquals(source.getTotalDistance() / 1000.0, processed.fallbackAfterErrorKm(), 1e-9);
  }

  @Test
  void aFullCallThatFails_isAFallback_soThatTheCatchUpRetries() {
    FakeRouteDetailsClient.failFull = true;
    Path source = nantesLine();

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(source, "test", ElevationQuality.HD);

    assertAllElevations(processed.path(), 0.0);
    assertEquals(source.getTotalDistance() / 1000.0, processed.fallbackAfterErrorKm(), 1e-9);
  }

  /** The failure path measures the file's own relief, climb and ascent consistent as ever. */
  @Test
  void aCallThatFails_stillMeasuresTheAscentOfTheOriginalElevations() {
    FakeRouteDetailsClient.failFast = true;
    List<CoordinatesElevation> coordinates = new ArrayList<>();
    for (int i = 0; i <= 20; i++) {
      coordinates.add(new LatLonElevation(47.2184, -1.5536 + i * 0.001, 5.0 * i));
    }

    GpxPipeline.ProcessedWithClimb withClimb =
        gpxPipeline.processWithClimb(
            PathJvm.fromCoordinates(coordinates), "test", ElevationQuality.FAST);
    Path path = withClimb.processed().path();
    double[] climb = withClimb.climb();

    assertTrue(path.getReportedElevationGain() > 50.0, "" + path.getReportedElevationGain());
    assertEquals(path.getSize(), climb.length);
    assertEquals(path.getReportedElevationGain(), climb[climb.length - 1], 1e-6);
  }

  @Test
  void aTerrainFallback_isCountedOverItsRange_theAnswerKept() {
    FakeRouteDetailsClient.fallbackAfterError = true;
    Path source = nantesLine();

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(source, "test", ElevationQuality.HD);

    assertAllElevations(processed.path(), FakeRouteDetailsClient.FULL_ELEVATION);
    assertEquals(source.getTotalDistance() / 1000.0, processed.fallbackAfterErrorKm(), 0.01);
  }

  /** {@code elevation_missing} is out of coverage, which no retry changes: filled, not counted. */
  @Test
  void aRangeWithoutElevation_isFilled_andIsNoFallback() {
    FakeRouteDetailsClient.partial = true;

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.FAST);

    assertEquals(0.0, processed.fallbackAfterErrorKm());
    assertAllElevations(processed.path(), FakeRouteDetailsClient.FAST_ELEVATION);
  }

  // ------------------------------------------------------------------ the surface (API-150)

  private static final List<RouteDetailsSection> ALL_SECTIONS =
      List.of(
          RouteDetailsSection.ELEVATION, RouteDetailsSection.TYPOLOGY, RouteDetailsSection.SUMMARY);

  private static final List<RouteDetailsSection> NO_TYPOLOGY =
      List.of(RouteDetailsSection.ELEVATION, RouteDetailsSection.SUMMARY);

  @Test
  void anHdCallWithoutTheSurface_asksNoTypology() {
    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.HD);

    assertEquals(NO_TYPOLOGY, FakeRouteDetailsClient.REQUESTS.getLast().options().sections());
    assertNull(processed.surface());
  }

  @Test
  void anHdCallWithTheSurface_asksAllThreeSections_inOneCall() {
    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.HD, true);

    assertEquals(1, FakeRouteDetailsClient.REQUESTS.size());
    RouteDetailsOptions options = FakeRouteDetailsClient.REQUESTS.getLast().options();
    assertEquals(ALL_SECTIONS, options.sections());
    assertEquals(RouteDetailsProfile.FULL, options.profile());
    assertEquals(Boolean.FALSE, options.acceptPartial(), "an outage must be a 503, retried");
    assertAllElevations(processed.path(), FakeRouteDetailsClient.FULL_ELEVATION);

    RouteSurfaceAnswer answer = processed.surface();
    assertEquals(1, answer.segments().size());
    assertTrue(answer.complete());
    assertEquals(FakeRouteDetailsClient.DATA_VERSIONS, answer.dataVersions());
  }

  @Test
  void aFastCall_neverAsksTheTypology() {
    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.FAST, true);

    assertEquals(NO_TYPOLOGY, FakeRouteDetailsClient.REQUESTS.getLast().options().sections());
    assertNull(processed.surface());
  }

  @Test
  void theTwoArgumentsResult_hasNoSurface() {
    assertNull(new GpxPipeline.Processed(nantesLine(), 0.0).surface());
  }

  @Test
  void theAnchors_pairEachStoredPoint_withItsDistanceInTheAnswer() {
    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.HD, true);

    Path path = processed.path();
    RouteSurfaceAnswer answer = processed.surface();
    assertEquals(path.getSize(), answer.answerM().length);
    assertEquals(path.getSize(), answer.storedM().length);
    assertEquals(0.0, answer.answerM()[0]);
    assertEquals(0.0, answer.storedM()[0]);
    for (int k = 0; k < path.getSize(); k++) {
      assertEquals(path.distance(k), answer.storedM()[k], 1e-9);
    }
    assertEquals(path.distance(path.getSize() - 1), answer.storedLength(), 1e-9);
  }

  /** The jitter of a recording stays in {@code d_m} and leaves the stored distance: two axes. */
  @Test
  void theJitterOfARecording_stretchesTheAnswerOverTheStoredTrack() {
    List<CoordinatesElevation> coordinates = new ArrayList<>();
    for (int i = 0; i <= 200; i++) {
      double jitter = i % 2 == 0 ? 0.00002 : -0.00002;
      coordinates.add(new LatLonElevation(47.2184 + jitter, -1.5536 + i * 0.00006, 0.0));
    }

    RouteSurfaceAnswer answer =
        gpxPipeline
            .processReported(
                PathJvm.fromCoordinates(coordinates), "test", ElevationQuality.HD, true)
            .surface();

    int last = answer.answerM().length - 1;
    assertTrue(last < 200, "Douglas-Peucker took points away: " + last);
    assertTrue(
        answer.answerM()[last] > answer.storedM()[last] + 5,
        answer.answerM()[last] + " along the answer, " + answer.storedM()[last] + " stored");
  }

  @Test
  void aSlicedRoute_comesBackWithOneTypology_onTheWholeAxis() {
    FakeRouteDetailsClient.limits = new RouteDetailsCapabilities.Limits(500, 1_000);
    Path source = nantesLine();

    RouteSurfaceAnswer answer =
        gpxPipeline.processReported(source, "test", ElevationQuality.HD, true).surface();

    assertTrue(FakeRouteDetailsClient.REQUESTS.size() > 1, "sliced");
    assertTrue(
        FakeRouteDetailsClient.REQUESTS.stream()
            .allMatch(r -> r.options().sections().contains(RouteDetailsSection.TYPOLOGY)));
    assertEquals(1, answer.segments().size(), "equal neighbours merged");
    assertEquals(0.0, answer.segments().getFirst().fromM());
    assertEquals(
        answer.answerM()[answer.answerM().length - 1],
        answer.segments().getFirst().toM(),
        1e-3,
        "the segments and the points share one axis");
    assertEquals(source.getTotalDistance(), answer.storedLength(), 1.0);
  }

  @Test
  void aFailedCall_hasNoSurface() {
    FakeRouteDetailsClient.failFull = true;

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.HD, true);

    assertTrue(processed.fallbackAfterErrorKm() > 0.0);
    assertNull(processed.surface());
  }

  @Test
  void aTerrainFallback_keepsTheSurfaceOfItsAnswer() {
    FakeRouteDetailsClient.fallbackAfterError = true;

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.HD, true);

    assertTrue(processed.fallbackAfterErrorKm() > 0.0);
    assertTrue(processed.surface().complete());
  }

  @Test
  void aPartialAnswer_isNotComplete() {
    FakeRouteDetailsClient.partial = true;

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.HD, true);

    assertEquals(0.0, processed.fallbackAfterErrorKm());
    assertFalse(processed.surface().complete());
  }

  /** The probe stands in for a degenerate track: its typology would describe the probe's line. */
  @Test
  void aLineWithoutLength_asksNoTypology_andHasNothingToProject() {
    Path source = line(47.2184, -1.5536, 47.2184, -1.5536);

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(source, "test", ElevationQuality.HD, true);

    assertEquals(NO_TYPOLOGY, FakeRouteDetailsClient.REQUESTS.getLast().options().sections());
    assertTrue(processed.surface().segments().isEmpty());
  }

  @Test
  void anAnswerWithoutSegments_hasNoSurface_andKeepsItsProfile() {
    FakeRouteDetailsClient.segmentsOf = length -> null;

    GpxPipeline.Processed processed =
        gpxPipeline.processReported(nantesLine(), "test", ElevationQuality.HD, true);

    assertNull(processed.surface());
    assertEquals(0.0, processed.fallbackAfterErrorKm());
    assertAllElevations(processed.path(), FakeRouteDetailsClient.FULL_ELEVATION);
  }

  // ------------------------------------------------------------------ fixtures

  /** What a request carries, as {@code [lon, lat]} pairs. */
  private static List<double[]> sent(RouteDetailsRequest request) {
    return Polyline6Decoder.decode(request.polyline());
  }

  private static void assertAllElevations(Path path, double expected) {
    assertTrue(path.getSize() >= 2);
    for (int i = 0; i < path.getSize(); i++) {
      assertEquals(expected, path.elevation(i), 1.0, "elevation of point " + i);
    }
  }

  private static Path line(double latA, double lonA, double latB, double lonB) {
    return PathJvm.fromCoordinates(
        List.of(new LatLonElevation(latA, lonA, 0.0), new LatLonElevation(latB, lonB, 0.0)));
  }

  /** About 1.5 km east of Nantes, a point every 75 m, with deliberately wrong elevations (0 m). */
  private static Path nantesLine() {
    List<CoordinatesElevation> coordinates = new ArrayList<>();
    for (int i = 0; i <= 20; i++) {
      coordinates.add(new LatLonElevation(47.2184, -1.5536 + i * 0.001, 0.0));
    }
    return PathJvm.fromCoordinates(coordinates);
  }
}
