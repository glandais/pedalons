package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class GeoTest {

  @Test
  void bearingsOfTheFourAxes() {
    assertEquals(0, Geo.bearingDeg(0, 0, 0, 10), 1e-9);
    assertEquals(90, Geo.bearingDeg(0, 0, 10, 0), 1e-9);
    assertEquals(180, Geo.bearingDeg(0, 0, 0, -10), 1e-9);
    assertEquals(270, Geo.bearingDeg(0, 0, -10, 0), 1e-9);
  }

  @Test
  void turnAngleIsSymmetricAndBounded() {
    assertEquals(0, Geo.turnAngleDeg(42, 42), 1e-9);
    assertEquals(180, Geo.turnAngleDeg(10, 190), 1e-9);
    assertEquals(20, Geo.turnAngleDeg(10, 350), 1e-9);
    assertEquals(Geo.turnAngleDeg(10, 350), Geo.turnAngleDeg(350, 10), 1e-9);
    assertEquals(155, Geo.turnAngleDeg(90, 245), 1e-9);
  }

  @Test
  void pointAlongWithCumulativeLengthsEqualsTheWalkedOne() {
    // two polylines in shared arrays, the second one with zero-length steps and sharp bends
    double[] xs = {5, 0, 10, 10, 30, 30, 30, 12, 0, 0, 0, 7, 7};
    double[] ys = {5, 0, 0, 10, 10, 10, 40, 40, 40, 40, 3, 3, -9};
    double[] cum = new double[xs.length];
    Geo.cumulate(xs, ys, 0, 4, cum);
    Geo.cumulate(xs, ys, 4, xs.length, cum);
    double[] a = new double[2];
    double[] b = new double[2];
    for (int[] range : new int[][] {{0, 4}, {4, xs.length}}) {
      for (boolean reversed : new boolean[] {false, true}) {
        for (double off = -3; off < 120; off += 0.7) {
          Geo.pointAlong(xs, ys, range[0], range[1], reversed, off, a);
          Geo.pointAlongCum(xs, ys, cum, range[0], range[1], reversed, off, b);
          assertArrayEquals(
              a, b, 1e-9, "range " + range[0] + " reversed " + reversed + " at " + off);
        }
      }
    }
  }

  @Test
  void pointAtClampsToTheEnds() {
    double[] xs = {0, 10, 10};
    double[] ys = {0, 0, 10};
    assertArrayEquals(new double[] {0, 0}, Geo.pointAt(xs, ys, -5), 1e-9);
    assertArrayEquals(new double[] {5, 0}, Geo.pointAt(xs, ys, 5), 1e-9);
    assertArrayEquals(new double[] {10, 5}, Geo.pointAt(xs, ys, 15), 1e-9);
    assertArrayEquals(new double[] {10, 10}, Geo.pointAt(xs, ys, 500), 1e-9);
  }

  @Test
  void projectionRoundTripIsBelowOneMillimetreNearTheReference() {
    LocalProjection p = new LocalProjection(45.0, 5.0);
    for (double[] xy : new double[][] {{0, 0}, {1234.5, -987.6}, {-20000, 15000}}) {
      LatLon ll = p.toLatLon(xy[0], xy[1]);
      assertEquals(xy[0], p.toX(ll.lat(), ll.lon()), 1e-3);
      assertEquals(xy[1], p.toY(ll.lat(), ll.lon()), 1e-3);
    }
  }

  @Test
  void headingsIgnoreTheFirstMetresOfADrawing() {
    // wiggles for 22 m, then north for 78 m, then east for 100 m
    double[] xs = {0, 5, 0, 0, 100};
    double[] ys = {0, 10, 20, 100, 100};
    double[] h = Geo.headings(xs, ys, 30, 50);
    assertEquals(0, Geo.turnAngleDeg(h[0], 0), 0.5);
    assertEquals(90, h[1], 0.5);
  }

  @Test
  void headingsOfAShortEdgeUseAClampedWindow() {
    double[] h = Geo.headings(new double[] {0, 31}, new double[] {0, 0}, 30, 50);
    assertEquals(90, h[0], 1e-6);
    assertEquals(90, h[1], 1e-6);
  }

  @Test
  void sliceInterpolatesBothEnds() {
    double[][] s = Geo.slice(new double[] {0, 10, 10}, new double[] {0, 0, 10}, 5, 15);
    assertArrayEquals(new double[] {5, 10, 10}, s[0], 1e-9);
    assertArrayEquals(new double[] {0, 0, 5}, s[1], 1e-9);
  }

  @Test
  void projectGivesDistanceAndOffset() {
    Geo.Projection pr = Geo.project(5, 3, new double[] {0, 10}, new double[] {0, 0});
    assertEquals(3, pr.distance(), 1e-9);
    assertEquals(5, pr.along(), 1e-9);
  }
}
