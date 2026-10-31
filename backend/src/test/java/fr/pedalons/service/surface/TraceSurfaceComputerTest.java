package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.GeoDistance;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import fr.pedalons.infrastructure.valhalla.TraceAttributesRequest;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse;
import fr.pedalons.service.surface.TraceSurfaceComputer.TransientTraceException;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;
import org.junit.jupiter.api.Test;

class TraceSurfaceComputerTest {

  private static final Instant NOW = Instant.parse("2026-10-20T08:00:00Z");

  private static TrackSurfaceDocument compute(
      List<TrackPoint> points,
      List<double[]> offNetwork,
      Function<TraceAttributesRequest, TraceAttributesResponse> call) {
    return TraceSurfaceComputer.compute(points, null, "bicycle", offNetwork, NOW, call);
  }

  private static WebApplicationException error(int status, int valhallaCode) {
    return new WebApplicationException(
        Response.status(status).entity("{\"error_code\":" + valhallaCode + "}").build());
  }

  private static void assertContiguous(TrackSurfaceDocument doc, double length) {
    List<SurfaceRange> ranges = doc.surfaces();
    assertEquals(0, ranges.getFirst().from(), 0);
    assertEquals(length, ranges.getLast().to(), 0.1);
    for (int i = 1; i < ranges.size(); i++) {
      assertEquals(ranges.get(i - 1).to(), ranges.get(i).from(), 0);
    }
  }

