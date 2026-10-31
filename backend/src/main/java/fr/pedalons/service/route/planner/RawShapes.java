package fr.pedalons.service.route.planner;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.service.surface.TrackAxisMapping;
import java.util.Arrays;

/**
 * The raw shapes of a planner state (docs/LEDGER_*.md API-147, phase C): the geometry the router
 * drew or the file held, which the saved track is derived from instead of the simplified {@code
 * line} the editor displays. The client carries them without reading them, so nothing guarantees
 * that a shape still stands for its piece: {@link #consistent} decides, and a shape that fails it is
 * ignored, the piece falling back on its line. Points are {@code [lng, lat]}, as {@link
 * PolylineCodec} decodes them. Pure.
 */
final class RawShapes {

  /** Farthest a raw shape may end from the ends of the line it stands for. */
  static final double MAX_END_GAP_M = 50;

  /** A raw shape may be this much longer or shorter than its line... */
  static final double LENGTH_TOLERANCE = 0.2;

  /** ...plus this, metres. */
  static final double LENGTH_MARGIN_M = 200;

  /** A first or last raw point this near its junction is that junction (the end of a leg). */
  static final double SAME_POINT_M = 1;

  /** A raw point this near a cut is the junction there. */
  static final double CUT_EPSILON_M = 0.01;

  private RawShapes() {}

  /**
   * Whether {@code raw[rawLo, rawHi)} and {@code line[lineLo, lineHi)}, both between the ends {@code
   * from} and {@code to}, describe the same ground: the raw shape starts and ends within {@link
   * #MAX_END_GAP_M} of those ends, and its length (ends included) is within {@link
   * #LENGTH_TOLERANCE} of the line's plus {@link #LENGTH_MARGIN_M}. A raw shape with no point is a
   * straight line between the ends and only the length applies.
   */
  static boolean consistent(
      double[] from,
      double[][] raw,
      int rawLo,
      int rawHi,
      double[][] line,
      int lineLo,
      int lineHi,
      double[] to) {
    if (rawHi > rawLo
        && (distance(from, raw[rawLo]) > MAX_END_GAP_M
            || distance(raw[rawHi - 1], to) > MAX_END_GAP_M)) {
      return false;
    }
    double rawLength = length(from, raw, rawLo, rawHi, to);
    double lineLength = length(from, line, lineLo, lineHi, to);
    return Math.abs(rawLength - lineLength) <= LENGTH_TOLERANCE * lineLength + LENGTH_MARGIN_M;
  }

  /**
   * A routed shape without the ends it may share with its junctions: the router's shape starts and
   * ends on the junctions it was asked for, which the piece's interior excludes.
   */
  static double[][] trimEnds(double[] from, double[][] raw, double[] to) {
    int lo = 0;
    int hi = raw.length;
    if (hi > lo && distance(from, raw[lo]) <= SAME_POINT_M) {
      lo++;
    }
    if (hi > lo && distance(raw[hi - 1], to) <= SAME_POINT_M) {
      hi--;
    }
    return lo == 0 && hi == raw.length ? raw : Arrays.copyOfRange(raw, lo, hi);
  }

  /**
   * Where the points {@code indices} of a source line fall on the raw track of that source, as
   * distances along the raw track: the line is walked forward and each station located with a
   * forward-only nearest-segment search ({@link TrackAxisMapping}), so a source that comes back along
   * itself is not cut on the wrong leg. The first point of the line maps on 0, its last on the
   * length of the raw track.
   *
   * <p>The walk takes a station every few metres of the line: the caller bounds the line's length
   * first.
   *
   * @param lineDist {@link #cumulative} of {@code line}
   * @param indices ascending
   */
  static double[] locate(
      double[][] line, double[] lineDist, double[][] raw, double[] rawDist, int[] indices) {
    double[] sorted = new double[indices.length];
    for (int i = 0; i < indices.length; i++) {
      sorted[i] = lineDist[indices[i]];
    }
    return TrackAxisMapping.map(
        lat(line), lng(line), lineDist, lat(raw), lng(raw), rawDist, sorted);
  }

  /**
   * The points of a raw track strictly between the distances {@code from} and {@code to} along it,
   * as {@code [lo, hi)}. A point within {@link #CUT_EPSILON_M} of a cut is the junction there, which
   * the piece already has (the location of a vertex may come back a rounding off).
   */
  static int[] between(double[] rawDist, double from, double to) {
    int lo = firstAbove(rawDist, from + CUT_EPSILON_M);
    // The first index at or past to, give or take the same
    int hi = Math.max(lo, firstAbove(rawDist, Math.nextDown(to - CUT_EPSILON_M)));
    return new int[] {lo, hi};
  }

  /** Cumulative distances along {@code points}, from 0, metres. */
  static double[] cumulative(double[][] points) {
    double[] out = new double[points.length];
    for (int i = 1; i < points.length; i++) {
      out[i] = out[i - 1] + distance(points[i - 1], points[i]);
    }
    return out;
  }

  /** The first index whose distance is strictly above {@code d}. */
  private static int firstAbove(double[] dist, double d) {
    int lo = 0;
    int hi = dist.length;
    while (lo < hi) {
      int mid = (lo + hi) >>> 1;
      if (dist[mid] > d) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  private static double length(double[] from, double[][] points, int lo, int hi, double[] to) {
    if (hi <= lo) {
      return distance(from, to);
    }
    double sum = distance(from, points[lo]) + distance(points[hi - 1], to);
    for (int i = lo + 1; i < hi; i++) {
      sum += distance(points[i - 1], points[i]);
    }
    return sum;
  }

  private static double distance(double[] a, double[] b) {
    return GeoDistance.haversineMeters(a[1], a[0], b[1], b[0]);
  }

  private static double[] lat(double[][] points) {
    double[] out = new double[points.length];
    for (int i = 0; i < points.length; i++) {
      out[i] = points[i][1];
    }
    return out;
  }

  private static double[] lng(double[][] points) {
    double[] out = new double[points.length];
    for (int i = 0; i < points.length; i++) {
      out[i] = points[i][0];
    }
    return out;
  }
}
