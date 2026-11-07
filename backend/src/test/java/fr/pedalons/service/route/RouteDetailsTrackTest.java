package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.OutputPoint;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Quality;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.TerrainRange;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Warning;
import fr.pedalons.service.route.planner.PolylineCodec;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import io.github.glandais.engine.path.PathSimplifier;
import io.github.glandais.engine.path.PathSimplifierJvm;
import java.util.ArrayList;
import java.util.List;
import java.util.function.DoubleUnaryOperator;
import org.junit.jupiter.api.Test;

/**
 * The conversions between a vcyclist path and an osm-route-details call (docs/LEDGER_*.md API-150),
 * on hand-built answers: no Quarkus, no service.
 */
class RouteDetailsTrackTest {

  static final double M_PER_DEG = GeoDistance.EARTH_RADIUS_METERS * Math.PI / 180;

  /** {@code n} positions due north from Nantes, {@code stepM} apart: {lat[], lon[]}. */
  static double[][] meridian(int n, double stepM) {
    double[] lat = new double[n];
    double[] lon = new double[n];
    for (int i = 0; i < n; i++) {
      lat[i] = 47.2 + i * stepM / M_PER_DEG;
      lon[i] = -1.55;
    }
    return new double[][] {lat, lon};
  }

  static OutputPoint input(
      double d, int index, Double ele, Double smoothed, double gain, double loss) {
    return new OutputPoint(d, index, "input", null, null, null, ele, smoothed, null, gain, loss);
  }

  static OutputPoint inserted(
      double d, int index, double lat, double lon, Double ele, double gain, double loss) {
    return new OutputPoint(d, index, "inserted", null, lat, lon, ele, ele, null, gain, loss);
  }

  static RouteDetailsResponse answer(List<OutputPoint> points, Quality quality) {
    return new RouteDetailsResponse(null, "complete", points, null, null, quality);
  }

  /**
   * One answer point per input point, {@code stepM} apart, elevation {@code terrain(d)} on both
   * {@code ele} and {@code ele_smoothed}, cumulatives the running sums of its deltas.
   */
  static List<OutputPoint> profile(int n, double stepM, DoubleUnaryOperator terrain) {
    List<OutputPoint> points = new ArrayList<>(n);
    double gain = 0;
    double loss = 0;
    double previous = terrain.applyAsDouble(0);
    for (int i = 0; i < n; i++) {
      double d = i * stepM;
      double e = terrain.applyAsDouble(d);
      gain += Math.max(0, e - previous);
      loss += Math.max(0, previous - e);
      previous = e;
      points.add(input(d, i, e, e, gain, loss));
    }
    return points;
  }

