package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.enums.WindDirection;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

/**
 * Reference values below were <b>not</b> guessed: they were captured by reasoning through {@link
 * WindEstimator#findDirectionFromVector(double, double)}'s own formula while gpx2web was still the
 * live implementation (migration plan §8) — for each {@link WindDirection}, the method's reference
 * unit vector for that sector was computed, and this test asserts that feeding that exact vector
 * back in resolves to the <em>opposite</em> sector, because the method keeps the lowest (most
 * anti-parallel) score, not the highest.
 *
 * <p>Pure JVM test, no {@code @QuarkusTest} — {@link WindEstimator} has no CDI dependency, and
 * this file is the only thing standing between the reference frame and someone "fixing" it.
 */
class WindEstimatorTest {

  private static final double SQRT2_OVER_2 = Math.sqrt(2) / 2;

  @Nested
  class EightSectors {

    // Each case feeds in gpx2web's Mercator-frame (Y south) reference vector for the sector named
    // in the input, and expects the diametrically opposite WindDirection back — see class javadoc.

    @Test
    void north() {
      assertEquals(WindDirection.SOUTH, WindEstimator.findDirectionFromVector(0, -1));
    }

    @Test
    void northEast() {
      assertEquals(
          WindDirection.SOUTH_WEST,
          WindEstimator.findDirectionFromVector(SQRT2_OVER_2, -SQRT2_OVER_2));
    }

    @Test
    void east() {
      assertEquals(WindDirection.WEST, WindEstimator.findDirectionFromVector(1, 0));
    }

    @Test
    void southEast() {
      assertEquals(
          WindDirection.NORTH_WEST,
          WindEstimator.findDirectionFromVector(SQRT2_OVER_2, SQRT2_OVER_2));
    }

    @Test
    void south() {
      assertEquals(WindDirection.NORTH, WindEstimator.findDirectionFromVector(0, 1));
    }

    @Test
    void southWest() {
      assertEquals(
          WindDirection.NORTH_EAST,
          WindEstimator.findDirectionFromVector(-SQRT2_OVER_2, SQRT2_OVER_2));
    }

    @Test
    void west() {
      assertEquals(WindDirection.EAST, WindEstimator.findDirectionFromVector(-1, 0));
    }

    @Test
    void northWest() {
      assertEquals(
          WindDirection.SOUTH_EAST,
          WindEstimator.findDirectionFromVector(-SQRT2_OVER_2, -SQRT2_OVER_2));
    }
  }

  @Nested
  class SectorBoundaries {

    // At the exact bisector between two sectors both candidates tie at the same (lowest) score;
    // .sorted(...).findFirst() then keeps whichever WindDirection is declared first in the enum
    // (NORTH before NORTH_EAST). A half-degree either side of the bisector breaks the tie cleanly
    // — this is what would catch someone reversing the sort direction without also breaking the
    // eight pure-sector cases above (a reversal there flips *all* of them, a reversal only in the
    // tie-break would flip only this family).
    private static final double BISECTOR_DEG = 112.5;

    @Test
    void exactBisectorBetweenNorthAndNorthEastKeepsTheFirstDeclaredEnumConstant() {
      double rad = Math.toRadians(BISECTOR_DEG);
      assertEquals(
          WindDirection.NORTH, WindEstimator.findDirectionFromVector(Math.cos(rad), Math.sin(rad)));
    }

    @Test
    void justBeforeTheBisectorStillResolvesToNorth() {
      double rad = Math.toRadians(BISECTOR_DEG - 0.1);
      assertEquals(
          WindDirection.NORTH, WindEstimator.findDirectionFromVector(Math.cos(rad), Math.sin(rad)));
    }

    @Test
    void justPastTheBisectorTipsOverToNorthEast() {
      double rad = Math.toRadians(BISECTOR_DEG + 0.1);
      assertEquals(
          WindDirection.NORTH_EAST,
          WindEstimator.findDirectionFromVector(Math.cos(rad), Math.sin(rad)));
    }
  }

  @Nested
  class DegenerateComponents {

    @Test
    void zeroXComponentBehavesLikeThePureSouthCaseAtAnyMagnitude() {
      // x = 0, y = 5: same direction as the pure south case above (only the magnitude differs),
      // scaling must not matter since every reference vector is normalized inside the method.
      assertEquals(WindDirection.NORTH, WindEstimator.findDirectionFromVector(0, 5));
    }

    @Test
    void zeroYComponentBehavesLikeThePureEastCaseAtAnyMagnitude() {
      assertEquals(WindDirection.WEST, WindEstimator.findDirectionFromVector(5, 0));
    }

    @Test
    void zeroVectorTiesEveryScoreAndKeepsTheFirstDeclaredEnumConstant() {
      assertEquals(WindDirection.NORTH, WindEstimator.findDirectionFromVector(0, 0));
    }

    @Test
    void magnitudeDoesNotChangeTheAnswer() {
      assertEquals(WindDirection.WEST, WindEstimator.findDirectionFromVector(100, 0));
      assertEquals(WindDirection.WEST, WindEstimator.findDirectionFromVector(1e-9, 0));
    }
  }

  /**
   * The frame conversion itself — the one thing migration plan §4 says this file exists to lock
   * down. Everything above exercises the scoring in gpx2web's frame, which the swap left alone;
   * these two exercise {@link WindEstimator#estimate}, where vcyclist's north-up vector is flipped
   * into gpx2web's south-up one. Drop the minus sign in {@code estimate} and both invert.
   */
  @Nested
  class NorthUpToSouthUpFrame {

    /** Straight meridian leg, enough points to clear vcyclist's {@code size > 3} threshold. */
    private static Path meridian(double startLat, double stepDeg) {
      List<CoordinatesElevation> coordinates = new ArrayList<>();
      for (int i = 0; i < 20; i++) {
        coordinates.add(new LatLonElevation(startLat + (i * stepDeg), 5.0, 100.0));
      }
      return PathJvm.fromCoordinates(coordinates);
    }

    @Test
    void northboundRouteReportsNorth() {
      assertEquals(WindDirection.NORTH, WindEstimator.estimate(List.of(meridian(45.0, 0.01))));
    }

    @Test
    void southboundRouteReportsSouth() {
      assertEquals(WindDirection.SOUTH, WindEstimator.estimate(List.of(meridian(45.2, -0.01))));
    }

    @Test
    void tooFewPointsYieldsNoDirectionRatherThanThrowing() {
      Path stub =
          PathJvm.fromCoordinates(
              List.of(
                  new LatLonElevation(45.0, 5.0, 100.0), new LatLonElevation(45.1, 5.0, 100.0)));
      assertNull(WindEstimator.estimate(List.of(stub)));
    }
  }
}
