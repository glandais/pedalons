package fr.pedalons.infrastructure.valhalla;

/** Encodes Google-style polylines with 6 digits of precision, the inverse of {@link Polyline6Decoder}. */
public final class Polyline6Encoder {

  private static final double PRECISION = 1e6;

  private Polyline6Encoder() {}

  /**
   * Encodes the positions {@code from..toInclusive} of two parallel arrays, latitude first and then
   * longitude of each (the order of the format; the decoder gives {@code [lon, lat]}).
   */
  public static String encode(double[] lat, double[] lon, int from, int toInclusive) {
    StringBuilder out = new StringBuilder((toInclusive - from + 1) * 10);
    long previousLat = 0;
    long previousLon = 0;
    for (int i = from; i <= toInclusive; i++) {
      long la = Math.round(lat[i] * PRECISION);
      long lo = Math.round(lon[i] * PRECISION);
      write(out, la - previousLat);
      write(out, lo - previousLon);
      previousLat = la;
      previousLon = lo;
    }
    return out.toString();
  }

  private static void write(StringBuilder out, long delta) {
    long v = delta < 0 ? ~(delta << 1) : delta << 1;
    while (v >= 0x20) {
      out.append((char) ((0x20 | (v & 0x1f)) + 63));
      v >>= 5;
    }
    out.append((char) (v + 63));
  }
}