  @Test
  void toDense_insertedPointsTakeTheServicePosition_inputPointsTheClientOne() {
    double[][] ll = meridian(3, 100);
    double insertedLat = (ll[0][1] + ll[0][2]) / 2;
    List<OutputPoint> points =
        List.of(
            input(0, 0, 10.0, 10.0, 0, 0),
            input(100, 1, 12.0, 12.0, 2, 0),
            inserted(150, 1, insertedLat, -1.5501, 15.0, 5, 0),
            input(200, 2, 11.0, 11.0, 5, 4));

    RouteDetailsTrack.Dense dense = RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null));

    Path path = dense.path();
    assertEquals(4, path.getSize());
    assertEquals(ll[0][1], path.latitudeDeg(1), 1e-9);
    assertEquals(ll[1][1], path.longitudeDeg(1), 1e-9);
    assertEquals(insertedLat, path.latitudeDeg(2), 1e-9);
    assertEquals(-1.5501, path.longitudeDeg(2), 1e-9);
    assertEquals(ll[0][2], path.latitudeDeg(3), 1e-9);
    assertEquals(15.0, path.elevation(2), 1e-9);
  }

  /** A fresh path's slots read 0, and the GPX writer takes that for a heart rate of 0. */
  @Test
  void toDense_leavesTheSensorsAbsent() {
    double[][] ll = meridian(2, 100);
    List<OutputPoint> points =
        List.of(input(0, 0, 10.0, 10.0, 0, 0), input(100, 1, 11.0, 11.0, 1, 0));

    Path path = RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null)).path();

    for (int k = 0; k < path.getSize(); k++) {
      assertTrue(Double.isNaN(path.heartRate(k)));
      assertTrue(Double.isNaN(path.cadence(k)));
      assertTrue(Double.isNaN(path.temperature(k)));
      assertTrue(Double.isNaN(path.pInputPower(k)));
    }
  }

  @Test
  void toDense_aThinnedIndexIsAbsent_theOthersKeepTheirPosition() {
    double[][] ll = meridian(4, 100);
    // Index 2 thinned by the gateway: no point of its own
    List<OutputPoint> points =
        List.of(
            input(0, 0, 10.0, 10.0, 0, 0),
            input(100, 1, 10.0, 10.0, 0, 0),
            input(300, 3, 10.0, 10.0, 0, 0));

    Path path = RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null)).path();

    assertEquals(3, path.getSize());
    assertEquals(ll[0][3], path.latitudeDeg(2), 1e-9);
  }

  @Test
  void toDense_anIndexOutOfTheSentArrays_orAnInsertedPointWithoutPosition_throws() {
    double[][] ll = meridian(2, 100);
    List<OutputPoint> outOfRange =
        List.of(input(0, 0, 10.0, 10.0, 0, 0), input(100, 2, 10.0, 10.0, 0, 0));
    assertThrows(
        IllegalStateException.class,
        () -> RouteDetailsTrack.toDense(ll[0], ll[1], answer(outOfRange, null)));

    List<OutputPoint> noPosition =
        List.of(
            input(0, 0, 10.0, 10.0, 0, 0),
            new OutputPoint(50, 0, "inserted", null, null, null, 10.0, 10.0, null, 0, 0),
            input(100, 1, 10.0, 10.0, 0, 0));
    assertThrows(
        IllegalStateException.class,
        () -> RouteDetailsTrack.toDense(ll[0], ll[1], answer(noPosition, null)));

    assertThrows(
        IllegalStateException.class,
        () ->
            RouteDetailsTrack.toDense(
                ll[0], ll[1], answer(List.of(input(0, 0, 1.0, 1.0, 0, 0)), null)));
  }

  @Test
  void toDense_usesEleSmoothed_fallsBackOnEle_andKeepsEleAsSourceElevation() {
    double[][] ll = meridian(3, 100);
    List<OutputPoint> points =
        List.of(
            input(0, 0, 10.0, 11.0, 0, 0),
            input(100, 1, 20.0, null, 0, 0),
            input(200, 2, 30.0, 29.0, 0, 0));

    Path path = RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null)).path();

    assertEquals(11.0, path.elevation(0), 1e-9);
    assertEquals(20.0, path.elevation(1), 1e-9);
    assertEquals(29.0, path.elevation(2), 1e-9);
    assertEquals(10.0, path.sourceElevation(0), 1e-9);
    assertEquals(30.0, path.sourceElevation(2), 1e-9);
  }

  @Test
  void toDense_interpolatesTheGapsWithoutElevation_andHoldsTheEnds() {
    double[][] ll = meridian(6, 100);
    List<OutputPoint> points =
        List.of(
            input(0, 0, null, null, 0, 0),
            input(100, 1, 10.0, 10.0, 0, 0),
            input(200, 2, null, null, 0, 0),
            input(300, 3, null, null, 0, 0),
            input(400, 4, 40.0, 40.0, 30, 0),
            input(500, 5, null, null, 30, 0));

    RouteDetailsTrack.Dense dense = RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null));

    Path path = dense.path();
    assertEquals(10.0, path.elevation(0), 1e-9);
    assertEquals(20.0, path.elevation(2), 1e-9);
    assertEquals(30.0, path.elevation(3), 1e-9);
    assertEquals(40.0, path.elevation(5), 1e-9);
    assertEquals(20.0, path.sourceElevation(2), 1e-9);
    for (int k = 0; k < path.getSize(); k++) {
      assertFalse(Double.isNaN(path.elevation(k)));
    }
    // 0-100, 100-200, 200-300, 300-400, 400-500 all touch a missing point
    assertEquals(500.0, dense.interpolatedM(), 1e-9);
  }

  @Test
  void toDense_withoutAnyElevation_throws() {
    double[][] ll = meridian(2, 100);
    List<OutputPoint> points =
        List.of(input(0, 0, null, null, 0, 0), input(100, 1, null, null, 0, 0));

    assertThrows(
        IllegalStateException.class,
        () -> RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null)));
  }

  @Test
  void toDense_climbAndReportedFigures_comeFromTheCumulatives() {
    double[][] ll = meridian(21, 100);
    DoubleUnaryOperator upAndDown = d -> d < 1000 ? 0.05 * d : 50 - 0.03 * (d - 1000);
    List<OutputPoint> points = profile(21, 100, upAndDown);

    RouteDetailsTrack.Dense dense = RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null));

    double[] climb = dense.climb();
    assertEquals(0.0, climb[0]);
    assertEquals(50.0, climb[climb.length - 1], 1e-9);
    assertEquals(50.0, dense.path().getReportedElevationGain(), 1e-9);
    assertEquals(-30.0, dense.path().getReportedElevationLoss(), 1e-9);
    for (int k = 1; k < climb.length; k++) {
      assertTrue(climb[k] >= climb[k - 1]);
    }
  }

  @Test
  void toDense_onASlicedAnswer_climbStartsAtZeroWhateverTheFirstCumulative() {
    double[][] ll = meridian(3, 100);
    List<OutputPoint> points =
        List.of(
            input(0, 0, 10.0, 10.0, 5, 2),
            input(100, 1, 20.0, 20.0, 15, 2),
            input(200, 2, 15.0, 15.0, 15, 7));

    RouteDetailsTrack.Dense dense = RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null));

    assertArrayEquals(new double[] {0, 10, 10}, dense.climb(), 1e-9);
    assertEquals(-5.0, dense.path().getReportedElevationLoss(), 1e-9);
  }

  /**
   * docs/LEDGER_*.md API-150: across a flat seam, the stitching's two sums can differ by an ulp the
   * wrong way. On a value ending in 5 cm the planner's tenths then round apart, and a drop of 0.1 m
   * makes the saved state invalid.
   */
  @Test
  void toDense_aFlatSeamOffByAnUlp_neverLowersTheClimb() {
    double[][] ll = meridian(4, 100);
    List<OutputPoint> points =
        List.of(
            input(0, 0, 10.0, 10.0, 0, 0),
            input(100, 1, 10.0, 10.0, 1234.2500000000002, 0),
            input(200, 2, 10.0, 10.0, 1234.2499999999998, 0),
            input(300, 3, 10.0, 10.0, 1240, 0));

    double[] climb = RouteDetailsTrack.toDense(ll[0], ll[1], answer(points, null)).climb();

    double[] tenths = PolylineCodec.decode1(PolylineCodec.encode1(climb), climb.length);
    for (int k = 1; k < climb.length; k++) {
      assertTrue(climb[k] >= climb[k - 1], "climb at " + k);
      assertTrue(tenths[k] >= tenths[k - 1], "encoded climb at " + k);
    }
    assertEquals(1240.0, climb[3]);
  }

  @Test
  void probe_twoDistinctPoints_towardsTheEquator() {
    Path north = PathJvm.fromCoordinates(List.of(new LatLonElevation(47.2, -1.55, 0)));
    RouteDetailsTrack.Sent sent = RouteDetailsTrack.probe(north, 10);

    assertEquals(2, sent.size());
    assertEquals(47.2, sent.lat()[0], 1e-9);
    assertEquals(-1.55, sent.lon()[1], 1e-9);
    assertTrue(sent.lat()[1] < 47.2);
    assertEquals(
        10.0,
        GeoDistance.haversineMeters(sent.lat()[0], sent.lon()[0], sent.lat()[1], sent.lon()[1]),
        1e-6);

    Path south = PathJvm.fromCoordinates(List.of(new LatLonElevation(-90, 0, 0)));
    assertTrue(RouteDetailsTrack.probe(south, 10).lat()[1] > -90);
  }

  @Test
  void flat_keepsThePositions_atTheProbesFirstElevation() {
    Path source =
        PathJvm.fromCoordinates(
            List.of(new LatLonElevation(47.2, -1.55, 0), new LatLonElevation(47.2, -1.55, 0)));
    double[][] ll = meridian(2, 10);
    Path probe =
        RouteDetailsTrack.toDense(
                ll[0],
                ll[1],
                answer(
                    List.of(input(0, 0, 310.0, 312.0, 0, 0), input(10, 1, 90.0, 90.0, 0, 0)), null))
            .path();

    Path flat = RouteDetailsTrack.flat(source, probe);

    assertEquals(2, flat.getSize());
    for (int k = 0; k < 2; k++) {
      assertEquals(47.2, flat.latitudeDeg(k), 1e-9);
      assertEquals(312.0, flat.elevation(k), 1e-9);
      assertEquals(310.0, flat.sourceElevation(k), 1e-9);
    }
  }

  @Test
  void climbAfterSimplification_matchesTheKeptPoints_andEndsOnTheReportedGain() {
    double[][] ll = meridian(41, 50);
    DoubleUnaryOperator terrain = d -> d < 750 ? 0.1 * d : 75 - 0.02 * (d - 750);
    RouteDetailsTrack.Dense dense =
        RouteDetailsTrack.toDense(ll[0], ll[1], answer(profile(41, 50, terrain), null));

    PathSimplifier.Simplified simplified =
        PathSimplifierJvm.simplifyWithIndices(dense.path(), 3.0, 3.0);
    int[] indices = simplified.getIndices();
    double[] climb = RouteDetailsTrack.pick(dense.climb(), indices);

    assertTrue(indices.length < dense.path().getSize(), "Douglas-Peucker dropped points");
    assertEquals(indices.length, simplified.getPath().getSize());
    for (int k = 0; k < indices.length; k++) {
      assertEquals(dense.climb()[indices[k]], climb[k]);
    }
    assertEquals(0.0, climb[0]);
    assertEquals(simplified.getPath().getReportedElevationGain(), climb[climb.length - 1], 1e-9);
    assertEquals(75.0, simplified.getPath().getReportedElevationGain(), 1e-9);
    assertEquals(-25.0, simplified.getPath().getReportedElevationLoss(), 1e-9);
  }

  @Test
  void fallbackKm_sumsTheTerrainFlagsAndElevationUnavailable_notElevationMissing() {
    Quality quality =
        new Quality(
            List.of(
                new TerrainRange(0, 1000, "ign_lidar_hd", true, false),
                new TerrainRange(1000, 1500, "mapterhorn", true, true),
                new TerrainRange(1500, 1800, "mapterhorn", true, true)),
            List.of(
                new Warning("elevation_unavailable", "down", 2000.0, 2200.0),
                new Warning("elevation_missing", "out of coverage", 2200.0, 2900.0),
                new Warning("unmatched_range", null, 0.0, 100.0)),
            null);
    List<OutputPoint> points = List.of(input(0, 0, 1.0, 1.0, 0, 0), input(3000, 1, 1.0, 1.0, 0, 0));

    assertEquals(1.0, RouteDetailsTrack.fallbackKm(answer(points, quality)), 1e-9);
  }

  @Test
  void fallbackKm_anElevationUnavailableWithoutRange_countsTheWholeLength() {
    Quality quality =
        new Quality(null, List.of(new Warning("elevation_unavailable", null, null, null)), null);
    List<OutputPoint> points = List.of(input(0, 0, 1.0, 1.0, 0, 0), input(2500, 1, 1.0, 1.0, 0, 0));

    assertEquals(2.5, RouteDetailsTrack.fallbackKm(answer(points, quality)), 1e-9);
    assertEquals(0.0, RouteDetailsTrack.fallbackKm(answer(points, null)));
  }

  @Test
  void densify_neverDropsAPoint_andCapsEveryGap() {
    // 2015 m rather than a multiple of 50: ceil() would then hang on the last bit of the haversine
    double[] lat = {47.2, 47.2 + 120 / M_PER_DEG, 47.2 + 130 / M_PER_DEG, 47.2 + 2145 / M_PER_DEG};
    double[] lon = {-1.55, -1.55, -1.55, -1.55};
    Path source =
        PathJvm.fromCoordinates(
            List.of(
                new LatLonElevation(lat[0], lon[0], 0),
                new LatLonElevation(lat[1], lon[1], 0),
                new LatLonElevation(lat[2], lon[2], 0),
                new LatLonElevation(lat[3], lon[3], 0)));

    RouteDetailsTrack.Sent sent = RouteDetailsTrack.densify(source, 50);

    // 120 m -> 3 gaps, 10 m -> 1, 2015 m -> 41: 45 gaps, 46 points
    assertEquals(46, sent.size());
    int found = 0;
    for (int i = 0; i < sent.size() && found < lat.length; i++) {
      if (Math.abs(sent.lat()[i] - lat[found]) < 1e-9) {
        found++;
      }
    }
    assertEquals(lat.length, found, "every source point is sent, in order");
    assertEquals(lat[3], sent.lat()[sent.size() - 1], 1e-9);
    for (int i = 1; i < sent.size(); i++) {
      double gap =
          GeoDistance.haversineMeters(
              sent.lat()[i - 1], sent.lon()[i - 1], sent.lat()[i], sent.lon()[i]);
      assertTrue(gap <= 50 + 1e-6, "gap " + gap + " at " + i);
    }
  }

  @Test
  void densify_leavesAGapAcrossTheAntimeridian() {
    RouteDetailsTrack.Sent sent =
        RouteDetailsTrack.densify(new double[] {0, 0}, new double[] {179.9, -179.9}, 50);

    assertEquals(2, sent.size());
  }
}
