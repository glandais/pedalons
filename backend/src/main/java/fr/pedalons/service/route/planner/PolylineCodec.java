package fr.pedalons.service.route.planner;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;

/**
 * Strict Google-style polyline codec for a planner state sent by a client (docs/LEDGER_*.md WEB-100,
 * C4a).
 *
 * <p>Not {@code Polyline6Decoder}, which decodes what the router answers and is lenient: it throws
 * {@code StringIndexOutOfBoundsException} on a truncated string, overflows an {@code int} on a long
 * varint and accepts characters below 63. Here every malformed input is a {@code
 * PLANNER_STATE_INVALID}, and the number of points is bounded <em>while</em> decoding.
 *
 * <p>Two dimensions: latitude then longitude, precision 6, returned as {@code [lng, lat]}. One
 * dimension: a factor of 10 (tenths of a metre, for elevations).
 */
public final class PolylineCodec {

  private static final double PRECISION = 1e6;
  private static final double ELE_FACTOR = 10.0;

  /** 7 blocks of 5 bits: 35 bits, more than any coordinate delta needs. */
  private static final int MAX_BLOCKS = 7;

  private static final long MAX_LAT_E6 = 90_000_000L;
  private static final long MAX_LNG_E6 = 180_000_000L;

  private PolylineCodec() {}

  /**
   * Decodes a two-dimension polyline into {@code [lng, lat]} pairs.
   *
   * @param budget the most points accepted; one more is refused before it is stored
   */
  public static double[][] decode2(String encoded, int budget) {
    // A point takes at least two characters: this bounds the allocation before decoding.
    int cap = Math.min(budget, encoded.length() / 2);
    double[][] out = new double[cap][];
    int count = 0;
    int[] cursor = {0};
    long lat = 0;
    long lng = 0;
    while (cursor[0] < encoded.length()) {
      lat += nextValue(encoded, cursor);
      if (cursor[0] >= encoded.length()) {
        throw invalid(); // a latitude without its longitude
      }
      lng += nextValue(encoded, cursor);
      if (Math.abs(lat) > MAX_LAT_E6 || Math.abs(lng) > MAX_LNG_E6) {
        throw invalid();
      }
      if (count >= budget || count >= cap) {
        throw invalid();
      }
      out[count++] = new double[] {lng / PRECISION, lat / PRECISION};
    }
    return count == out.length ? out : java.util.Arrays.copyOf(out, count);
  }

  /** Decodes a one-dimension polyline of exactly {@code expected} values (metres). */
  public static double[] decode1(String encoded, int expected) {
    double[] out = new double[expected];
    int count = 0;
    int[] cursor = {0};
    long value = 0;
    while (cursor[0] < encoded.length()) {
      value += nextValue(encoded, cursor);
      if (count >= expected) {
        throw invalid();
      }
      out[count++] = value / ELE_FACTOR;
    }
    if (count != expected) {
      throw invalid();
    }
    return out;
  }

  /** Reads one zigzag varint at {@code cursor[0]} and advances it. */
  private static long nextValue(String s, int[] cursor) {
    long result = 0;
    int blocks = 0;
    int b;
    do {
      if (cursor[0] >= s.length() || blocks >= MAX_BLOCKS) {
        throw invalid();
      }
      char c = s.charAt(cursor[0]++);
      if (c < 63 || c > 126) {
        throw invalid();
      }
      b = c - 63;
      result |= (long) (b & 0x1f) << (5 * blocks);
      blocks++;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  private static BusinessException invalid() {
    return new BusinessException(ErrorCode.PLANNER_STATE_INVALID);
  }

  // ------------------------------------------------------------------ encoders (tests, symmetry)

  /** Encodes {@code [lng, lat]} pairs at precision 6. */
  public static String encode2(double[][] lngLat) {
    StringBuilder sb = new StringBuilder();
    long prevLat = 0;
    long prevLng = 0;
    for (double[] p : lngLat) {
      long lat = Math.round(p[1] * PRECISION);
      long lng = Math.round(p[0] * PRECISION);
      writeValue(sb, lat - prevLat);
      writeValue(sb, lng - prevLng);
      prevLat = lat;
      prevLng = lng;
    }
    return sb.toString();
  }

  /** Encodes metres at a tenth of a metre. */
  public static String encode1(double[] values) {
    StringBuilder sb = new StringBuilder();
    long prev = 0;
    for (double v : values) {
      long x = Math.round(v * ELE_FACTOR);
      writeValue(sb, x - prev);
      prev = x;
    }
    return sb.toString();
  }

  private static void writeValue(StringBuilder sb, long delta) {
    long v = delta < 0 ? ~(delta << 1) : (delta << 1);
    while (v >= 0x20) {
      sb.append((char) ((0x20 | (v & 0x1f)) + 63));
      v >>= 5;
    }
    sb.append((char) (v + 63));
  }
}
