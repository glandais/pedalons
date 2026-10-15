package fr.pedalons.service.gpx;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.service.gpx.GpxTrackMerger.MergePlan;
import fr.pedalons.service.route.GpxLimits;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxPathKind;
import io.github.glandais.engine.gpx.GpxSegment;
import io.github.glandais.engine.gpx.GpxTrack;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.gpx.GpxWaypoint;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import org.junit.jupiter.api.Test;

/** Plain unit test of the GPX merge ordering (docs/LEDGER_*.md API-112). */
class GpxTrackMergerTest {

  /** About 1.1 km of longitude at the equator. */
  private static final double STEP = 0.01;

  /** A straight piece along the equator from longitude {@code from} to {@code to}, 3 points. */
  private static List<GpxTrackPoint> line(double from, double to) {
    double mid = (from + to) / 2;
    return List.of(
        GpxModelJvm.trackPoint(0.0, from, 10.0),
        GpxModelJvm.trackPoint(0.0, mid, 20.0),
        GpxModelJvm.trackPoint(0.0, to, 30.0));
  }

  private static GpxTrack track(List<GpxTrackPoint> points) {
    return GpxModelJvm.track(points, "t");
  }

  @SafeVarargs
  private static GpxDocument doc(List<GpxTrackPoint>... tracks) {
    List<GpxTrack> list = new ArrayList<>();
    for (List<GpxTrackPoint> points : tracks) {
      list.add(track(points));
    }
    return GpxModelJvm.document(list, "doc", List.of());
  }

  private static List<Double> longitudes(GpxDocument merged) {
    assertEquals(1, merged.getTracks().size());
    assertEquals(1, merged.getTracks().getFirst().getSegments().size());
    return merged.getTracks().getFirst().getPoints().stream()
        .map(GpxTrackPoint::getLongitudeDeg)
        .toList();
  }

  /** Longitudes compared within a rounding error: {@code (a + b) / 2} need not be exact. */
  private static void assertLongitudes(List<Double> expected, GpxDocument merged) {
    List<Double> actual = longitudes(merged);
    assertEquals(expected.size(), actual.size(), () -> "longitudes " + actual);
    for (int i = 0; i < expected.size(); i++) {
      assertEquals(expected.get(i), actual.get(i), 1e-12, "longitude " + i + " of " + actual);
    }
  }

  private static ErrorCode refusal(List<GpxDocument> docs) {
    BusinessException e =
        assertThrows(BusinessException.class, () -> GpxTrackMerger.merge(docs, "m"));
    return e.getErrorCode();
  }

  // ==================== Ordering ====================

  @Test
  void twoTracksAlreadyInOrder_comeOutUnchanged() {
    GpxDocument merged =
        GpxTrackMerger.merge(List.of(doc(line(0, STEP)), doc(line(STEP, 2 * STEP))), "m");

    // The shared point at the junction appears once.
    assertLongitudes(List.of(0.0, STEP / 2, STEP, 1.5 * STEP, 2 * STEP), merged);
    assertEquals("m", merged.getName());
    assertEquals("m", merged.getTracks().getFirst().getName());
  }

  @Test
  void tracksInReverseOrder_areReordered() {
    List<List<GpxTrackPoint>> pieces =
        List.of(line(2 * STEP, 3 * STEP), line(STEP, 2 * STEP), line(0, STEP));

    MergePlan plan = GpxTrackMerger.plan(pieces);

    // Piece 0 is pinned forward, so the chain is ridden 0 -> 3 STEP: 2, 1, 0 forward.
    assertEquals(List.of(2, 1, 0), plan.order());
    assertEquals(List.of(false, false, false), plan.reversed());
    assertEquals(0.0, plan.gapMeters(), 1e-6);
  }

  @Test
  void aTrackRecordedBackwards_isReversed() {
    GpxDocument merged =
        GpxTrackMerger.merge(List.of(doc(line(0, STEP)), doc(line(2 * STEP, STEP))), "m");

    assertLongitudes(List.of(0.0, STEP / 2, STEP, 1.5 * STEP, 2 * STEP), merged);
    // The elevation of each point travels with it.
    List<GpxTrackPoint> points = merged.getTracks().getFirst().getPoints();
    assertEquals(20.0, points.get(3).getElevationM());
    assertEquals(10.0, points.get(4).getElevationM());
  }

