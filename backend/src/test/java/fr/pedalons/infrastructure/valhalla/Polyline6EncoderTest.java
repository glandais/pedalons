package fr.pedalons.infrastructure.valhalla;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;
import org.junit.jupiter.api.Test;

class Polyline6EncoderTest {

  @Test
  void roundTripsWithTheDecoder() {
    double[] lat = {48.123456, 48.123999, 47.5, -33.865143, 0};
    double[] lon = {2.654321, 2.0, -1.25, 151.2099, -179.999999};
    List<double[]> decoded = Polyline6Decoder.decode(Polyline6Encoder.encode(lat, lon, 0, 4));
    assertEquals(5, decoded.size());
    for (int i = 0; i < 5; i++) {
      assertEquals(lon[i], decoded.get(i)[0], 1e-9);
      assertEquals(lat[i], decoded.get(i)[1], 1e-9);
    }
  }

  @Test
  void encodesASubInterval() {
    double[] lat = {1, 2, 3, 4};
    double[] lon = {5, 6, 7, 8};
    List<double[]> decoded = Polyline6Decoder.decode(Polyline6Encoder.encode(lat, lon, 1, 2));
    assertEquals(2, decoded.size());
    assertEquals(6, decoded.getFirst()[0], 1e-9);
    assertEquals(2, decoded.getFirst()[1], 1e-9);
    assertEquals(7, decoded.getLast()[0], 1e-9);
    assertEquals(3, decoded.getLast()[1], 1e-9);
  }
}
