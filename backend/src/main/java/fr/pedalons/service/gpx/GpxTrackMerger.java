package fr.pedalons.service.gpx;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.service.route.GpxLimits;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxTrack;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.gpx.GpxWaypoint;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Merges the tracks of several GPX documents into one track, choosing the order of the tracks
 * <em>and</em> the direction each one is ridden in so that the summed gaps — straight lines from
 * the end of a track to the start of the next — are as short as possible (docs/LEDGER_*.md
 * API-112).
 *
 * <p><b>Pieces.</b> Every {@code trk} or {@code rte} holding at least one point is one piece, in
 * file order then track order; the {@code trkseg} of one {@code trk} stay together in their order,
 * as the pipeline already reads them ({@code GpxToPathJvm.tracksAsPaths}). A file may hold several
 * disjoint tracks, so ordering per track rather than per file finds the better chain; tracks
 * already end to end come out in their order. A document with no point at all is refused with
 * {@code GPX_EMPTY}, rather than silently dropped from a merge the member asked for.
 *
 * <p><b>Exact ordering.</b> A dynamic programme over (set of pieces used, last piece, its
 * direction), in O(2<sup>n</sup>·n²) — exact, unlike a nearest-neighbour heuristic, and cheap up to
 * {@link GpxLimits#MAX_MERGE_TRACKS} pieces. Riding a whole chain backwards costs the same, so
 * piece 0 is pinned forward; ties (within a millimetre) go to the lowest index and the forward
 * direction, so files already in order and direction come out unchanged.
 *
 * <p><b>Output.</b> One track, one segment: the pieces' points concatenated, reversed for a piece
 * ridden backwards. A gap under {@link #JOIN_TOLERANCE_METERS} drops the next piece's first point
 * (the same place twice); a longer one stays a straight line that the pipeline resamples and counts
 * in the distance. Waypoints are the union of all files, in file order, exact duplicates dropped.
 * Timestamps need no care: the pipeline's {@code GpxSanitizer} drops them anyway.
 *
 * <p>Pure and stateless: no CDI, unit-tested by {@code GpxTrackMergerTest}.
 */
public final class GpxTrackMerger {

  /** Below this gap, the end of a piece and the start of the next are the same place. */
  static final double JOIN_TOLERANCE_METERS = 1.0;

  /** Two chains whose gaps differ by less than this cost the same (tie-break, rounding). */
  private static final double COST_EPSILON_METERS = 0.001;

  private GpxTrackMerger() {}

  /**
   * The order and directions chosen for the pieces.
   *
   * @param order piece indexes, in riding order
   * @param reversed for each entry of {@code order}, whether that piece is ridden backwards
   * @param gapMeters the summed straight-line gaps between consecutive pieces
   */
  public record MergePlan(List<Integer> order, List<Boolean> reversed, double gapMeters) {}

  /**
   * One document with a single track merging every track of {@code docs}, named {@code name}.
   *
   * @throws BusinessException {@code GPX_EMPTY} when one of the documents holds no point, {@code
   *     GPX_MERGE_TOO_MANY_TRACKS} past {@link GpxLimits#MAX_MERGE_TRACKS} pieces
   */
  public static GpxDocument merge(List<GpxDocument> docs, String name) {
    List<List<GpxTrackPoint>> pieces = pieces(docs);
    MergePlan plan = plan(pieces);
    List<GpxTrackPoint> points = new ArrayList<>();
    for (int i = 0; i < plan.order().size(); i++) {
      List<GpxTrackPoint> piece = pieces.get(plan.order().get(i));
      List<GpxTrackPoint> oriented = plan.reversed().get(i) ? piece.reversed() : piece;
      int from = 0;
      if (!points.isEmpty()
          && distance(points.getLast(), oriented.getFirst()) < JOIN_TOLERANCE_METERS) {
        from = 1;
      }
      points.addAll(oriented.subList(from, oriented.size()));
    }
    GpxTrack track = GpxModelJvm.track(points, name);
    return GpxModelJvm.document(List.of(track), name, waypoints(docs));
  }

  /**
   * The pieces of {@code docs}: one per track holding at least one point, in file then track order.
   */
  static List<List<GpxTrackPoint>> pieces(List<GpxDocument> docs) {
    List<List<GpxTrackPoint>> pieces = new ArrayList<>();
    for (GpxDocument doc : docs) {
      int before = pieces.size();
      for (GpxTrack track : doc.getTracks()) {
        List<GpxTrackPoint> points = track.getPoints();
        if (!points.isEmpty()) {
          pieces.add(points);
          if (pieces.size() > GpxLimits.MAX_MERGE_TRACKS) {
            throw new BusinessException(ErrorCode.GPX_MERGE_TOO_MANY_TRACKS);
          }
        }
      }
      if (pieces.size() == before) {
        throw new BusinessException(ErrorCode.GPX_EMPTY);
      }
    }
    return pieces;
  }

  /**
   * The order and directions of {@code pieces} minimising the summed gaps, piece 0 forward.
   * Every piece must hold at least one point.
   */
  public static MergePlan plan(List<List<GpxTrackPoint>> pieces) {
    int n = pieces.size();
    if (n == 0) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    if (n > GpxLimits.MAX_MERGE_TRACKS) {
      throw new BusinessException(ErrorCode.GPX_MERGE_TOO_MANY_TRACKS);
    }
    // Node 2j+o is piece j in direction o (0 forward, 1 backward). Its entry point is its start
    // when forward, its end when backward; its exit point the other one.
    int nodes = 2 * n;
    double[][] gap = new double[nodes][nodes];
    for (int a = 0; a < nodes; a++) {
      GpxTrackPoint exit = exitPoint(pieces, a);
      for (int b = 0; b < nodes; b++) {
        gap[a][b] = distance(exit, entryPoint(pieces, b));
      }
    }

    int states = 1 << n;
    double[] cost = new double[states * nodes];
    int[] parent = new int[states * nodes];
    Arrays.fill(cost, Double.POSITIVE_INFINITY);
    Arrays.fill(parent, -1);
    for (int j = 0; j < n; j++) {
      for (int o = 0; o < 2; o++) {
        if (j == 0 && o == 1) {
          continue; // A chain and its reverse cost the same: piece 0 is pinned forward.
        }
        cost[(1 << j) * nodes + 2 * j + o] = 0.0;
      }
    }
    for (int mask = 1; mask < states; mask++) {
      for (int last = 0; last < nodes; last++) {
        double base = cost[mask * nodes + last];
        if (base == Double.POSITIVE_INFINITY) {
          continue;
        }
        for (int k = 0; k < n; k++) {
          if ((mask & (1 << k)) != 0) {
            continue;
          }
          int nextMask = mask | (1 << k);
          for (int p = 0; p < 2; p++) {
            if (k == 0 && p == 1) {
              continue;
            }
            int next = 2 * k + p;
            double candidate = base + gap[last][next];
            int index = nextMask * nodes + next;
            // Strictly better only: masks and nodes are visited in increasing order, so a tie
            // keeps the lowest predecessor.
            if (candidate < cost[index] - COST_EPSILON_METERS) {
              cost[index] = candidate;
              parent[index] = last;
            }
          }
        }
      }
    }

    int full = states - 1;
    int best = -1;
    double bestCost = Double.POSITIVE_INFINITY;
    for (int last = 0; last < nodes; last++) {
      double c = cost[full * nodes + last];
      if (c < bestCost - COST_EPSILON_METERS) {
        bestCost = c;
        best = last;
      }
    }

    Integer[] order = new Integer[n];
    Boolean[] reversed = new Boolean[n];
    int mask = full;
    int node = best;
    for (int i = n - 1; i >= 0; i--) {
      order[i] = node / 2;
      reversed[i] = node % 2 == 1;
      int previous = parent[mask * nodes + node];
      mask &= ~(1 << (node / 2));
      node = previous;
    }
    return new MergePlan(List.of(order), List.of(reversed), bestCost);
  }

  /** The summed gaps of riding {@code pieces} in {@code order}, with directions {@code reversed}. */
  static double gap(List<List<GpxTrackPoint>> pieces, List<Integer> order, List<Boolean> reversed) {
    double total = 0.0;
    for (int i = 1; i < order.size(); i++) {
      int from = 2 * order.get(i - 1) + (reversed.get(i - 1) ? 1 : 0);
      int to = 2 * order.get(i) + (reversed.get(i) ? 1 : 0);
      total += distance(exitPoint(pieces, from), entryPoint(pieces, to));
    }
    return total;
  }

  private static GpxTrackPoint entryPoint(List<List<GpxTrackPoint>> pieces, int node) {
    List<GpxTrackPoint> piece = pieces.get(node / 2);
    return node % 2 == 0 ? piece.getFirst() : piece.getLast();
  }

  private static GpxTrackPoint exitPoint(List<List<GpxTrackPoint>> pieces, int node) {
    List<GpxTrackPoint> piece = pieces.get(node / 2);
    return node % 2 == 0 ? piece.getLast() : piece.getFirst();
  }

  private static double distance(GpxTrackPoint a, GpxTrackPoint b) {
    return GeoDistance.haversineMeters(
        a.getLatitudeDeg(), a.getLongitudeDeg(), b.getLatitudeDeg(), b.getLongitudeDeg());
  }

  private record WaypointKey(double lat, double lng, String name) {}

  private static List<GpxWaypoint> waypoints(List<GpxDocument> docs) {
    Set<WaypointKey> seen = new LinkedHashSet<>();
    List<GpxWaypoint> waypoints = new ArrayList<>();
    for (GpxDocument doc : docs) {
      for (GpxWaypoint w : doc.getWaypoints()) {
        if (seen.add(new WaypointKey(w.getLatitudeDeg(), w.getLongitudeDeg(), w.getName()))) {
          waypoints.add(w);
        }
      }
    }
    return waypoints;
  }
}
