package fr.pedalons.service.gpx;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.service.route.GpxLimits;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxSegmentOrderJvm;
import io.github.glandais.engine.gpx.GpxTrack;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.gpx.GpxWaypoint;
import io.github.glandais.engine.gpx.SegmentOrderPlan;
import java.util.ArrayList;
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
 * as the pipeline already reads them ({@code GpxToPathJvm.tracksAsPaths}), once vcyclist's
 * {@code GpxSegmentOrderJvm.withOrderedSegments} has put segments written out of order back end to end (API-195). A file may hold several
 * disjoint tracks, so ordering per track rather than per file finds the better chain; tracks
 * already end to end come out in their order. A document with no point at all is refused with
 * {@code GPX_EMPTY}, rather than silently dropped from a merge the member asked for.
 *
 * <p><b>Exact ordering.</b> vcyclist's planner ({@code GpxSegmentOrderJvm.plan}): a dynamic
 * programme over (set of pieces used, last piece, its
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
      // A track's segments are put back end to end first (API-195): a piece is a track.
      for (GpxTrack track : GpxSegmentOrderJvm.withOrderedSegments(doc).getTracks()) {
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
   * The order and directions of {@code pieces} minimising the summed gaps, piece 0 forward —
   * vcyclist's exact planner ({@code GpxSegmentOrderJvm.plan}, the one that also reorders the
   * segments of a track, API-195). Every piece must hold at least one point.
   */
  public static MergePlan plan(List<List<GpxTrackPoint>> pieces) {
    if (pieces.isEmpty()) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    if (pieces.size() > GpxLimits.MAX_MERGE_TRACKS) {
      throw new BusinessException(ErrorCode.GPX_MERGE_TOO_MANY_TRACKS);
    }
    SegmentOrderPlan plan = GpxSegmentOrderJvm.plan(pieces, GpxLimits.MAX_MERGE_TRACKS);
    return new MergePlan(
        List.copyOf(plan.getOrder()), List.copyOf(plan.getReversed()), plan.getGapM());
  }

  /** The summed gaps of riding {@code pieces} in {@code order}, with directions {@code reversed}. */
  static double gap(List<List<GpxTrackPoint>> pieces, List<Integer> order, List<Boolean> reversed) {
    return GpxSegmentOrderJvm.gapM(pieces, order, reversed);
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
