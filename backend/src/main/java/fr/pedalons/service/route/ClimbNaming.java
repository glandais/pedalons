package fr.pedalons.service.route;

import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * Names a climb after the waypoint the route's author put at its top (docs/LEDGER_*.md API-10).
 *
 * <p>A GPX built for a ride usually marks its passes — « Col de la Croix de Fer », « Côte de
 * Domancy » — as waypoints. A waypoint lying within {@link #MAX_SUMMIT_DISTANCE_METERS} of the
 * point where a detected climb ends <em>is</em> that climb's name: the author wrote it there. No
 * waypoint near the summit means no name, and clients keep « Montée N ».
 *
 * <p>Deliberately <b>not</b> a reverse geocoding of the summit: it would put a network call per
 * climb on every route detail (or a stored column and its backfill), and the nearest place name of
 * a summit is often a hamlet below it — a wrong name is worse than none.
 *
 * <p>Pure computation on what the caller already loaded (the track points and the route's
 * waypoints): no query.
 */
public final class ClimbNaming {

  /**
   * How far from the summit a waypoint may lie and still name the climb. Track points are about
   * 90 m apart after the import simplification, and a waypoint is often dropped beside the road
   * (on the pass sign, the café): a few hundred metres, not a kilometre that would reach the next
   * hairpin's hamlet.
   */
  public static final double MAX_SUMMIT_DISTANCE_METERS = 300;

  private static final double EARTH_RADIUS_METERS = 6_371_000;

  /** A named point of the route — a waypoint, whatever it was loaded from. */
  public record NamedPoint(String name, double lat, double lng) {}

  private ClimbNaming() {}

  /**
   * @param trackPoints the points of the track the climb was detected on, in distance order
   * @return the name of the closest waypoint to the summit within {@link
   *     #MAX_SUMMIT_DISTANCE_METERS}, or {@code null}
   */
  public static @Nullable String nameOf(
      ClimbData climb, List<TrackPoint> trackPoints, List<NamedPoint> waypoints) {
    if (trackPoints.isEmpty() || waypoints.isEmpty()) {
      return null;
    }
    TrackPoint summit = pointAt(trackPoints, climb.endDist());
    String best = null;
    double bestDistance = MAX_SUMMIT_DISTANCE_METERS;
    for (NamedPoint waypoint : waypoints) {
      if (waypoint.name() == null || waypoint.name().isBlank()) {
        continue;
      }
      double d = distanceMeters(summit.lat(), summit.lng(), waypoint.lat(), waypoint.lng());
      if (d <= bestDistance) {
        bestDistance = d;
        best = waypoint.name().strip();
      }
    }
    return best;
  }

  /** The track point whose cumulative distance is closest to {@code dist} (binary search). */
  static TrackPoint pointAt(List<TrackPoint> points, double dist) {
    int lo = 0;
    int hi = points.size() - 1;
    while (lo < hi) {
      int mid = (lo + hi) >>> 1;
      if (points.get(mid).dist() < dist) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0
        && Math.abs(points.get(lo - 1).dist() - dist) < Math.abs(points.get(lo).dist() - dist)) {
      return points.get(lo - 1);
    }
    return points.get(lo);
  }

  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    double dLat = Math.toRadians(lat2 - lat1);
    double dLng = Math.toRadians(lng2 - lng1);
    double a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2)
                * Math.sin(dLng / 2);
    return 2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}
