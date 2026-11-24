package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.Changed;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.EditedRoute;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GenerateRequest;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GeoPoint;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.Route;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Each check of {@link GeneratedRouteSanity} refuses a forged route and keeps a good one. */
class GeneratedRouteSanityTest {

  private static final double LAT = 47.2;
  private static final double LON = -1.5;
  private static final double M_PER_DEG = Math.toRadians(1) * GeoDistance.EARTH_RADIUS_METERS;

  private static GenerateRequest loopOf(double meters) {
    return new GenerateRequest(new GeoPoint(LAT, LON), null, null, meters, "road", 0.25, 0);
  }

  /** Out and back to the north in steps of 1 km: a loop of {@code meters}. */
  private static List<double[]> loopPoints(double meters, double stepM) {
    List<double[]> out = new ArrayList<>();
    int steps = (int) Math.ceil(meters / 2 / stepM);
    for (int i = 0; i <= steps; i++) {
      out.add(new double[] {LAT + (meters / 2) * i / steps / M_PER_DEG, LON});
    }
    List<double[]> all = new ArrayList<>(out);
    for (int i = out.size() - 2; i >= 0; i--) {
      all.add(out.get(i));
    }
    return all;
  }

  private static Route route(List<double[]> points, double distanceM, double teamShare) {
    double[] lat = new double[points.size()];
    double[] lon = new double[points.size()];
    for (int i = 0; i < lat.length; i++) {
      lat[i] = points.get(i)[0];
      lon[i] = points.get(i)[1];
    }
    return new Route(
        Polyline6Encoder.encode(lat, lon, 0, lat.length - 1),
        distanceM,
        distanceM * teamShare,
        0,
        teamShare,
        0,
        0,
        0,
        0.1,
        null,
        null,
        null);
  }

  private static double length(List<double[]> points) {
    double l = 0;
    for (int i = 1; i < points.size(); i++) {
      l +=
          GeoDistance.haversineMeters(
              points.get(i - 1)[0], points.get(i - 1)[1], points.get(i)[0], points.get(i)[1]);
    }
    return l;
  }

  private static Route good(double meters) {
    List<double[]> points = loopPoints(meters, 1000);
    return route(points, length(points), 0.8);
  }

  @Test
  void aGoodLoopIsKeptAndFramed() {
    GeneratedRouteSanity.Verdict v = GeneratedRouteSanity.check(loopOf(20_000), good(20_000));
    assertTrue(v.sane(), String.valueOf(v.failed()));
    assertNotNull(v.bounds());
    assertEquals(LON, v.bounds().minLon(), 1e-5);
    assertEquals(LAT, v.bounds().minLat(), 1e-5);
    assertEquals(LAT + 10_000 / M_PER_DEG, v.bounds().maxLat(), 1e-5);
  }

  @Test
  void aTripEndingAtTheEndIsKept() {
    List<double[]> points = new ArrayList<>();
    for (int i = 0; i <= 20; i++) {
      points.add(new double[] {LAT + i * 1000 / M_PER_DEG, LON});
    }
    GenerateRequest request =
        new GenerateRequest(
            new GeoPoint(LAT, LON),
            new GeoPoint(LAT + 20_000 / M_PER_DEG, LON),
            null,
            20_000,
            "road",
            0.25,
            0);
    assertTrue(GeneratedRouteSanity.check(request, route(points, length(points), 0.5)).sane());
  }

  @Test
  void anUndecodablePolylineIsRefused() {
    Route r = good(20_000);
    for (String bad : new String[] {"", "?", r.polyline().substring(0, 2)}) {
      Route forged = new Route(bad, r.distanceM(), 0, 0, 0.8, 0, 0, 0, 0.1, null, null, null);
      assertEquals(
          GeneratedRouteSanity.Check.DECODE,
          GeneratedRouteSanity.check(loopOf(20_000), forged).failed(),
          "polyline: " + bad);
    }
  }

