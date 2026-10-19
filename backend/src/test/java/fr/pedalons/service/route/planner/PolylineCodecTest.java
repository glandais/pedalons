package fr.pedalons.service.route.planner;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import org.junit.jupiter.api.Test;

class PolylineCodecTest {

  @Test
  void roundTrip2d() {
    double[][] points = {{4.835659, 45.764043}, {4.841122, 45.77187}, {-122.5, -33.123456}};
    double[][] back = PolylineCodec.decode2(PolylineCodec.encode2(points), 10);
    assertEquals(3, back.length);
    for (int i = 0; i < points.length; i++) {
      assertArrayEquals(points[i], back[i], 1e-9);
    }
  }

  @Test
  void roundTrip1d() {
    double[] ele = {171.2, 176.0, -3.4, 0, 1250.9};
    assertArrayEquals(ele, PolylineCodec.decode1(PolylineCodec.encode1(ele), 5), 1e-9);
  }

  @Test
  void emptyString() {
    assertEquals(0, PolylineCodec.decode2("", 10).length);
    assertEquals(0, PolylineCodec.decode1("", 0).length);
  }

  @Test
  void truncatedStringIsRefused() {
    String encoded = PolylineCodec.encode2(new double[][] {{4.835659, 45.764043}});
    assertInvalid(() -> PolylineCodec.decode2(encoded.substring(0, encoded.length() - 1), 10));
    // A latitude without its longitude
    String lat = encoded.substring(0, encoded.length() / 2);
    assertInvalid(() -> PolylineCodec.decode2(lat, 10));
  }

  @Test
  void charactersOutOfRangeAreRefused() {
    assertInvalid(() -> PolylineCodec.decode2("_p~iF~ps|U ", 10));
    assertInvalid(() -> PolylineCodec.decode2("_p~iF~ps|U\u007f", 10));
    assertInvalid(() -> PolylineCodec.decode1("!", 1));
  }

  @Test
  void tooLongVarintIsRefused() {
    // Eight continuation blocks in a row
    assertInvalid(() -> PolylineCodec.decode1("~~~~~~~~?", 1));
  }

  @Test
  void budgetIsEnforcedWhileDecoding() {
    String encoded = PolylineCodec.encode2(new double[][] {{1, 1}, {2, 2}, {3, 3}});
    assertEquals(3, PolylineCodec.decode2(encoded, 3).length);
    assertInvalid(() -> PolylineCodec.decode2(encoded, 2));
  }

  @Test
  void coordinatesOutOfWgs84AreRefused() {
    String encoded = PolylineCodec.encode2(new double[][] {{181, 0}});
    assertInvalid(() -> PolylineCodec.decode2(encoded, 5));
  }

  @Test
  void wrongCardinalityOfOneDimensionIsRefused() {
    String encoded = PolylineCodec.encode1(new double[] {1, 2, 3});
    assertInvalid(() -> PolylineCodec.decode1(encoded, 2));
    assertInvalid(() -> PolylineCodec.decode1(encoded, 4));
  }

  private static void assertInvalid(org.junit.jupiter.api.function.Executable e) {
    BusinessException ex = assertThrows(BusinessException.class, e);
    assertEquals(ErrorCode.PLANNER_STATE_INVALID, ex.getErrorCode());
  }
}
