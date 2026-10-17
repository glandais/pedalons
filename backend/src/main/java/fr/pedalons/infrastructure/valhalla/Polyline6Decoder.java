package fr.pedalons.infrastructure.valhalla;

import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;

/** Decodes Google-style encoded polylines with 6 digits of precision (the Valhalla protocol, as served by Stadia Maps). */
public final class Polyline6Decoder {

  private static final double PRECISION = 1e6;

  private Polyline6Decoder() {}

  /** Decodes an encoded polyline6 string into a list of [lon, lat] coordinate pairs. */
  public static List<double[]> decode(@Nullable String encoded) {
    if (encoded == null || encoded.isEmpty()) {
      return List.of();
    }
    List<double[]> coordinates = new ArrayList<>();
    int index = 0;
    int lat = 0;
    int lon = 0;

    while (index < encoded.length()) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.charAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.charAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lon += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      coordinates.add(new double[] {lon / PRECISION, lat / PRECISION});
    }
    return coordinates;
  }
}