  @Test
  void aLengthOffByMoreThanTenPercentIsRefused() {
    // 25 km ridden for 20 km asked
    GeneratedRouteSanity.Verdict v = GeneratedRouteSanity.check(loopOf(20_000), good(25_000));
    assertEquals(GeneratedRouteSanity.Check.LENGTH, v.failed());
    // 11 % short
    assertEquals(
        GeneratedRouteSanity.Check.LENGTH,
        GeneratedRouteSanity.check(loopOf(22_500), good(20_000)).failed());
    // 9 % off passes
    assertTrue(GeneratedRouteSanity.check(loopOf(22_000), good(20_000)).sane());
  }

  @Test
  void aDistanceTheEngineClaimsWrongIsRefused() {
    Route r = good(20_000);
    Route forged =
        new Route(r.polyline(), r.distanceM() * 1.05, 0, 0, 0.8, 0, 0, 0, 0.1, null, null, null);
    assertEquals(
        GeneratedRouteSanity.Check.LENGTH,
        GeneratedRouteSanity.check(loopOf(20_000), forged).failed());
  }

  @Test
  void aRouteThatDoesNotStartNearTheStartIsRefused() {
    GenerateRequest elsewhere =
        new GenerateRequest(
            new GeoPoint(LAT + 5_000 / M_PER_DEG, LON), null, null, 20_000, "road", 0.25, 0);
    assertEquals(
        GeneratedRouteSanity.Check.ENDS,
        GeneratedRouteSanity.check(elsewhere, good(20_000)).failed());
  }

  @Test
  void aLoopThatDoesNotCloseIsRefused() {
    List<double[]> points = loopPoints(20_000, 1000);
    points.remove(points.size() - 1);
    points.remove(points.size() - 1); // ends 2 km from the start: not a loop
    // 18 km ridden for 20 km asked is within tolerance, the end is what fails
    assertEquals(
        GeneratedRouteSanity.Check.ENDS,
        GeneratedRouteSanity.check(loopOf(18_000), route(points, length(points), 0.8)).failed());
  }

  @Test
  void aTripNotEndingNearTheEndIsRefused() {
    List<double[]> points = new ArrayList<>();
    for (int i = 0; i <= 20; i++) {
      points.add(new double[] {LAT + i * 1000 / M_PER_DEG, LON});
    }
    GenerateRequest request =
        new GenerateRequest(
            new GeoPoint(LAT, LON),
            new GeoPoint(LAT + 25_000 / M_PER_DEG, LON),
            null,
            20_000,
            "road",
            0.25,
            0);
    assertEquals(
        GeneratedRouteSanity.Check.ENDS,
        GeneratedRouteSanity.check(request, route(points, length(points), 0.5)).failed());
  }

  @Test
  void aStepOfMoreThanTenKilometresIsRefused() {
    // a loop made of 11 km steps: the length and the ends are right, the teleport is not
    List<double[]> points = loopPoints(44_000, 11_000);
    assertEquals(
        GeneratedRouteSanity.Check.JUMP,
        GeneratedRouteSanity.check(loopOf(44_000), route(points, length(points), 0.8)).failed());
  }

  @Test
  void sharesOutsideZeroToOneAreRefused() {
    List<double[]> points = loopPoints(20_000, 1000);
    double d = length(points);
    for (double share : new double[] {-0.01, 1.01, Double.NaN}) {
      assertEquals(
          GeneratedRouteSanity.Check.SHARES,
          GeneratedRouteSanity.check(loopOf(20_000), route(points, d, share)).failed(),
          "share " + share);
    }
    Route r = route(points, d, 0.5);
    Route badUnpaved = new Route(r.polyline(), d, 0, 0, 0.5, 0, 0, 0, 1.2, null, null, null);
    assertEquals(
        GeneratedRouteSanity.Check.SHARES,
        GeneratedRouteSanity.check(loopOf(20_000), badUnpaved).failed());
    for (double offroad : new double[] {-0.01, 1.2, Double.NaN}) {
      Route badOffroad =
          new Route(r.polyline(), d, 0, 0, 0.5, 0, 0, 0, 0.1, null, null, null, 0.0, offroad);
      assertEquals(
          GeneratedRouteSanity.Check.SHARES,
          GeneratedRouteSanity.check(loopOf(20_000), badOffroad).failed(),
          "offroad share " + offroad);
    }
    Route goodOffroad =
        new Route(r.polyline(), d, 0, 0, 0.5, 0, 0, 0, 0.1, null, null, null, d * 0.4, 0.4);
    assertTrue(GeneratedRouteSanity.check(loopOf(20_000), goodOffroad).sane());
    Route negativeTail = new Route(r.polyline(), d, 0, 0, 0.5, -1, 0, 0, 0.1, null, null, null);
    assertEquals(
        GeneratedRouteSanity.Check.SHARES,
        GeneratedRouteSanity.check(loopOf(20_000), negativeTail).failed());
  }