  @Test
  void oneSliceForAShortTrack() {
    List<TrackPoint> points = TraceFixtures.line(11, 100);
    List<TraceAttributesRequest> requests = new ArrayList<>();
    TrackSurfaceDocument doc =
        compute(
            points,
            List.of(),
            request -> {
              requests.add(request);
              return TraceFixtures.answer(request, i -> i < 5 ? "paved" : "gravel");
            });
    assertEquals(1, requests.size());
    assertTrue(doc.ok());
    assertEquals(190_674_135L, doc.osmChangeset());
    assertEquals("bicycle", doc.costing());
    assertEquals(points.getLast().dist(), doc.distance(), 0);
    assertEquals(2, doc.surfaces().size());
    assertEquals("paved", doc.surfaces().get(0).code());
    assertEquals("gravel", doc.surfaces().get(1).code());
    assertEquals(500, doc.surfaces().get(0).to(), 1);
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void theRequestIsMapSnapWithTheExpectedFiltersAndNoCostingOptions() throws Exception {
    List<TraceAttributesRequest> requests = new ArrayList<>();
    compute(
        TraceFixtures.line(11, 100),
        List.of(),
        request -> {
          requests.add(request);
          return TraceFixtures.answer(request, i -> "paved");
        });
    TraceAttributesRequest request = requests.getFirst();
    assertEquals("map_snap", request.shapeMatch());
    assertEquals("bicycle", request.costing());
    assertEquals("include", request.filters().action());
    assertTrue(
        request
            .filters()
            .attributes()
            .containsAll(List.of("edge.surface", "shape", "osm_changeset")));
    String json = new ObjectMapper().writeValueAsString(request);
    assertFalse(json.contains("costing_options"));
    assertFalse(json.contains("avoid_bad_surfaces"));
    assertTrue(json.contains("\"shape_match\":\"map_snap\""));
    assertTrue(json.contains("\"encoded_polyline\""));
  }

  @Test
  void aLongTrackIsSlicedWithAnOverlapAndWithoutGapsOrOverlaps() {
    // 450 km, a point every 100 m
    List<TrackPoint> points = TraceFixtures.line(4501, 100);
    List<TraceAttributesRequest> requests = new ArrayList<>();
    TrackSurfaceDocument doc =
        compute(
            points,
            List.of(),
            request -> {
              requests.add(request);
              return TraceFixtures.answer(request, i -> "paved");
            });
    assertEquals(3, requests.size());
    for (TraceAttributesRequest request : requests) {
      List<double[]> sent = Polyline6Decoder.decode(request.encodedPolyline());
      assertTrue(sent.size() <= TraceSurfaceComputer.MAX_POINTS);
      double span =
          GeoDistance.haversineMeters(
              sent.getFirst()[1], sent.getFirst()[0], sent.getLast()[1], sent.getLast()[0]);
      assertTrue(span <= TraceSurfaceComputer.MAX_REQUEST_M, "span " + span);
    }
    // The second request starts 500 m before the end of the first core
    double[] second = Polyline6Decoder.decode(requests.get(1).encodedPolyline()).getFirst();
    double start = GeoDistance.haversineMeters(48, 2, second[1], second[0]);
    assertEquals(TraceSurfaceComputer.CORE_M - TraceSurfaceComputer.OVERLAP_M, start, 100);
    assertEquals(1, doc.surfaces().size());
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void theSlicesArePutBackWhereTheyBelong() {
    // 450 km, gravel across the end of the first core (188 km) and further on in the second
    List<TrackPoint> points = TraceFixtures.line(4501, 100);
    int[] calls = {0};
    TrackSurfaceDocument doc =
        compute(
            points,
            List.of(),
            request -> {
              calls[0]++;
              return TraceFixtures.answerAlong(
                  request,
                  m ->
                      (m > 187_500 && m < 188_600) || (m > 300_000 && m < 300_500)
                          ? "gravel"
                          : "paved");
            });
    assertEquals(3, calls[0]);
    List<SurfaceRange> ranges = doc.surfaces();
    assertEquals(5, ranges.size(), ranges.toString());
    double[][] expected = {
      {0, 187_500}, {187_500, 188_600}, {188_600, 300_000}, {300_000, 300_500}
    };
    for (int i = 0; i < expected.length; i++) {
      assertEquals(i % 2 == 0 ? "paved" : "gravel", ranges.get(i).code());
      assertEquals(expected[i][0], ranges.get(i).from(), 1);
      assertEquals(expected[i][1], ranges.get(i).to(), 1);
    }
    assertEquals("paved", ranges.getLast().code());
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void theSlicesOfADenseTrackArePutBackWhereTheyBelong() {
    // 100 km, a point every 5 m: the first slice is cut by its point count, about 74.5 km in
    List<TrackPoint> points = TraceFixtures.line(20_001, 5);
    TrackSurfaceDocument doc =
        compute(
            points,
            List.of(),
            request ->
                TraceFixtures.answerAlong(
                    request, m -> m > 74_000 && m < 75_000 ? "dirt" : "paved"));
    List<SurfaceRange> ranges = doc.surfaces();
    assertEquals(3, ranges.size(), ranges.toString());
    assertEquals("dirt", ranges.get(1).code());
    assertEquals(74_000, ranges.get(1).from(), 1);
    assertEquals(75_000, ranges.get(1).to(), 1);
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void aDenseTrackIsSlicedByPointCount() {
    // 100 km, a point every 5 m: 20 001 points
    List<TrackPoint> points = TraceFixtures.line(20_001, 5);
    List<TraceAttributesRequest> requests = new ArrayList<>();
    TrackSurfaceDocument doc =
        compute(
            points,
            List.of(),
            request -> {
              requests.add(request);
              return TraceFixtures.answer(request, i -> "paved");
            });
    assertEquals(2, requests.size());
    for (TraceAttributesRequest request : requests) {
      assertTrue(
          Polyline6Decoder.decode(request.encodedPolyline()).size()
              <= TraceSurfaceComputer.MAX_POINTS);
    }
    assertEquals(1, doc.surfaces().size());
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void aSliceTheProviderCannotMatchIsUnknownAndTheRestStays() {
    List<TrackPoint> points = TraceFixtures.line(4501, 100);
    int[] calls = {0};
    TrackSurfaceDocument doc =
        compute(
            points,
            List.of(),
            request -> {
              if (++calls[0] == 2) {
                throw error(400, 171);
              }
              return TraceFixtures.answer(request, i -> "paved");
            });
    assertTrue(doc.ok());
    assertEquals(3, doc.surfaces().size());
    assertEquals("paved", doc.surfaces().get(0).code());
    assertEquals("unknown", doc.surfaces().get(1).code());
    assertEquals("paved", doc.surfaces().get(2).code());
    assertEquals(TraceSurfaceComputer.CORE_M, doc.surfaces().get(1).from(), 0.1);
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void aTrackEverySliceOfWhichIsRefusedIsUnavailable() {
    TrackSurfaceDocument doc =
        compute(
            TraceFixtures.line(11, 100),
            List.of(),
            request -> {
              throw error(400, 444);
            });
    assertFalse(doc.ok());
    assertEquals("unavailable", doc.status());
    assertEquals("valhalla-444", doc.reason());
    assertTrue(doc.surfaces().isEmpty());
  }

  @Test
  void anyOtherFailureFailsTheWholeTrack() {
    for (int status : new int[] {429, 503, 401, 403, 404}) {
      assertThrows(
          TransientTraceException.class,
          () ->
              compute(
                  TraceFixtures.line(11, 100),
                  List.of(),
                  request -> {
                    throw error(status, -1);
                  }),
          "status " + status);
    }
    assertThrows(
        TransientTraceException.class,
        () ->
            compute(
                TraceFixtures.line(11, 100),
                List.of(),
                request -> {
                  throw new ProcessingException("connection reset");
                }));
    // A 400 of another kind is not a verdict on the track either
    assertThrows(
        TransientTraceException.class,
        () ->
            compute(
                TraceFixtures.line(11, 100),
                List.of(),
                request -> {
                  throw error(400, 100);
                }));
  }

  @Test
  void aTransientFailureOfALaterSliceDiscardsTheEarlierOnes() {
    int[] calls = {0};
    assertThrows(
        TransientTraceException.class,
        () ->
            compute(
                TraceFixtures.line(4501, 100),
                List.of(),
                request -> {
                  if (++calls[0] == 2) {
                    throw error(503, -1);
                  }
                  return TraceFixtures.answer(request, i -> "paved");
                }));
  }

  @Test
  void aTrackWithNothingToMatchIsUnavailableWithoutACall() {
    for (List<TrackPoint> points :
        List.of(
            TraceFixtures.line(1, 100),
            List.<TrackPoint>of(),
            List.of(new TrackPoint(48, 2, 0, 0), new TrackPoint(48, 2, 0, 0)))) {
      TrackSurfaceDocument doc =
          compute(
              points,
              List.of(),
              request -> {
                throw new AssertionError("no call expected");
              });
      assertEquals("too-short", doc.reason());
      assertFalse(doc.ok());
    }
  }

  @Test
  void straightPiecesAreOffNetwork() {
    List<TrackPoint> points = TraceFixtures.line(21, 100);
    TrackSurfaceDocument doc =
        compute(
            points,
            List.of(new double[] {600, 1200}),
            request -> TraceFixtures.answer(request, i -> "paved"));
    assertEquals(3, doc.surfaces().size());
    assertEquals("off_network", doc.surfaces().get(1).code());
    assertEquals(600, doc.surfaces().get(1).from(), 0.1);
    assertEquals(1200, doc.surfaces().get(1).to(), 0.1);
    assertEquals("off_network", doc.ways().get(1).use());
  }

  // ------------------------------------------------------------------ raw line (API-147, B)

  private static TrackSurfaceDocument computeRaw(
      List<TrackPoint> points,
      List<double[]> raw,
      List<double[]> offNetwork,
      Function<TraceAttributesRequest, TraceAttributesResponse> call) {
    return TraceSurfaceComputer.compute(points, raw, "bicycle", offNetwork, NOW, call);
  }

  @Test
  void theRawLineIsSent_notTheStoredPoints() {
    List<TrackPoint> points = TraceFixtures.line(11, 100);
    List<double[]> raw = TraceFixtures.rawLine(101, 10, 0, 0);
    List<TraceAttributesRequest> requests = new ArrayList<>();
    TrackSurfaceDocument doc =
        computeRaw(
            points,
            raw,
            List.of(),
            request -> {
              requests.add(request);
              return TraceFixtures.answer(request, i -> "paved");
            });
    assertEquals(1, requests.size());
    List<double[]> sent = Polyline6Decoder.decode(requests.getFirst().encodedPolyline());
    assertEquals(raw.size(), sent.size());
    assertEquals(points.getLast().dist(), doc.distance(), 0);
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void withoutAUsableRawLine_theStoredPointsAreSent() {
    List<TrackPoint> points = TraceFixtures.line(11, 100);
    List<double[]> one = List.of(new double[] {2, 48});
    List<double[]> still = List.of(new double[] {2, 48}, new double[] {2, 48});
    for (List<double[]> raw : java.util.Arrays.asList(null, one, still)) {
      List<TraceAttributesRequest> requests = new ArrayList<>();
      computeRaw(
          points,
          raw,
          List.of(),
          request -> {
            requests.add(request);
            return TraceFixtures.answer(request, i -> "paved");
          });
      assertEquals(
          points.size(), Polyline6Decoder.decode(requests.getFirst().encodedPolyline()).size());
    }
  }

  @Test
  void aRangeFoundOnAJitteryRawLine_landsWhereItIsOnTheStoredPoints() {
    // 2 km north; the raw line zigzags 10 m east over its first km, which makes it about 414 m
    // longer there: a proportional rescale would put metre 1500 at about 1586
    List<TrackPoint> points = TraceFixtures.line(21, 100);
    List<double[]> raw = TraceFixtures.rawLine(201, 10, 1000, 10);
    double rawLength = 0;
    for (int i = 1; i < raw.size(); i++) {
      double[] a = raw.get(i - 1);
      double[] b = raw.get(i);
      rawLength += GeoDistance.haversineMeters(a[1], a[0], b[1], b[0]);
    }
    assertTrue(rawLength > 2_400, "raw " + rawLength);
    TrackSurfaceDocument doc =
        computeRaw(
            points,
            raw,
            List.of(),
            request ->
                TraceFixtures.answerAlong(
                    request, m -> m > 1_500 && m < 1_800 ? "gravel" : "paved"));
    List<SurfaceRange> ranges = doc.surfaces();
    assertEquals(3, ranges.size(), ranges.toString());
    assertEquals("gravel", ranges.get(1).code());
    assertEquals(1_500, ranges.get(1).from(), 3);
    assertEquals(1_800, ranges.get(1).to(), 3);
    assertEquals(points.getLast().dist(), doc.distance(), 0);
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void straightPieces_stayOnTheStoredPoints_whenTheRawLineIsSent() {
    List<TrackPoint> points = TraceFixtures.line(21, 100);
    List<double[]> raw = TraceFixtures.rawLine(201, 10, 1000, 10);
    TrackSurfaceDocument doc =
        computeRaw(
            points,
            raw,
            List.of(new double[] {1_200, 1_600}),
            request ->
                TraceFixtures.answerAlong(
                    request, m -> m > 1_500 && m < 1_800 ? "gravel" : "paved"));
    List<SurfaceRange> ranges = doc.surfaces();
    assertEquals(4, ranges.size(), ranges.toString());
    assertEquals("off_network", ranges.get(1).code());
    assertEquals(1_200, ranges.get(1).from(), 0.1);
    assertEquals(1_600, ranges.get(1).to(), 0.1);
    assertEquals("gravel", ranges.get(2).code());
    assertEquals(1_800, ranges.get(2).to(), 3);
  }

  @Test
  void theSentCopyIsThinned_keepingTheLastPoint() {
    List<double[]> line = TraceFixtures.rawLine(13, 1.1, 0, 0);
    List<double[]> kept = TraceSurfaceComputer.decimate(line, 5);
    assertEquals(4, kept.size());
    assertEquals(line.get(0), kept.get(0));
    assertEquals(line.get(5), kept.get(1));
    assertEquals(line.get(10), kept.get(2));
    assertEquals(line.getLast(), kept.getLast());
  }

  @Test
  void aDenseRawLine_isThinned_soThatOneSliceHoldsIt() {
    // 100 km recorded every metre, plus a last point 2 m on: thinned at 5 m, 20 002 points would
    // take two requests; thinned to fit, one, as the stored points
    List<TrackPoint> points = TraceFixtures.line(1_001, 100);
    List<double[]> raw = new ArrayList<>(TraceFixtures.rawLine(100_001, 1, 0, 0));
    double[] end = raw.getLast();
    double[] last =
        new double[] {end[0], end[1] + Math.toDegrees(2 / GeoDistance.EARTH_RADIUS_METERS)};
    raw.add(last);
    List<TraceAttributesRequest> requests = new ArrayList<>();
    TrackSurfaceDocument doc =
        computeRaw(
            points,
            raw,
            List.of(),
            request -> {
              requests.add(request);
              return TraceFixtures.answer(request, i -> "paved");
            });
    assertEquals(1, requests.size());
    List<double[]> sent = Polyline6Decoder.decode(requests.getFirst().encodedPolyline());
    assertTrue(sent.size() <= TraceSurfaceComputer.MAX_POINTS, "sent " + sent.size());
    assertTrue(sent.size() > 10_000, "sent " + sent.size());
    assertEquals(last[0], sent.getLast()[0], 1e-6);
    assertEquals(last[1], sent.getLast()[1], 1e-6);
    assertEquals(1, doc.surfaces().size());
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void aLong1HzRawLine_takesAsManyRequestsAsItsStoredPoints() {
    // 300 km at 7 m between points (1 Hz at 25 km/h): bounded by point count, a slice would cover
    // about 100 km, three requests; bounded by distance, two
    List<TrackPoint> points = TraceFixtures.line(3_001, 100);
    List<double[]> raw = TraceFixtures.rawLine(42_858, 7, 0, 0);
    int[] stored = {0};
    compute(
        points,
        List.of(),
        request -> {
          stored[0]++;
          return TraceFixtures.answer(request, i -> "paved");
        });
    List<TraceAttributesRequest> requests = new ArrayList<>();
    TrackSurfaceDocument doc =
        computeRaw(
            points,
            raw,
            List.of(),
            request -> {
              requests.add(request);
              return TraceFixtures.answer(request, i -> "paved");
            });
    assertEquals(2, stored[0]);
    assertEquals(stored[0], requests.size());
    for (TraceAttributesRequest request : requests) {
      assertTrue(
          Polyline6Decoder.decode(request.encodedPolyline()).size()
              <= TraceSurfaceComputer.MAX_POINTS);
    }
    assertEquals(1, doc.surfaces().size());
    assertContiguous(doc, points.getLast().dist());
  }

  @Test
  void aShortRawLine_isThinnedAtTheMinimumSpacing() {
    assertEquals(
        TraceSurfaceComputer.MIN_SPACING_M,
        TraceSurfaceComputer.spacingFor(TraceFixtures.rawLine(10_001, 1, 0, 0)),
        0);
  }

  @Test
  void theCostingFollowsTheProfile() {
    assertEquals("pedestrian", TraceSurfaceComputer.costingOf(RouterProfile.RUN_HIKE));
    assertEquals("auto", TraceSurfaceComputer.costingOf(RouterProfile.MOTORCYCLE));
    for (RouterProfile p :
        List.of(
            RouterProfile.BIKE, RouterProfile.FASTBIKE, RouterProfile.GRAVEL, RouterProfile.MTB)) {
      assertEquals("bicycle", TraceSurfaceComputer.costingOf(p));
    }
    assertEquals("bicycle", TraceSurfaceComputer.costingOf(null));
  }
}
