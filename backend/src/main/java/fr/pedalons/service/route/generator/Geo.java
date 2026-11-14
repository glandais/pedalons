package fr.pedalons.service.route.generator;

/** Static helpers on projected (metre) polylines. */
final class Geo {
  private Geo() {}

  /** Result of projecting a point onto a polyline. */
  record Projection(double distance, double along, double x, double y) {}

  /** Bearing in degrees, 0 = north, clockwise, in [0, 360). */
  static double bearingDeg(double x1, double y1, double x2, double y2) {
    return normalizeDeg(Math.toDegrees(Math.atan2(x2 - x1, y2 - y1)));
  }

  static double normalizeDeg(double deg) {
    double d = deg % 360.0;
    return d < 0 ? d + 360.0 : d;
  }

  /** Absolute change of heading between two bearings, in [0, 180]: 0 straight on, 180 U-turn. */
  static double turnAngleDeg(double inBearing, double outBearing) {
    double d = normalizeDeg(outBearing - inBearing);
    return d > 180 ? 360 - d : d;
  }

  static double polylineLength(double[] xs, double[] ys) {
    double len = 0;
    for (int i = 1; i < xs.length; i++) {
      len += Math.hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]);
    }
    return len;
  }

  /**
   * Allocation-free {@link #pointAt} on the range {@code [from, to)} of shared coordinate arrays,
   * walked forward or backward; the point is written to {@code out}.
   */
  static void pointAlong(
      double[] xs, double[] ys, int from, int to, boolean reversed, double offsetM, double[] out) {
    int first = reversed ? to - 1 : from;
    int step = reversed ? -1 : 1;
    int n = to - from;
    out[0] = xs[first];
    out[1] = ys[first];
    if (offsetM <= 0) {
      return;
    }
    double acc = 0;
    for (int k = 1; k < n; k++) {
      int a = first + (k - 1) * step;
      int b = a + step;
      double seg = Math.hypot(xs[b] - xs[a], ys[b] - ys[a]);
      if (acc + seg >= offsetM) {
        double t = seg == 0 ? 0 : (offsetM - acc) / seg;
        out[0] = xs[a] + t * (xs[b] - xs[a]);
        out[1] = ys[a] + t * (ys[b] - ys[a]);
        return;
      }
      acc += seg;
    }
    int last = first + (n - 1) * step;
    out[0] = xs[last];
    out[1] = ys[last];
  }

  /**
   * {@link #pointAlong} with the cumulative lengths of the points precomputed ({@code cum[k]} =
   * length of the polyline from point {@code from} to point {@code k}, for {@code k} in {@code
   * [from, to)}): a binary search instead of a walk, for the edges with many points.
   */
  static void pointAlongCum(
      double[] xs,
      double[] ys,
      double[] cum,
      int from,
      int to,
      boolean reversed,
      double offsetM,
      double[] out) {
    int n = to - from;
    int first = reversed ? to - 1 : from;
    out[0] = xs[first];
    out[1] = ys[first];
    if (offsetM <= 0 || n < 2) {
      return;
    }
    double base = cum[from];
    double total = cum[to - 1] - base;
    if (offsetM > total) {
      int last = reversed ? from : to - 1;
      out[0] = xs[last];
      out[1] = ys[last];
      return;
    }
    if (!reversed) {
      // the first point k whose cumulative length reaches the offset
      int lo = from + 1;
      int hi = to - 1;
      while (lo < hi) {
        int mid = (lo + hi) >>> 1;
        if (cum[mid] - base >= offsetM) {
          hi = mid;
        } else {
          lo = mid + 1;
        }
      }
      double c0 = cum[lo - 1] - base;
      double seg = cum[lo] - base - c0;
      double t = seg == 0 ? 0 : (offsetM - c0) / seg;
      out[0] = xs[lo - 1] + t * (xs[lo] - xs[lo - 1]);
      out[1] = ys[lo - 1] + t * (ys[lo] - ys[lo - 1]);
    } else {
      // walking back from the last point: the last point b whose length from the start is at
      // most total - offset
      double target = total - offsetM;
      int lo = from;
      int hi = to - 2;
      while (lo < hi) {
        int mid = (lo + hi + 1) >>> 1;
        if (cum[mid] - base <= target) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      int a = lo + 1;
      double seg = cum[a] - cum[lo];
      double acc = total - (cum[a] - base);
      double t = seg == 0 ? 0 : (offsetM - acc) / seg;
      out[0] = xs[a] + t * (xs[lo] - xs[a]);
      out[1] = ys[a] + t * (ys[lo] - ys[a]);
    }
  }

  /** Fills {@code cum[k]} for the points {@code [from, to)}: the length from point {@code from}. */
  static void cumulate(double[] xs, double[] ys, int from, int to, double[] cum) {
    double acc = 0;
    if (to > from) {
      cum[from] = 0;
    }
    for (int k = from + 1; k < to; k++) {
      acc += Math.hypot(xs[k] - xs[k - 1], ys[k] - ys[k - 1]);
      cum[k] = acc;
    }
  }

  /** The point at {@code offsetM} along the polyline, clamped to its ends. */
  static double[] pointAt(double[] xs, double[] ys, double offsetM) {
    if (offsetM <= 0) {
      return new double[] {xs[0], ys[0]};
    }
    double acc = 0;
    for (int i = 1; i < xs.length; i++) {
      double seg = Math.hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]);
      if (acc + seg >= offsetM) {
        double t = seg == 0 ? 0 : (offsetM - acc) / seg;
        return new double[] {
          xs[i - 1] + t * (xs[i] - xs[i - 1]), ys[i - 1] + t * (ys[i] - ys[i - 1])
        };
      }
      acc += seg;
    }
    return new double[] {xs[xs.length - 1], ys[ys.length - 1]};
  }

  static double pointSegmentDistance(
      double px, double py, double ax, double ay, double bx, double by) {
    return Math.hypot(px - nearestX(px, py, ax, ay, bx, by), py - nearestY(px, py, ax, ay, bx, by));
  }

  private static double segmentT(double px, double py, double ax, double ay, double bx, double by) {
    double dx = bx - ax;
    double dy = by - ay;
    double len2 = dx * dx + dy * dy;
    if (len2 == 0) {
      return 0;
    }
    double t = ((px - ax) * dx + (py - ay) * dy) / len2;
    return Math.max(0, Math.min(1, t));
  }

  private static double nearestX(double px, double py, double ax, double ay, double bx, double by) {
    return ax + segmentT(px, py, ax, ay, bx, by) * (bx - ax);
  }

  private static double nearestY(double px, double py, double ax, double ay, double bx, double by) {
    return ay + segmentT(px, py, ax, ay, bx, by) * (by - ay);
  }

  /** Nearest point of a polyline to {@code (px, py)}: distance and projected arc-length offset. */
  static Projection project(double px, double py, double[] xs, double[] ys) {
    double best = Double.POSITIVE_INFINITY;
    double bestAlong = 0;
    double bx = xs[0];
    double by = ys[0];
    double acc = 0;
    for (int i = 1; i < xs.length; i++) {
      double ax = xs[i - 1];
      double ay = ys[i - 1];
      double seg = Math.hypot(xs[i] - ax, ys[i] - ay);
      double t = segmentT(px, py, ax, ay, xs[i], ys[i]);
      double qx = ax + t * (xs[i] - ax);
      double qy = ay + t * (ys[i] - ay);
      double d = Math.hypot(px - qx, py - qy);
      if (d < best) {
        best = d;
        bestAlong = acc + t * seg;
        bx = qx;
        by = qy;
      }
      acc += seg;
    }
    return new Projection(best, bestAlong, bx, by);
  }

  /** Distance from a point to a polyline. */
  static double distanceToPolyline(double px, double py, double[] xs, double[] ys) {
    double best = Double.POSITIVE_INFINITY;
    for (int i = 1; i < xs.length; i++) {
      best = Math.min(best, pointSegmentDistance(px, py, xs[i - 1], ys[i - 1], xs[i], ys[i]));
    }
    return best;
  }

  /** {@code n >= 2} points at equal arc-length fractions, as {@code [x0, y0, x1, y1, ...]}. */
  static double[] resample(double[] xs, double[] ys, int n) {
    double len = polylineLength(xs, ys);
    double[] out = new double[2 * n];
    for (int i = 0; i < n; i++) {
      double[] p = pointAt(xs, ys, len * i / (n - 1));
      out[2 * i] = p[0];
      out[2 * i + 1] = p[1];
    }
    return out;
  }

  /**
   * Mean distance between the points of two polylines taken at the same arc-length offsets, from
   * the start, over {@code lengthM} metres.
   */
  static double meanDistanceOver(
      double[] ax, double[] ay, double[] bx, double[] by, double lengthM, int samples) {
    double sum = 0;
    for (int i = 0; i < samples; i++) {
      double off = lengthM * i / (samples - 1);
      double[] p = pointAt(ax, ay, off);
      double[] q = pointAt(bx, by, off);
      sum += Math.hypot(p[0] - q[0], p[1] - q[1]);
    }
    return sum / samples;
  }

  /**
   * Start and end headings of a polyline in its own direction (design §3.4): the bearing of the
   * segment between {@code near} and {@code far} metres from each end, which ignores the fine
   * drawing of a junction.
   */
  static double[] headings(double[] xs, double[] ys, double nearM, double farM) {
    double len = polylineLength(xs, ys);
    double far = Math.min(farM, len);
    double near = Math.min(nearM, far / 2);
    double[] a = pointAt(xs, ys, near);
    double[] b = pointAt(xs, ys, far);
    double start = headingOf(a, b, xs, ys);
    double[] c = pointAt(xs, ys, len - far);
    double[] d = pointAt(xs, ys, len - near);
    double end = headingOf(c, d, xs, ys);
    return new double[] {start, end};
  }

  private static double headingOf(double[] a, double[] b, double[] xs, double[] ys) {
    if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 0.5) {
      int last = xs.length - 1;
      return bearingDeg(xs[0], ys[0], xs[last], ys[last]);
    }
    return bearingDeg(a[0], a[1], b[0], b[1]);
  }

  /** Local direction of travel around {@code offsetM}, from a one metre window. */
  static double localBearing(double[] xs, double[] ys, double offsetM) {
    double[] a = pointAt(xs, ys, offsetM - 0.5);
    double[] b = pointAt(xs, ys, offsetM + 0.5);
    return bearingDeg(a[0], a[1], b[0], b[1]);
  }

  /** The part of a polyline between two arc-length offsets, ends interpolated. */
  static double[][] slice(double[] xs, double[] ys, double fromM, double toM) {
    double len = polylineLength(xs, ys);
    double from = Math.max(0, Math.min(len, fromM));
    double to = Math.max(from, Math.min(len, toM));
    int cap = xs.length + 2;
    double[] sx = new double[cap];
    double[] sy = new double[cap];
    int n = 0;
    double[] p = pointAt(xs, ys, from);
    sx[n] = p[0];
    sy[n++] = p[1];
    double acc = 0;
    for (int i = 1; i < xs.length; i++) {
      acc += Math.hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]);
      if (acc > from && acc < to) {
        sx[n] = xs[i];
        sy[n++] = ys[i];
      }
    }
    double[] q = pointAt(xs, ys, to);
    sx[n] = q[0];
    sy[n++] = q[1];
    return new double[][] {java.util.Arrays.copyOf(sx, n), java.util.Arrays.copyOf(sy, n)};
  }

  static double[] reversed(double[] a) {
    double[] r = new double[a.length];
    for (int i = 0; i < a.length; i++) {
      r[i] = a[a.length - 1 - i];
    }
    return r;
  }
}
