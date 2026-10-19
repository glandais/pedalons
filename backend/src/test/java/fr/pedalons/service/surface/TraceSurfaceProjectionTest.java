package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.Edge;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.MatchedPoint;
import fr.pedalons.service.surface.TraceSurfaceProjection.Range;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The cases of the prototype of docs/research/2026-10-19-stadia-surfaces.md, on a straight line. */
class TraceSurfaceProjectionTest {

  /** A shape of three vertices, 100 m apart: edge 0 is metres 0-100, edge 1 is 100-200. */
  private static final List<TrackPoint> LINE = TraceFixtures.line(3, 100);

  private static String shape() {
    double[] lat = LINE.stream().mapToDouble(TrackPoint::lat).toArray();
    double[] lon = LINE.stream().mapToDouble(TrackPoint::lng).toArray();
    return Polyline6Encoder.encode(lat, lon, 0, 2);
  }

  private static final List<Edge> EDGES =
      List.of(new Edge("paved", "road", "none", 0, 1), new Edge("gravel", "track", null, 1, 2));

  private static MatchedPoint at(int edge, double along) {
    return new MatchedPoint("matched", edge, along);
  }

  private static List<Range<String>> surfaces(double[] d, List<MatchedPoint> matched) {
    return TraceSurfaceProjection.project(
        d, new TraceAttributesResponse(shape(), EDGES, matched, null), Edge::surface);
  }

  private static void assertRange(Range<String> r, double from, double to, String value) {
    assertEquals(from, r.from(), 0.5);
    assertEquals(to, r.to(), 0.5);
    assertEquals(value, r.value());
  }

  @Test
  void aSingleEdgeIsOneRange() {
    var out = surfaces(new double[] {0, 50, 100}, List.of(at(0, 0), at(0, 0.5), at(0, 1)));
    assertEquals(1, out.size());
    assertRange(out.getFirst(), 0, 100, "paved");
  }

  @Test
  void edgesAreCutWhereTheSnappedLineCrossesThem() {
    var out = surfaces(new double[] {0, 200}, List.of(at(0, 0), at(1, 1)));
    assertEquals(2, out.size());
    assertRange(out.get(0), 0, 100, "paved");
    assertRange(out.get(1), 100, 200, "gravel");
  }

  @Test
  void theCutIsInterpolatedOnTheDistanceBetweenThePoints() {
    // The two points are 100 m apart on the input and span 200 m of snapped line
    var out = surfaces(new double[] {1000, 1100}, List.of(at(0, 0), at(1, 1)));
    assertEquals(2, out.size());
    assertRange(out.get(0), 1000, 1050, "paved");
    assertRange(out.get(1), 1050, 1100, "gravel");
  }

  @Test
  void aDetourIsCutHalfway() {
    // 200 m of snapped line for 50 m of input: more than 1.2 x 50 + 30
    var out = surfaces(new double[] {0, 50}, List.of(at(0, 0), at(1, 1)));
    assertEquals(2, out.size());
    assertRange(out.get(0), 0, 25, "paved");
    assertRange(out.get(1), 25, 50, "gravel");
  }

  @Test
  void aWayBackIsCutHalfway() {
    var out = surfaces(new double[] {0, 100}, List.of(at(1, 1), at(0, 0)));
    assertEquals(2, out.size());
    assertRange(out.get(0), 0, 50, "gravel");
    assertRange(out.get(1), 50, 100, "paved");
  }

  @Test
  void twoPointsSnappedOntoTheSameSpotOfTwoEdgesAreCutHalfway() {
    // The end of edge 0 is the start of edge 1: no snapped line between the points, yet 40 m of
    // track, which must not be left to nothing
    var out = surfaces(new double[] {0, 40}, List.of(at(0, 1), at(1, 0)));
    assertEquals(2, out.size());
    assertRange(out.get(0), 0, 20, "paved");
    assertRange(out.get(1), 20, 40, "gravel");
  }

  @Test
  void anEdgeCrossedWholeBetweenTwoPointsHasItsShare() {
    // Three edges of 100 m, the points at 50 m on the first and 50 m on the third: 200 m of
    // snapped line for 200 m of track, the middle edge crossed whole
    List<TrackPoint> line = TraceFixtures.line(4, 100);
    double[] lat = line.stream().mapToDouble(TrackPoint::lat).toArray();
    double[] lon = line.stream().mapToDouble(TrackPoint::lng).toArray();
    List<Edge> edges =
        List.of(
            new Edge("paved", "road", "none", 0, 1),
            new Edge("dirt", "track", null, 1, 2),
            new Edge("gravel", "track", null, 2, 3));
    var out =
        TraceSurfaceProjection.project(
            new double[] {0, 200},
            new TraceAttributesResponse(
                Polyline6Encoder.encode(lat, lon, 0, 3),
                edges,
                List.of(at(0, 0.5), at(2, 0.5)),
                null),
            Edge::surface);
    assertEquals(3, out.size());
    assertRange(out.get(0), 0, 50, "paved");
    assertRange(out.get(1), 50, 150, "dirt");
    assertRange(out.get(2), 150, 200, "gravel");
  }

  @Test
  void anUnmatchedPointMakesTheSpansAroundItUnknown() {
    var out =
        surfaces(
            new double[] {0, 50, 100},
            List.of(at(0, 0), new MatchedPoint("unmatched", null, null), at(0, 1)));
    assertEquals(1, out.size());
    assertRange(out.getFirst(), 0, 100, null);
  }

  @Test
  void aMissingEdgeIndexIsUnknownToo() {
    var out =
        surfaces(
            new double[] {0, 50, 100},
            List.of(at(0, 0), at(0, 0.5), new MatchedPoint("matched", null, null)));
    assertEquals(2, out.size());
    assertRange(out.get(0), 0, 50, "paved");
    assertRange(out.get(1), 50, 100, null);
  }

  @Test
  void anEdgeIndexOutOfTheEdgesIsUnknown() {
    var out = surfaces(new double[] {0, 100}, List.of(at(0, 0), at(7, 0)));
    assertEquals(1, out.size());
    assertNull(out.getFirst().value());
  }

  @Test
  void adjacentRangesOfTheSameValueAreMerged() {
    var out =
        surfaces(
            new double[] {0, 30, 60, 100}, List.of(at(0, 0), at(0, 0.3), at(0, 0.6), at(0, 1)));
    assertEquals(1, out.size());
  }

  @Test
  void aCountOfMatchedPointsThatIsNotTheCountOfInputPointsMakesTheSliceUnknown() {
    var out = surfaces(new double[] {0, 50, 100}, List.of(at(0, 0), at(0, 1)));
    assertEquals(1, out.size());
    assertRange(out.getFirst(), 0, 100, null);
  }

  @Test
  void aWayIsThePairOfUseAndCycleLane() {
    var out =
        TraceSurfaceProjection.project(
            new double[] {0, 200},
            new TraceAttributesResponse(shape(), EDGES, List.of(at(0, 0), at(1, 1)), null),
            e -> e.use() + "/" + e.cycleLane());
    assertEquals(2, out.size());
    assertEquals("road/none", out.get(0).value());
    assertEquals("track/null", out.get(1).value());
  }
}