  // ------------------------------------------------------------------ checkEdit

  private static EditedRoute edited(List<double[]> points, String kind, int from, int to) {
    return editedWith(points, length(points), kind, from, to, 0.9, 0.5);
  }

  private static EditedRoute editedWith(
      List<double[]> points,
      double distance,
      String kind,
      int from,
      int to,
      double kept,
      double team) {
    double[] lat = new double[points.size()];
    double[] lon = new double[points.size()];
    for (int i = 0; i < lat.length; i++) {
      lat[i] = points.get(i)[0];
      lon[i] = points.get(i)[1];
    }
    return new EditedRoute(
        kind,
        null,
        Polyline6Encoder.encode(lat, lon, 0, lat.length - 1),
        distance,
        null,
        0,
        kept,
        null,
        null,
        0,
        new Changed(0, 0, 0, List.of(from, to), 0, 0, team, 0, 0.1, 0));
  }

  /** The points are [lat, lon]; the context wants [lon, lat]. */
  private static GeneratedRouteSanity.EditContext context(
      List<double[]> original, Double target, GeoPoint end) {
    double[] f = original.getFirst();
    double[] l = original.getLast();
    return new GeneratedRouteSanity.EditContext(
        new double[] {f[1], f[0]}, new double[] {l[1], l[0]}, target, end);
  }

  private static List<double[]> line(double km, double stepM) {
    List<double[]> out = new ArrayList<>();
    for (int i = 0; i * stepM <= km * 1000; i++) {
      out.add(new double[] {LAT + i * stepM / M_PER_DEG, LON});
    }
    return out;
  }

  @Test
  void aSaneEditKeepsItsEndsAndIsFramed() {
    List<double[]> original = line(20, 500);
    var verdict =
        GeneratedRouteSanity.checkEdit(
            context(original, null, null), edited(original, "lengthen", 10, 12));
    assertTrue(verdict.sane(), String.valueOf(verdict.failed()));
    assertNotNull(verdict.bounds());
  }

  @Test
  void theIndicesMustFrameAStretchOfThePolyline() {
    List<double[]> original = line(20, 500);
    var ctx = context(original, null, null);
    for (int[] bad : new int[][] {{-1, 3}, {5, 4}, {3, original.size()}}) {
      assertEquals(
          GeneratedRouteSanity.Check.INDICES,
          GeneratedRouteSanity.checkEdit(ctx, edited(original, "lengthen", bad[0], bad[1]))
              .failed(),
          bad[0] + "," + bad[1]);
    }
  }

  @Test
  void aResizeIsHeldToItsTargetAndTheEngineToItsOwnLength() {
    List<double[]> original = line(20, 500);
    double d = length(original);
    EditedRoute route = edited(original, "shorten", 3, 4);
    assertTrue(GeneratedRouteSanity.checkEdit(context(original, d * 1.02, null), route).sane());
    assertEquals(
        GeneratedRouteSanity.Check.LENGTH,
        GeneratedRouteSanity.checkEdit(context(original, d * 1.3, null), route).failed());
    EditedRoute lying = editedWith(original, d * 1.5, "shorten", 3, 4, 0.9, 0.5);
    assertEquals(
        GeneratedRouteSanity.Check.LENGTH,
        GeneratedRouteSanity.checkEdit(context(original, null, null), lying).failed());
  }

