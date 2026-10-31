package fr.pedalons.service.route.planner;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** The trust check of the raw shapes of a planner state (docs/LEDGER_*.md API-147, phase C). */
class RawShapesTest {

  /** Metres of one degree of latitude, on the sphere GeoDistance uses. */
  private static final double M_PER_DEG_LAT = Math.PI / 180 * 6_371_008.8;

  private static final double[] FROM = {4.83, 45.76};
  private static final double[] TO = {4.83, 45.76 + 1_000 / M_PER_DEG_LAT};
  private static final double[][] NONE = new double[0][];

  /** A point {@code north} metres north of FROM, {@code east} metres east. */
  private static double[] at(double north, double east) {
    double cos = Math.cos(Math.toRadians(FROM[1]));
    return new double[] {FROM[0] + east / (M_PER_DEG_LAT * cos), FROM[1] + north / M_PER_DEG_LAT};
  }

  private static boolean consistent(double[][] raw) {
    return RawShapes.consistent(FROM, raw, 0, raw.length, NONE, 0, 0, TO);
  }

  @Test
  void theEndsMayBeUpTo50MetresFromTheJunctions() {
    assertTrue(consistent(new double[][] {at(0, 49), at(1_000, 49)}));
    assertFalse(consistent(new double[][] {at(0, 51), at(1_000, 0)}));
    assertFalse(consistent(new double[][] {at(0, 0), at(1_000, 51)}));
  }

  @Test
  void theLengthMayDifferBy20PercentPlus200Metres() {
    // The line is 1 000 m: up to 1 400 m of raw shape, out and back sideways
    assertTrue(consistent(new double[][] {at(0, 0), at(500, 480), at(1_000, 0)}));
    assertFalse(consistent(new double[][] {at(0, 0), at(500, 500), at(1_000, 0)}));
  }

  @Test
  void anEmptyShapeIsAStraightLine() {
    assertTrue(consistent(NONE));
  }

  @Test
  void theRoutersEndsAreDroppedOthersKept() {
    double[][] raw = {FROM, at(500, 0), TO};
    assertArrayEquals(new double[][] {at(500, 0)}, RawShapes.trimEnds(FROM, raw, TO));
    double[][] apart = {at(0, 5), at(500, 0), at(1_000, 5)};
    assertSame(apart, RawShapes.trimEnds(FROM, apart, TO));
  }

  @Test
  void aCutKeepsThePointsStrictlyBetweenItsEnds() {
    double[] dist = {0, 10, 20, 30, 40};
    assertArrayEquals(new int[] {1, 3}, RawShapes.between(dist, 0, 30));
    assertArrayEquals(new int[] {2, 3}, RawShapes.between(dist, 10.004, 29.996));
    assertArrayEquals(new int[] {2, 2}, RawShapes.between(dist, 15, 15));
    assertEquals(5, RawShapes.between(dist, 0, 50)[1]);
  }
}