  @Test
  void theFirstTrack_isNeverReversed() {
    // The best chain is piece 1 then piece 0 forward, or its mirror; the mirror reverses piece 0.
    MergePlan plan = GpxTrackMerger.plan(List.of(line(STEP, 2 * STEP), line(0, STEP)));

    assertEquals(List.of(1, 0), plan.order());
    assertEquals(List.of(false, false), plan.reversed());
  }

  @Test
  void aGapBetweenTracks_staysAStraightLine() {
    GpxDocument merged =
        GpxTrackMerger.merge(List.of(doc(line(0, STEP)), doc(line(3 * STEP, 4 * STEP))), "m");

    assertLongitudes(List.of(0.0, STEP / 2, STEP, 3 * STEP, 3.5 * STEP, 4 * STEP), merged);
  }

  @Test
  void twoTracksInOneFile_areTwoPieces() {
    // One file holds both ends, the other the middle: per-file ordering could not interleave them.
    GpxDocument ends = doc(line(0, STEP), line(2 * STEP, 3 * STEP));
    GpxDocument middle = doc(line(2 * STEP, STEP));

    GpxDocument merged = GpxTrackMerger.merge(List.of(ends, middle), "m");

    assertLongitudes(
        List.of(0.0, STEP / 2, STEP, 1.5 * STEP, 2 * STEP, 2.5 * STEP, 3 * STEP), merged);
  }

  @Test
  void theSegmentsOfOneTrack_stayOnePiece() {
    GpxTrack twoSegments =
        new GpxTrack(
            "t",
            null,
            List.of(new GpxSegment(line(0, STEP)), new GpxSegment(line(STEP, 2 * STEP))),
            GpxPathKind.TRACK,
            null,
            null);
    GpxDocument first = GpxModelJvm.document(List.of(twoSegments), "a", List.of());

    assertEquals(1, GpxTrackMerger.pieces(List.of(first)).size());
    GpxDocument merged = GpxTrackMerger.merge(List.of(first, doc(line(3 * STEP, 2 * STEP))), "m");
    assertEquals(0.0, longitudes(merged).getFirst());
    assertEquals(3 * STEP, longitudes(merged).getLast(), 1e-12);
  }

  @Test
  void tenShuffledTracks_areChainedWithoutGap() {
    // Ten consecutive pieces of one ride, shuffled, every other one recorded backwards.
    int[] shuffled = {7, 2, 9, 0, 5, 3, 8, 1, 6, 4};
    List<GpxDocument> docs = new ArrayList<>();
    for (int i : shuffled) {
      docs.add(doc(i % 2 == 0 ? line(i * STEP, (i + 1) * STEP) : line((i + 1) * STEP, i * STEP)));
    }

    MergePlan plan = GpxTrackMerger.plan(GpxTrackMerger.pieces(docs));
    assertEquals(0.0, plan.gapMeters(), 1e-6);

    List<Double> lngs = longitudes(GpxTrackMerger.merge(docs, "m"));
    // 10 pieces of 3 points, 9 junction duplicates dropped.
    assertEquals(21, lngs.size());
    // Piece 0 is pinned forward: it is part 7 recorded backwards (8 -> 7), so the whole ride
    // goes down from 10 to 0.
    assertEquals(10 * STEP, lngs.getFirst(), 1e-12);
    assertEquals(0.0, lngs.getLast(), 1e-12);
    for (int i = 1; i < lngs.size(); i++) {
      assertTrue(lngs.get(i) < lngs.get(i - 1), "points must be decreasing at " + i);
    }
  }

  @Test
  void aSinglePointTrack_isAPieceOfItsOwn() {
    GpxDocument point = doc(List.of(GpxModelJvm.trackPoint(0.0, 5 * STEP, 0.0)));
    GpxDocument merged =
        GpxTrackMerger.merge(List.of(doc(line(0, STEP)), point, doc(line(2 * STEP, STEP))), "m");

    // The lone point is visited last, after the two lines chained end to end.
    assertLongitudes(List.of(0.0, STEP / 2, STEP, 1.5 * STEP, 2 * STEP, 5 * STEP), merged);
  }

  @Test
  void aTrackWithoutPoints_isIgnoredWhenTheFileHasOthers() {
    GpxDocument withEmpty = doc(List.of(), line(0, STEP));

    assertEquals(1, GpxTrackMerger.pieces(List.of(withEmpty)).size());
  }

  // ==================== Exhaustive check ====================

