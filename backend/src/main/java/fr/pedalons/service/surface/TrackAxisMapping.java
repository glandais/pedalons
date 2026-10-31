package fr.pedalons.service.surface;

/**
 * Carries distances along the line sent to the provider onto the axis of the stored track points
 * (docs/LEDGER_*.md API-147, phase B): the surface is matched on the raw line of a track, but the
 * stored document stays on the distances of {@code track_points}, which the clients read.
 *
 * <p>The sent line is walked from its start, a station at each of its vertices and at least every
 * {@link #STEP_M}, and each station is located on the track points with a forward-only
 * nearest-segment search; the distances asked for are read off that walk. Never a proportional
 * rescale on the total length, which a GPS jitter (a raw line tens of metres longer, in one place)
 * would shift everywhere after it, and never a jump between two far stations: the search starts
 * where the previous station landed and looks only a little further than the walk advanced, so a
 * route that comes back along itself (an out-and-back, a spur, hairpins) is not caught by the wrong
 * leg, whatever length a stop or a jitter added to the raw line before. Between two candidates the
 * nearer to where the step leads wins. Pure.
 *
 * <p>Also cuts an imported piece of a planner state out of the raw track of its source, the other
 * way round: from the simplified source line onto the raw one (API-147, phase C, {@code
 * PlannerStates}).
 */
public final class TrackAxisMapping {

  /** The longest step of the walk along the sent line, between two of its vertices. */
  static final double STEP_M = 20;

  /** How much further than the walk advanced the search looks on the track. */
  private static final double WINDOW_SLACK = 1.5;

  /** Plus this, in metres: the room the stored points need where they cut a corner. */
  private static final double WINDOW_MARGIN_M = 200;

  /**
   * Weight of the gap between a candidate and where the step leads, against its distance from the
   * station: two legs of an out-and-back are equally near, not equally far along.
   */
  private static final double ALONG_WEIGHT = 0.5;

  private static final double M_PER_DEGREE = Math.PI / 180 * 6_371_008.8;

  private TrackAxisMapping() {}

  /**
   * @param fromLat latitudes of the sent line
   * @param fromLon longitudes of the sent line
   * @param fromDist cumulative distances along the sent line, from 0
   * @param toLat latitudes of the track points
   * @param toLon longitudes of the track points
   * @param toDist the stored distances of the track points, from 0
   * @param sorted distances along the sent line, ascending
   * @return the distance of each on the track points, ascending, within {@code [0, last toDist]}:
   *     0 maps on 0 and the end of the sent line on the end of the track
   */
  public static double[] map(
      double[] fromLat,
      double[] fromLon,
      double[] fromDist,
      double[] toLat,
      double[] toLon,
      double[] toDist,
      double[] sorted) {
    int n = toDist.length;
    double fromLength = fromDist[fromDist.length - 1];
    double toLength = toDist[n - 1];
    double[] out = new double[sorted.length];
    int segment = 0;
    double cursor = 0;
    double previous = 0;
    int vertex = 1;
    int b = 0;
    while (b < sorted.length) {
      double d = sorted[b];
      if (d <= 0) {
        out[b++] = 0;
        continue;
      }
      if (d >= fromLength || n < 2) {
        out[b++] = toLength;
        continue;
      }
      if (d <= previous) {
        out[b++] = cursor;
        continue;
      }
      // The next station: the distance asked for, the next vertex or a step on, the nearest
      while (vertex < fromDist.length && fromDist[vertex] <= previous) {
        vertex++;
      }
      double station = Math.min(d, previous + STEP_M);
      if (vertex < fromDist.length) {
        station = Math.min(station, fromDist[vertex]);
      }
      int k = segmentAt(fromDist, station);
      double span = fromDist[k + 1] - fromDist[k];
      double t = span > 0 ? (station - fromDist[k]) / span : 0;
      double lat = fromLat[k] + t * (fromLat[k + 1] - fromLat[k]);
      double lon = fromLon[k] + t * (fromLon[k + 1] - fromLon[k]);

      double advance = station - previous;
      double expected = cursor + advance;
      double limit = cursor + advance * WINDOW_SLACK + WINDOW_MARGIN_M;
      double cos = Math.cos(Math.toRadians(lat));
      double bestScore = Double.POSITIVE_INFINITY;
      double bestAlong = cursor;
      int bestSegment = segment;
      for (int s = segment; s < n - 1 && (s == segment || toDist[s] <= limit); s++) {
        // Local plane around the station, in metres
        double ax = (toLon[s] - lon) * cos * M_PER_DEGREE;
        double ay = (toLat[s] - lat) * M_PER_DEGREE;
        double bx = (toLon[s + 1] - lon) * cos * M_PER_DEGREE;
        double by = (toLat[s + 1] - lat) * M_PER_DEGREE;
        double ex = bx - ax;
        double ey = by - ay;
        double sq = ex * ex + ey * ey;
        double u = sq > 0 ? Math.clamp(-(ax * ex + ay * ey) / sq, 0.0, 1.0) : 0;
        double px = ax + u * ex;
        double py = ay + u * ey;
        double perp = Math.sqrt(px * px + py * py);
        double along = Math.max(cursor, toDist[s] + u * (toDist[s + 1] - toDist[s]));
        double score = perp + ALONG_WEIGHT * Math.abs(along - expected);
        if (score < bestScore) {
          bestScore = score;
          bestAlong = along;
          bestSegment = s;
        }
      }
      cursor = Math.min(bestAlong, toLength);
      segment = bestSegment;
      previous = station;
      if (station == d) {
        out[b++] = cursor;
      }
    }
    return out;
  }

  /** The index {@code k} of the segment {@code [k, k + 1]} that holds {@code d}. */
  private static int segmentAt(double[] dist, double d) {
    int lo = 0;
    int hi = dist.length - 2;
    while (lo < hi) {
      int mid = (lo + hi + 1) >>> 1;
      if (dist[mid] <= d) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}
