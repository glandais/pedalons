package fr.pedalons.service.router;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.planner.UnpavedSpan;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** docs/LEDGER_*.md WEB-100 (C1a): rough maneuver ranges carried onto the pipeline's points. */
class UnpavedSpansTest {

  /** 11 raw points along a parallel, 0.001 degree (about 78 m) apart: indices 0..10. */
  private static List<double[]> raw() {
    List<double[]> raw = new ArrayList<>();
    for (int i = 0; i <= 10; i++) {
      raw.add(new double[] {4.83 + 0.001 * i, 45.76});
    }
    return raw;
  }

  /** The same line resampled to {@code n} points, as the pipeline would. */
  private static double[] lons(int n) {
    double[] lon = new double[n];
    for (int i = 0; i < n; i++) {
      lon[i] = 4.83 + 0.010 * i / (n - 1);
    }
    return lon;
  }

  private static double[] lats(int n) {
    double[] lat = new double[n];
    java.util.Arrays.fill(lat, 45.76);
    return lat;
  }

  @Test
  void aRangeOfTheRawLineLandsOnTheSameStretchOfTheOutput() {
    // Raw indices 2..6 are 20 % to 60 % of the line; the output has 21 points, 20 edges.
    List<UnpavedSpan> spans =
        UnpavedSpans.project(raw(), List.<int[]>of(new int[] {2, 6}), lons(21), lats(21));

    assertEquals(List.of(new UnpavedSpan(4, 12)), spans);
  }

  @Test
  void aShorterOutputIsRescaledToTheRawLength() {
    // The pipeline cut a corner: the output covers only 90 % of the raw length, the ranges still
    // end together with the line.
    int n = 21;
    double[] lon = new double[n];
    for (int i = 0; i < n; i++) {
      lon[i] = 4.83 + 0.009 * i / (n - 1);
    }
    List<UnpavedSpan> spans =
        UnpavedSpans.project(raw(), List.<int[]>of(new int[] {5, 10}), lon, lats(n));

    // The last 50 % of the raw length is the last 10 edges of 20, whatever the output length.
    assertEquals(List.of(new UnpavedSpan(10, 20)), spans);
  }

  @Test
  void overlappingAndTouchingRangesFormOneRun() {
    List<UnpavedSpan> spans =
        UnpavedSpans.project(
            raw(),
            List.of(new int[] {5, 8}, new int[] {1, 3}, new int[] {3, 5}),
            lons(21),
            lats(21));

    assertEquals(List.of(new UnpavedSpan(2, 16)), spans);
  }

  @Test
  void separateRangesStaySeparate() {
    List<UnpavedSpan> spans =
        UnpavedSpans.project(
            raw(), List.of(new int[] {0, 2}, new int[] {6, 8}), lons(21), lats(21));

    assertEquals(2, spans.size());
    assertEquals(0, spans.get(0).from());
    assertTrue(spans.get(0).to() < spans.get(1).from());
    assertEquals(16, spans.get(1).to());
  }

  @Test
  void noRoughRangeIsAnEmptyList() {
    assertTrue(UnpavedSpans.project(raw(), List.of(), lons(21), lats(21)).isEmpty());
  }

  @Test
  void outOfRangeIndicesAreClamped() {
    List<UnpavedSpan> spans =
        UnpavedSpans.project(raw(), List.<int[]>of(new int[] {8, 99}), lons(21), lats(21));

    assertEquals(List.of(new UnpavedSpan(16, 20)), spans);
  }

  @Test
  void emptyAndReversedRangesAreIgnored() {
    List<UnpavedSpan> spans =
        UnpavedSpans.project(
            raw(), List.of(new int[] {4, 4}, new int[] {7, 3}), lons(21), lats(21));

    assertTrue(spans.isEmpty());
  }

  @Test
  void aShortRunInsideALongOutputEdgeIsNotDropped() {
    // The pipeline kept only the ends of the straight line (one edge of about 780 m); the rough
    // maneuver covers 20 % of it (raw indices 4..6), well under the edge's midpoint.
    double[] lon = {4.83, 4.84};
    double[] lat = {45.76, 45.76};
    List<UnpavedSpan> spans =
        UnpavedSpans.project(raw(), List.<int[]>of(new int[] {7, 8}), lon, lat);

    assertEquals(List.of(new UnpavedSpan(0, 1)), spans);
  }

  @Test
  void aRangeEndingOnAVertexDoesNotSpillOnTheNextEdge() {
    List<UnpavedSpan> spans =
        UnpavedSpans.project(raw(), List.<int[]>of(new int[] {2, 6}), lons(11), lats(11));

    assertEquals(List.of(new UnpavedSpan(2, 6)), spans);
  }
}