  @Test
  void theEndsOfAResizeAreTheOriginalOnes() {
    List<double[]> original = line(20, 500);
    List<double[]> moved = new ArrayList<>(original);
    moved.set(moved.size() - 1, new double[] {LAT + 25_000 / M_PER_DEG, LON});
    assertEquals(
        GeneratedRouteSanity.Check.ENDS,
        GeneratedRouteSanity.checkEdit(
                context(original, null, null), edited(moved, "lengthen", 3, 4))
            .failed());
    List<double[]> shifted = new ArrayList<>(original);
    shifted.set(0, new double[] {LAT - 100 / M_PER_DEG, LON});
    assertEquals(
        GeneratedRouteSanity.Check.ENDS,
        GeneratedRouteSanity.checkEdit(
                context(original, null, null), edited(shifted, "lengthen", 3, 4))
            .failed());
  }

  @Test
  void aMovedEndLiesWithinTwoKilometresOfTheAskedPoint() {
    List<double[]> original = line(20, 500);
    List<double[]> route = new ArrayList<>(original.subList(0, 20));
    route.add(new double[] {LAT + 12_000 / M_PER_DEG, LON + 0.01});
    GeoPoint asked = new GeoPoint(LAT + 12_000 / M_PER_DEG, LON + 0.01);
    assertTrue(
        GeneratedRouteSanity.checkEdit(
                context(original, null, asked), edited(route, "move_end", 19, 20))
            .sane());
    GeoPoint far = new GeoPoint(LAT + 12_000 / M_PER_DEG, LON + 0.05);
    assertEquals(
        GeneratedRouteSanity.Check.ENDS,
        GeneratedRouteSanity.checkEdit(
                context(original, null, far), edited(route, "move_end", 19, 20))
            .failed());
  }

  @Test
  void aJumpIsSoughtInTheNewStretchOnly() {
    // a hole of 15 km in the person's own track
    List<double[]> hole = line(10, 500);
    hole.addAll(
        line(10, 500).stream().map(p -> new double[] {p[0] + 25_000 / M_PER_DEG, p[1]}).toList());
    var ctx = context(hole, null, null);
    // the new stretch is at the start: the hole is the kept part, the proposal stands
    assertTrue(GeneratedRouteSanity.checkEdit(ctx, edited(hole, "lengthen", 2, 3)).sane());
    // the new stretch contains the hole: refused
    assertEquals(
        GeneratedRouteSanity.Check.JUMP,
        GeneratedRouteSanity.checkEdit(ctx, edited(hole, "lengthen", 3, hole.size() - 3)).failed());
  }

  @Test
  void theSharesAndTheKindOfAnEditAreChecked() {
    List<double[]> original = line(20, 500);
    var ctx = context(original, null, null);
    assertEquals(
        GeneratedRouteSanity.Check.SHARES,
        GeneratedRouteSanity.checkEdit(
                ctx, editedWith(original, length(original), "lengthen", 3, 4, 1.4, 0.5))
            .failed());
    assertEquals(
        GeneratedRouteSanity.Check.SHARES,
        GeneratedRouteSanity.checkEdit(
                ctx, editedWith(original, length(original), "lengthen", 3, 4, 0.9, -0.1))
            .failed());
    assertEquals(
        GeneratedRouteSanity.Check.SHARES,
        GeneratedRouteSanity.checkEdit(ctx, edited(original, "teleport", 3, 4)).failed());
    EditedRoute garbled =
        new EditedRoute(
            "lengthen",
            null,
            "!!!",
            1,
            null,
            0,
            0.9,
            null,
            null,
            0,
            new Changed(0, 0, 0, List.of(1, 2), 0, 0, 0.5, 0, 0.1, 0));
    assertEquals(
        GeneratedRouteSanity.Check.DECODE, GeneratedRouteSanity.checkEdit(ctx, garbled).failed());
  }
}
