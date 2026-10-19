package fr.pedalons.service.router;

import fr.pedalons.common.planner.UnpavedSpan;
import java.util.ArrayList;
import java.util.List;

/**
 * Carries the unpaved ("rough") maneuvers of a Valhalla route onto the points the GPX pipeline
 * outputs (docs/LEDGER_*.md WEB-100, C1a). The pipeline resamples and simplifies, so the shape
 * indices of the maneuvers mean nothing on the output: the ranges travel by distance along the
 * line, the output distance being rescaled to the raw one ({@code L_raw / L_out}) so that both
 * lines end together whatever the simplification did to the length.
 */
final class UnpavedSpans {

  /** Overlap (m) with a rough range from which an output edge counts as unpaved. */
  private static final double OVERLAP_M = 5;

  private static final double EARTH_RADIUS_M = 6_371_008.8;

  private UnpavedSpans() {}

  /**
   * The runs of unpaved edges of the output line.
   *
   * @param raw the raw shape, [lon, lat] pairs
   * @param roughRanges the rough maneuvers as [begin, end] indices into {@code raw}, in any order
   * @param outLon longitudes of the output points
   * @param outLat latitudes of the output points
   * @return half-open runs of edge indices (edge {@code i} joins output points {@code i} and {@code
   *     i + 1}), ascending and non-adjacent; empty when no edge is unpaved
   */
  static List<UnpavedSpan> project(
      List<double[]> raw, List<int[]> roughRanges, double[] outLon, double[] outLat) {
    int n = outLon.length;
    if (roughRanges.isEmpty() || n < 2 || raw.size() < 2) {
      return List.of();
    }
    double[] rawDist = cumulative(raw.size(), i -> raw.get(i)[0], i -> raw.get(i)[1]);
    double[] outDist = cumulative(n, i -> outLon[i], i -> outLat[i]);
    double rawLength = rawDist[rawDist.length - 1];
    double outLength = outDist[n - 1];
    if (!(rawLength > 0) || !(outLength > 0)) {
      return List.of();
    }
    double scale = rawLength / outLength;

    // Rough ranges in metres along the raw line, sorted, overlapping or touching ones merged.
    List<double[]> ranges = new ArrayList<>();
    for (int[] r : roughRanges) {
      int begin = Math.max(0, r[0]);
      int end = Math.min(raw.size() - 1, r[1]);
      if (end > begin) {
        ranges.add(new double[] {rawDist[begin], rawDist[end]});
      }
    }
    ranges.sort((a, b) -> Double.compare(a[0], b[0]));
    List<double[]> merged = new ArrayList<>();
    for (double[] r : ranges) {
      double[] last = merged.isEmpty() ? null : merged.getLast();
      if (last != null && r[0] <= last[1]) {
        last[1] = Math.max(last[1], r[1]);
      } else {
        merged.add(new double[] {r[0], r[1]});
      }
    }

    // An edge is unpaved when a rough range overlaps it by more than OVERLAP_M (or by half of it,
    // for a shorter edge), on the raw scale: like `rough` itself, this errs towards over-reporting,
    // so a short unpaved run that lies inside a long output edge (no bend, so no vertex kept) is
    // never dropped; the margin only absorbs the rounding where a range ends on a vertex.
    List<UnpavedSpan> spans = new ArrayList<>();
    int run = -1;
    int k = 0;
    for (int e = 0; e < n - 1; e++) {
      double start = outDist[e] * scale;
      double end = outDist[e + 1] * scale;
      while (k < merged.size() && merged.get(k)[1] <= start) {
        k++;
      }
      double overlap = 0;
      for (int m = k; m < merged.size() && merged.get(m)[0] < end; m++) {
        overlap += Math.min(end, merged.get(m)[1]) - Math.max(start, merged.get(m)[0]);
      }
      boolean rough = overlap > Math.min(OVERLAP_M, (end - start) / 2);
      if (rough && run < 0) {
        run = e;
      } else if (!rough && run >= 0) {
        spans.add(new UnpavedSpan(run, e));
        run = -1;
      }
    }
    if (run >= 0) {
      spans.add(new UnpavedSpan(run, n - 1));
    }
    return spans;
  }

  private static double[] cumulative(
      int n,
      java.util.function.IntToDoubleFunction lon,
      java.util.function.IntToDoubleFunction lat) {
    double[] d = new double[n];
    for (int i = 1; i < n; i++) {
      d[i] =
          d[i - 1]
              + haversine(
                  lon.applyAsDouble(i - 1),
                  lat.applyAsDouble(i - 1),
                  lon.applyAsDouble(i),
                  lat.applyAsDouble(i));
    }
    return d;
  }

  private static double haversine(double lon1, double lat1, double lon2, double lat2) {
    double p1 = Math.toRadians(lat1);
    double p2 = Math.toRadians(lat2);
    double dp = p2 - p1;
    double dl = Math.toRadians(lon2 - lon1);
    double a =
        Math.sin(dp / 2) * Math.sin(dp / 2)
            + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) * Math.sin(dl / 2);
    return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1.0, Math.sqrt(a)));
  }
}
