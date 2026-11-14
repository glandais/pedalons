package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** The radius of the polygon shape is found by bisection on its perimeter (review M1). */
class PolygonFamilyTest {

  private static PolygonFamily.Shape shape(double[] a, double[] b, int k) {
    double[] jitter = new double[k];
    double[] fraction = new double[k];
    for (int i = 0; i < k; i++) {
      jitter[i] = (i - 1) * 6;
      fraction[i] = 0.02 * (i - 1);
    }
    return new PolygonFamily.Shape(true, a, b, 35, jitter, fraction, true);
  }

  @Test
  void theRadiusMakesThePerimeterTheTargetForALoop() {
    double[] a = {100, 200};
    for (int k = 2; k <= 3; k++) {
      PolygonFamily.Shape s = shape(a, a, k);
      double target = 20_000 / 1.3;
      assertEquals(target, s.perimeter(s.radiusFor(target)), 1);
    }
  }

  @Test
  void theRadiusMakesThePerimeterTheTargetForACloseEnd() {
    double[] a = {0, 0};
    for (double chord : new double[] {3000, 0.45 * 20_000}) {
      double[] b = {chord, 400};
      PolygonFamily.Shape s = shape(a, b, 3);
      double target = 20_000 / 1.3;
      double r = s.radiusFor(target);
      assertTrue(r > 50, "radius " + r + " for a chord of " + chord);
      assertEquals(target, s.perimeter(r), 1, "chord " + chord);
    }
  }

  @Test
  void anAnchorPairAlreadyFurtherApartThanTheTargetGetsTheMinimumRadius() {
    PolygonFamily.Shape s = shape(new double[] {0, 0}, new double[] {9000, 0}, 2);
    assertEquals(50, s.radiusFor(5000), 0);
  }
}