  @Test
  void theDynamicProgramme_matchesExhaustiveSearch() {
    Random random = new Random(42);
    for (int round = 0; round < 40; round++) {
      int n = 1 + random.nextInt(6);
      List<List<GpxTrackPoint>> pieces = new ArrayList<>();
      for (int i = 0; i < n; i++) {
        pieces.add(
            List.of(
                GpxModelJvm.trackPoint(random.nextDouble(), random.nextDouble()),
                GpxModelJvm.trackPoint(random.nextDouble(), random.nextDouble())));
      }

      MergePlan plan = GpxTrackMerger.plan(pieces);

      assertEquals(n, plan.order().size());
      assertEquals(n, plan.order().stream().distinct().count());
      assertEquals(
          GpxTrackMerger.gap(pieces, plan.order(), plan.reversed()), plan.gapMeters(), 1e-6);
      assertEquals(bruteForce(pieces), plan.gapMeters(), 0.01, "round " + round);
      assertFalse(plan.reversed().get(plan.order().indexOf(0)), "piece 0 forward");
    }
  }

  private static double bruteForce(List<List<GpxTrackPoint>> pieces) {
    int n = pieces.size();
    double[] best = {Double.POSITIVE_INFINITY};
    permute(pieces, new ArrayList<>(), new boolean[n], best);
    return best[0];
  }

  private static void permute(
      List<List<GpxTrackPoint>> pieces, List<Integer> order, boolean[] used, double[] best) {
    int n = pieces.size();
    if (order.size() == n) {
      for (int mask = 0; mask < (1 << n); mask++) {
        List<Boolean> reversed = new ArrayList<>();
        for (int i = 0; i < n; i++) {
          reversed.add((mask & (1 << i)) != 0);
        }
        best[0] = Math.min(best[0], GpxTrackMerger.gap(pieces, order, reversed));
      }
      return;
    }
    for (int i = 0; i < n; i++) {
      if (!used[i]) {
        used[i] = true;
        order.add(i);
        permute(pieces, order, used, best);
        order.removeLast();
        used[i] = false;
      }
    }
  }

  // ==================== Waypoints ====================

  @Test
  void waypoints_areTheUnionWithoutExactDuplicates() {
    GpxWaypoint cafe = GpxModelJvm.waypoint(0.0, 0.0, null, "Café");
    GpxWaypoint cafeAgain = GpxModelJvm.waypoint(0.0, 0.0, null, "Café");
    GpxWaypoint col = GpxModelJvm.waypoint(0.0, STEP, null, "Col");
    GpxDocument a = GpxModelJvm.document(List.of(track(line(0, STEP))), "a", List.of(cafe));
    GpxDocument b =
        GpxModelJvm.document(List.of(track(line(STEP, 2 * STEP))), "b", List.of(cafeAgain, col));

    List<GpxWaypoint> waypoints = GpxTrackMerger.merge(List.of(a, b), "m").getWaypoints();

    assertEquals(List.of("Café", "Col"), waypoints.stream().map(GpxWaypoint::getName).toList());
  }

  // ==================== Refusals ====================

  @Test
  void aFileWithoutAnyPoint_isRefused() {
    assertEquals(
        ErrorCode.GPX_EMPTY,
        refusal(List.of(doc(line(0, STEP)), GpxModelJvm.document(List.of(), "e", List.of()))));
    assertEquals(ErrorCode.GPX_EMPTY, refusal(List.of(doc(line(0, STEP)), doc(List.of()))));
  }

  @Test
  void moreTracksThanTheBound_isRefused() {
    List<GpxDocument> docs = new ArrayList<>();
    for (int i = 0; i <= GpxLimits.MAX_MERGE_TRACKS; i++) {
      docs.add(doc(line(i * STEP, (i + 1) * STEP)));
    }

    assertEquals(ErrorCode.GPX_MERGE_TOO_MANY_TRACKS, refusal(docs));
  }

  @Test
  void exactlyTheBound_isAccepted() {
    List<GpxDocument> docs = new ArrayList<>();
    for (int i = GpxLimits.MAX_MERGE_TRACKS - 1; i >= 0; i--) {
      docs.add(doc(line(i * STEP, (i + 1) * STEP)));
    }

    MergePlan plan = GpxTrackMerger.plan(GpxTrackMerger.pieces(docs));

    assertEquals(GpxLimits.MAX_MERGE_TRACKS, plan.order().size());
    assertEquals(0.0, plan.gapMeters(), 1e-6);
  }
}
