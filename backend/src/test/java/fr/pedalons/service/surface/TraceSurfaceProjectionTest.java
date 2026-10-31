package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.Edge;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.MatchedPoint;
import fr.pedalons.service.surface.TraceSurfaceProjection.Range;
import java.util.ArrayList;
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

  // ------------------------------------------------------------------ TrackAxisMapping (API-147)

  /** An out-and-back: {@code n} vertices north every {@code step} metres, then back south. */
  private static double[][] outAndBack(int n, double step, double eastM) {
    double dLat = Math.toDegrees(step / fr.pedalons.common.GeoDistance.EARTH_RADIUS_METERS);
    double dLng =
        Math.toDegrees(
            eastM
                / (fr.pedalons.common.GeoDistance.EARTH_RADIUS_METERS
                    * Math.cos(Math.toRadians(48))));
    int total = 2 * n - 1;
    double[][] out = new double[3][total];
    for (int i = 0; i < total; i++) {
      int k = i < n ? i : 2 * (n - 1) - i;
      out[0][i] = 48 + k * dLat;
      out[1][i] = 2 + (i < n ? 0 : dLng);
      if (i > 0) {
        out[2][i] =
            out[2][i - 1]
                + fr.pedalons.common.GeoDistance.haversineMeters(
                    out[0][i - 1], out[1][i - 1], out[0][i], out[1][i]);
      }
    }
    return out;
  }

  @Test
  void theMappingOfAnOutAndBack_followsTheLegItIsOn() {
    // Stored: 1 km north and back every 100 m; sent: the same every 10 m, 3 m east on the way back
    double[][] track = outAndBack(11, 100, 0);
    double[][] sent = outAndBack(101, 10, 3);
    double sentLength = sent[2][sent[2].length - 1];
    double back = sent[2][170]; // 300 m north, on the way back
    double[] mapped =
        TrackAxisMapping.map(
            sent[0],
            sent[1],
            sent[2],
            track[0],
            track[1],
            track[2],
            new double[] {0, back, sentLength});
    assertEquals(0, mapped[0], 0);
    assertEquals(1_700, mapped[1], 2);
    assertEquals(track[2][track[2].length - 1], mapped[2], 0);

    double out = sent[2][30]; // 300 m north, on the way out: the same spot, the other leg
    mapped =
        TrackAxisMapping.map(
            sent[0], sent[1], sent[2], track[0], track[1], track[2], new double[] {out, back});
    assertEquals(300, mapped[0], 2);
    assertEquals(1_700, mapped[1], 2);
  }

  /**
   * A line through the given {@code [east, north]} waypoints in metres from (lat 48, lng 2), a
   * vertex every {@code step} metres along each leg; between {@code zigFrom} and {@code zigTo}
   * metres along it every other vertex is {@code lateral} metres east, a GPS jitter that makes the
   * line longer there only. As {@code [lat[], lng[], dist[]]}.
   */
  private static double[][] path(
      double step, double zigFrom, double zigTo, double lateral, double[]... waypoints) {
    double r = fr.pedalons.common.GeoDistance.EARTH_RADIUS_METERS;
    double cos = Math.cos(Math.toRadians(48));
    List<double[]> en = new ArrayList<>();
    en.add(waypoints[0]);
    for (int w = 1; w < waypoints.length; w++) {
      double[] a = waypoints[w - 1];
      double[] b = waypoints[w];
      double leg = Math.hypot(b[0] - a[0], b[1] - a[1]);
      int steps = Math.max(1, (int) Math.round(leg / step));
      for (int i = 1; i <= steps; i++) {
        double f = (double) i / steps;
        en.add(new double[] {a[0] + f * (b[0] - a[0]), a[1] + f * (b[1] - a[1])});
      }
    }
    double[][] out = new double[3][en.size()];
    for (int i = 0; i < en.size(); i++) {
      boolean zig = i % 2 == 1 && i * step >= zigFrom && i * step < zigTo;
      double east = en.get(i)[0] + (zig ? lateral : 0);
      out[0][i] = 48 + Math.toDegrees(en.get(i)[1] / r);
      out[1][i] = 2 + Math.toDegrees(east / (r * cos));
      if (i > 0) {
        out[2][i] =
            out[2][i - 1]
                + fr.pedalons.common.GeoDistance.haversineMeters(
                    out[0][i - 1], out[1][i - 1], out[0][i], out[1][i]);
      }
    }
    return out;
  }

  /** The distance along {@code line} of its first vertex within a metre of {@code [east, north]}, from {@code after}. */
  private static double distAt(double[][] line, double east, double north, double after) {
    double r = fr.pedalons.common.GeoDistance.EARTH_RADIUS_METERS;
    double lat = 48 + Math.toDegrees(north / r);
    double lng = 2 + Math.toDegrees(east / (r * Math.cos(Math.toRadians(48))));
    for (int i = 0; i < line[2].length; i++) {
      if (line[2][i] >= after
          && fr.pedalons.common.GeoDistance.haversineMeters(line[0][i], line[1][i], lat, lng) < 1) {
        return line[2][i];
      }
    }
    throw new AssertionError("no vertex at " + east + ", " + north);
  }

  @Test
  void aSpurAfterAJitteryStretch_mapsOnThePassItIsOn() {
    // 20 km north, a 100 m spur east and back, 30 km north again. The raw line zigzags 10 m over
    // km 15-16, about 414 m more there only: rescaled by the length ratio of the whole line, the
    // base of the spur, passed first, is expected about 250 m on, nearer its second pass
    double[][] corners = {{0, 0}, {0, 20_000}, {100, 20_000}, {0, 20_000}, {0, 50_000}};
    double[][] track = path(100, 0, 0, 0, corners);
    double[][] sent = path(10, 15_000, 16_000, 10, corners);
    double first = distAt(sent, 0, 20_000, 0);
    double tip = distAt(sent, 100, 20_000, first);
    double second = distAt(sent, 0, 20_000, tip);
    assertTrue(first > 20_400, "first " + first);
    double[] mapped =
        TrackAxisMapping.map(
            sent[0],
            sent[1],
            sent[2],
            track[0],
            track[1],
            track[2],
            new double[] {first, tip, second});
    assertEquals(20_000, mapped[0], 3);
    assertEquals(20_100, mapped[1], 3);
    assertEquals(20_200, mapped[2], 3);
  }

  @Test
  void aBoundaryFarFromThePreviousOne_staysOnItsLeg() {
    // 25 km north and 5 km back, the way back 5 m east; the raw line zigzags only after the
    // boundary, which is 100 m after the U-turn, 25 km from the start: a length ratio of the
    // whole line would expect it about 340 m early, on the way out across the road
    double[][] track =
        path(
            100,
            0,
            0,
            0,
            new double[] {0, 0},
            new double[] {0, 25_000},
            new double[] {5, 25_000},
            new double[] {5, 20_000});
    double[][] sent =
        path(
            10,
            28_000,
            29_000,
            10,
            new double[] {0, 0},
            new double[] {0, 25_000},
            new double[] {5, 25_000},
            new double[] {5, 20_000});
    double turn = distAt(sent, 5, 25_000, 0);
    double back = distAt(sent, 5, 24_900, turn);
    double[] mapped =
        TrackAxisMapping.map(
            sent[0], sent[1], sent[2], track[0], track[1], track[2], new double[] {back});
    assertEquals(25_105, mapped[0], 3);
  }
}
