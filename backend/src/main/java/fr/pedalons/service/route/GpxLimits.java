package fr.pedalons.service.route;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.github.glandais.engine.path.Path;
import java.util.List;

/**
 * Bounds on what the GPX pipeline accepts, so that a request cannot make it allocate without limit
 * (docs/LEDGER_*.md SEC-6, audit M3).
 *
 * <p>The pipeline resamples every track to one point per {@value #RESAMPLING_STEP_METERS} m before
 * anything else: the number of points it allocates follows the <em>distance</em> of the track, not
 * the size of the request. A handful of points far apart (or a GPX file of a few KB) would
 * otherwise produce millions of interpolated points. Hence three bounds, each checked before the
 * resampling allocates:
 *
 * <ul>
 *   <li>{@link #MAX_GPX_SIZE_BYTES}: an uploaded file, on every HTTP route that takes one (GPX
 *       tools create and update, team route create and update), through {@code api.gpx.GpxUploads}. The
 *       biketeam migration reads its files server to server and is not bound by it — the distance
 *       bound below still applies to it;
 *   <li>{@link #MAX_PLANNER_POINTS}: the planner points of a JSON request ({@code @Size} on the DTO
 *       lists), every one of them inside the WGS84 bounds ({@code GeoPoint});
 *   <li>{@link #MAX_TRACK_DISTANCE_METERS}: the summed length of all the tracks of a GPX, whatever
 *       its source, so at most about 400 000 resampled points (a few hundred MB at worst, transient).
 * </ul>
 *
 * <p>The values fit real cycling: 4 000 km covers an ultra-distance event in one file (Paris-Brest-
 * Paris 1 200 km, London-Edinburgh-London 1 500 km), and a longer journey is a trip made of several
 * stage routes; a route drawn with the planner carries a few thousand points per hundred km.
 * Raising {@link #MAX_TRACK_DISTANCE_METERS} raises the memory one request may take on the shared
 * backend in the same proportion.
 */
public final class GpxLimits {

  /** The step of the resampling the pipeline applies to every track ({@link GpxPipeline}). */
  public static final double RESAMPLING_STEP_METERS = 10.0;

  /**
   * Well under {@code quarkus.http.limits.max-body-size}, which is a global ceiling rather than a
   * per-upload guard. A 10 MB GPX is already several hundred thousand points.
   */
  public static final long MAX_GPX_SIZE_BYTES = 10L * 1024 * 1024;

  /** Summed length of all the tracks of one GPX: 4 000 km, about 400 000 resampled points. */
  public static final double MAX_TRACK_DISTANCE_METERS = 4_000_000.0;

  /**
   * Planner points in one request. The planner sends the routed, simplified geometry: one point
   * every 40 m over the longest accepted track is still well under this.
   */
  public static final int MAX_PLANNER_POINTS = 100_000;

  private GpxLimits() {}

  /** Mean Earth radius, the one a haversine distance is usually computed with. */
  private static final double EARTH_RADIUS_METERS = 6_371_000.0;

  /** {@link #checkTracks(List)} on every track (and route) of the document. */
  public static void checkTracks(GpxDocument doc) {
    checkTracks(GpxToPathJvm.tracksAsPaths(doc));
  }

  /**
   * Refuses tracks whose resampling would allocate without bound: a coordinate outside the WGS84
   * bounds (or not a number) is a {@code GPX_FAILURE}, a summed length over {@link
   * #MAX_TRACK_DISTANCE_METERS} a {@code GPX_TOO_LONG}. Linear in the number of points already
   * there, and allocates nothing.
   *
   * <p>The distance is computed here rather than read from the path's derived data, so the check
   * does not depend on whether a given vcyclist factory computed it.
   */
  public static void checkTracks(List<Path> paths) {
    double total = 0.0;
    for (Path path : paths) {
      for (int i = 0; i < path.getSize(); i++) {
        double lat = path.latitudeDeg(i);
        double lng = path.longitudeDeg(i);
        if (!isValidCoordinate(lat, lng)) {
          throw new BusinessException(ErrorCode.GPX_FAILURE);
        }
        if (i > 0) {
          total += haversine(path.latitudeDeg(i - 1), path.longitudeDeg(i - 1), lat, lng);
        }
      }
      // Checked per track so that a pathological file stops at the first one past the bound.
      // Written as a negation so that a NaN distance is refused too.
      if (!(total <= MAX_TRACK_DISTANCE_METERS)) {
        throw new BusinessException(ErrorCode.GPX_TOO_LONG);
      }
    }
  }

  private static double haversine(double lat1, double lng1, double lat2, double lng2) {
    double dLat = Math.toRadians(lat2 - lat1);
    double dLng = Math.toRadians(lng2 - lng1);
    double a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2)
                * Math.sin(dLng / 2);
    return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1.0, Math.sqrt(a)));
  }

  private static boolean isValidCoordinate(double lat, double lng) {
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }
}
