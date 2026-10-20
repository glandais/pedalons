package fr.pedalons.service.route.waypoint;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * Places waypoints on a track, and places them again when the track changes (docs/LEDGER_*.md
 * WEB-100, C3c; research §11.3). Pure.
 *
 * <p>A waypoint is {@linkplain #SNAP_RADIUS_M on the track} when some segment passes within 50 m
 * of it; its distance is then the interpolation of the stored distances of that segment, so it is
 * exactly on the axis of the profile and of the FIT. A route that goes out and comes back passes
 * twice near a point: the candidates are grouped in <i>passages</i> (two candidates less than
 * {@link #PASSAGE_GAP_M} apart along the track are one passage, whether a shared vertex or the
 * bottom of a U-turn), and the passage is chosen by the hint the point carries (the nearest to its
 * previous distance), else the first.
 */
public final class WaypointAnchoring {

  /** W4: how far from the track a waypoint still counts as on it. */
  public static final double SNAP_RADIUS_M = 50;

  /** Two candidates closer than this along the track are one passage. */
  public static final double PASSAGE_GAP_M = 2 * SNAP_RADIUS_M;

  private static final double EARTH_RADIUS_M = 6_371_008.8;
  private static final double M_PER_DEGREE = Math.PI / 180 * EARTH_RADIUS_M;

  /** Squared length (m²) under which a segment is a point. */
  private static final double MIN_SEGMENT_SQ = 1e-6;

  private WaypointAnchoring() {}

  /** One segment within the radius: where along the axis, and how far from the point. */
  private record Candidate(double along, double perp) {}

  /** The drafts placed on {@code axis}, in the order of the drafts. */
  public static List<AnchoredWaypoint> anchor(TrackAxis axis, List<WaypointDraft> drafts) {
    List<AnchoredWaypoint> result = new ArrayList<>(drafts.size());
    for (WaypointDraft draft : drafts) {
      result.add(
          new AnchoredWaypoint(
              draft.id(),
              draft.lat(),
              draft.lng(),
              draft.name(),
              draft.description(),
              draft.type(),
              draft.origin(),
              locate(axis, draft)));
    }
    return result;
  }

  private static @Nullable Double locate(TrackAxis axis, WaypointDraft draft) {
    List<Candidate> candidates = candidates(axis, draft.lat(), draft.lng());
    if (candidates.isEmpty()) {
      return null;
    }
    candidates.sort(Comparator.comparingDouble(Candidate::along));
    List<Candidate> passages = passages(candidates);
    Double target = target(axis, draft);
    Candidate chosen = passages.getFirst();
    if (target != null) {
      double bestGap = Math.abs(chosen.along() - target);
      for (Candidate passage : passages) {
        double gap = Math.abs(passage.along() - target);
        if (gap < bestGap || (gap == bestGap && passage.perp() < chosen.perp())) {
          chosen = passage;
          bestGap = gap;
        }
      }
    }
    return chosen.along();
  }

  /** The distance the hint asks for, rescaled onto this axis when the previous length is known. */
  private static @Nullable Double target(TrackAxis axis, WaypointDraft draft) {
    Double previous = draft.previousDistance();
    if (previous == null) {
      return null;
    }
    Double previousTotal = draft.previousTotal();
    if (previousTotal != null && previousTotal > 0) {
      return previous * axis.total() / previousTotal;
    }
    return previous;
  }

  /** The closest candidate of each run of candidates less than a passage gap apart. */
  private static List<Candidate> passages(List<Candidate> sortedByAlong) {
    List<Candidate> passages = new ArrayList<>();
    Candidate best = sortedByAlong.getFirst();
    double last = best.along();
    for (int i = 1; i < sortedByAlong.size(); i++) {
      Candidate next = sortedByAlong.get(i);
      if (next.along() - last >= PASSAGE_GAP_M) {
        passages.add(best);
        best = next;
      } else if (next.perp() < best.perp()) {
        best = next;
      }
      last = next.along();
    }
    passages.add(best);
    return passages;
  }

  private static List<Candidate> candidates(TrackAxis axis, double pLat, double pLng) {
    double cos = Math.cos(Math.toRadians(pLat));
    double marginLat = (SNAP_RADIUS_M * 1.1) / M_PER_DEGREE;
    double marginLng = cos < 1e-9 ? 360 : marginLat / cos;
    double minLat = pLat - marginLat;
    double maxLat = pLat + marginLat;
    double minLng = pLng - marginLng;
    double maxLng = pLng + marginLng;
    List<Candidate> candidates = new ArrayList<>();
    for (TrackAxis.Segmented track : axis.tracks()) {
      double[] lat = track.lat();
      double[] lng = track.lng();
      double[] dist = track.dist();
      if (lat.length == 1) {
        addSegment(candidates, track, 0, 0, pLat, pLng, cos);
        continue;
      }
      for (int i = 0; i + 1 < lat.length; i++) {
        if ((lat[i] < minLat && lat[i + 1] < minLat)
            || (lat[i] > maxLat && lat[i + 1] > maxLat)
            || (lng[i] < minLng && lng[i + 1] < minLng)
            || (lng[i] > maxLng && lng[i + 1] > maxLng)) {
          continue;
        }
        addSegment(candidates, track, i, i + 1, pLat, pLng, cos);
      }
    }
    return candidates;
  }

  private static void addSegment(
      List<Candidate> out,
      TrackAxis.Segmented track,
      int a,
      int b,
      double pLat,
      double pLng,
      double cos) {
    // Equirectangular frame centred on the point, in metres
    double ax = (track.lng()[a] - pLng) * cos * M_PER_DEGREE;
    double ay = (track.lat()[a] - pLat) * M_PER_DEGREE;
    double bx = (track.lng()[b] - pLng) * cos * M_PER_DEGREE;
    double by = (track.lat()[b] - pLat) * M_PER_DEGREE;
    double dx = bx - ax;
    double dy = by - ay;
    double lengthSq = dx * dx + dy * dy;
    double t = 0;
    if (lengthSq >= MIN_SEGMENT_SQ) {
      t = Math.max(0, Math.min(1, -(ax * dx + ay * dy) / lengthSq));
    }
    double px = ax + t * dx;
    double py = ay + t * dy;
    double perp = Math.sqrt(px * px + py * py);
    if (perp > SNAP_RADIUS_M) {
      return;
    }
    double along = track.offset() + track.dist()[a] + t * (track.dist()[b] - track.dist()[a]);
    out.add(new Candidate(along, perp));
  }
}
