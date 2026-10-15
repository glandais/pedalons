package fr.pedalons.service.route;

import fr.pedalons.common.GeoDistance;
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
 * <p>The pipeline resamples every track to one point every 5 to {@value #RESAMPLING_STEP_METERS} m
 * ({@link GpxPipeline}): the number of points it allocates follows the <em>distance</em> of the track, not
 * the size of the request. A handful of points far apart (or a GPX file of a few KB) would
 * otherwise produce millions of interpolated points. Hence three bounds, each checked before the
 * resampling allocates:
 *
 * <ul>
 *   <li>{@link #MAX_GPX_SIZE_BYTES}: an uploaded file, on every HTTP route that takes one (GPX
 *       tools create, update and merge — whose files are also bound together by {@link
 *       #MAX_MERGE_TOTAL_BYTES} —, team route create and update), through {@code api.gpx.GpxUploads}. The
 *       biketeam migration reads its files server to server and is not bound by it — the distance
 *       bound below still applies to it;
 *   <li>{@link #MAX_PLANNER_POINTS}: the planner points of a JSON request ({@code @Size} on the DTO
 *       lists), every one of them inside the WGS84 bounds ({@code GeoPoint});
 *   <li>{@link #MAX_TRACK_DISTANCE_METERS}: the summed length of all the tracks of a GPX, whatever
 *       its source, so 400 000 to 800 000 resampled points at 352 bytes each (vcyclist 6.5.0) —
 *       a few hundred MB at worst, transient.
 * </ul>
 *
 * <p>The values fit real cycling: 4 000 km covers an ultra-distance event in one file (Paris-Brest-
 * Paris 1 200 km, London-Edinburgh-London 1 500 km), and a longer journey is a trip made of several
 * stage routes; a route drawn with the planner carries a few thousand points per hundred km.
 * Raising {@link #MAX_TRACK_DISTANCE_METERS} raises the memory one request may take on the shared
 * backend in the same proportion.
 */
public final class GpxLimits {

  /**
   * The widest gap the pipeline leaves between two points ({@link GpxPipeline}), the narrowest
   * being half of it. Not above 10 m: past it, vcyclist warns, the ramps of a bridge deck or a
   * tunnel fall between two points.
   */
  public static final double RESAMPLING_STEP_METERS = 10.0;

  /**
   * Well under {@code quarkus.http.limits.max-body-size}, which is a global ceiling rather than a
   * per-upload guard. A 10 MB GPX is already several hundred thousand points.
   */
  public static final long MAX_GPX_SIZE_BYTES = 10L * 1024 * 1024;

  /** Summed length of all the tracks of one GPX: 4 000 km, at most about 800 000 resampled points. */
  public static final double MAX_TRACK_DISTANCE_METERS = 4_000_000.0;

  /**
   * Planner points in one request. The planner sends the routed, simplified geometry: one point
   * every 40 m over the longest accepted track is still well under this.
   */
  public static final int MAX_PLANNER_POINTS = 100_000;

  /** Fewest GPX files one merge takes: merging a single file is just an upload. */
  public static final int MIN_MERGE_FILES = 2;

  /** Most GPX files one merge takes. Their summed size is bound by {@link #MAX_MERGE_TOTAL_BYTES}. */
  public static final int MAX_MERGE_FILES = 10;

  /**
   * Summed size of all the files of one merge: the same as one upload, so that a merge never feeds
   * the pipeline more raw points than a single file may (SEC-6) — the distance bound only limits
   * the resampled output. Well under {@code quarkus.http.limits.max-body-size} too, so a merge
   * near the bound gets {@code FILE_TOO_LARGE} rather than a bare 413 from Vert.x.
   */
  public static final long MAX_MERGE_TOTAL_BYTES = MAX_GPX_SIZE_BYTES;

  /**
   * Most tracks (all files together) one merge orders. The exact ordering is a dynamic programme in
   * O(2<sup>n</sup>·n²) time and O(2<sup>n</sup>·n) memory: 16 tracks are about 70 million steps and
   * 24 MB, transient; each extra track doubles both.
   */
  public static final int MAX_MERGE_TRACKS = 16;

  private GpxLimits() {}

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
          total +=
              GeoDistance.haversineMeters(
                  path.latitudeDeg(i - 1), path.longitudeDeg(i - 1), lat, lng);
        }
      }
      // Checked per track so that a pathological file stops at the first one past the bound.
      // Written as a negation so that a NaN distance is refused too.
      if (!(total <= MAX_TRACK_DISTANCE_METERS)) {
        throw new BusinessException(ErrorCode.GPX_TOO_LONG);
      }
    }
  }

  private static boolean isValidCoordinate(double lat, double lng) {
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }
}
