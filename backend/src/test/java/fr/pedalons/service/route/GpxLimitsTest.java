package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Plain unit test of the bounds of the GPX pipeline (docs/LEDGER_*.md SEC-6). */
class GpxLimitsTest {

  private static Path path(double[]... latLngDeg) {
    List<CoordinatesElevation> coordinates = new ArrayList<>();
    for (double[] p : latLngDeg) {
      coordinates.add(new LatLonElevation(p[0], p[1], 0.0));
    }
    return PathJvm.fromCoordinates(coordinates);
  }

  private static ErrorCode refusal(Path... paths) {
    BusinessException e =
        assertThrows(BusinessException.class, () -> GpxLimits.checkTracks(List.of(paths)));
    return e.getErrorCode();
  }

  @Test
  void aRealisticTrack_isAccepted() {
    // Lyon to Paris and back, about 800 km.
    assertDoesNotThrow(
        () ->
            GpxLimits.checkTracks(
                List.of(
                    path(
                        new double[] {45.76, 4.84},
                        new double[] {48.86, 2.35},
                        new double[] {45.76, 4.84}))));
  }

  @Test
  void aTrackAHemisphereLong_isRefused() {
    assertEquals(ErrorCode.GPX_TOO_LONG, refusal(path(new double[] {0, 0}, new double[] {0, 179})));
  }

  /** The bound is on the sum over the tracks of a file, not per track. */
  @Test
  void tracksAddingUpPastTheBound_areRefused() {
    // Each about 2 100 km (Lyon to the Atlantic off Portugal), over 4 000 km together.
    Path first = path(new double[] {45.76, 4.84}, new double[] {38.72, -20.0});
    Path second = path(new double[] {45.76, 4.84}, new double[] {38.72, -20.0});
    assertDoesNotThrow(() -> GpxLimits.checkTracks(List.of(first)));
    assertEquals(ErrorCode.GPX_TOO_LONG, refusal(first, second));
  }

  @Test
  void anOutOfRangeLatitude_isRefused() {
    assertEquals(ErrorCode.GPX_FAILURE, refusal(path(new double[] {0, 0}, new double[] {91, 0})));
  }

  @Test
  void aNaNCoordinate_isRefused() {
    assertEquals(
        ErrorCode.GPX_FAILURE, refusal(path(new double[] {0, 0}, new double[] {Double.NaN, 0})));
  }
}
