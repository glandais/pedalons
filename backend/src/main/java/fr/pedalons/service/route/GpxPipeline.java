package fr.pedalons.service.route;

import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.infrastructure.routedetails.RouteDetailsException;
import fr.pedalons.infrastructure.routedetails.RouteDetailsGateway;
import fr.pedalons.infrastructure.routedetails.RouteDetailsOptions;
import fr.pedalons.infrastructure.routedetails.RouteDetailsProfile;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse;
import fr.pedalons.infrastructure.routedetails.RouteDetailsSection;
import fr.pedalons.service.surface.RouteSurfaceAnswer;
import io.github.glandais.engine.climb.ClimbDetectorJvm;
import io.github.glandais.engine.path.ElevationGainJvm;
import io.github.glandais.engine.path.ElevationStepJvm;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathSimplifier;
import io.github.glandais.engine.path.PathSimplifierJvm;
import io.github.glandais.engine.path.PointPerDistance;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The geometry pipeline, shared by every producer of a track: read the elevations (bridge decks and
 * tunnels corrected, smoothed) and the ascent from osm-route-details, simplify, detect the climbs.
 * One place so route import, GPX previews and the planner cannot drift apart (docs/LEDGER_*.md
 * API-150).
 *
 * <p>Deliberately free of {@code java.nio.file}: {@link Path} here is vcyclist's immutable point
 * array, and the collision with {@code java.nio.file.Path} is contained by never importing both in
 * the same file. Each step returns a <b>new</b> {@link Path}; nothing is mutated, which is what
 * lets a caller keep the raw geometry and the processed one side by side.
 *
 * <ul>
 *   <li><b>Densify</b> the source to a point every {@value #SENT_MAX_GAP_M} m at most ({@link
 *       RouteDetailsTrack#densify}): the service answers the input points plus its breakpoints
 *       only, so a sparse input (a planner straight line) would get a profile sampled at a few
 *       breakpoints. 50 m is a third of the 150 m smoothing window; no source point is dropped.
 *   <li><b>One service call</b> through {@link RouteDetailsGateway} (thinned, sliced and stitched
 *       there), profile {@code fast} for {@link ElevationQuality#FAST} (Mapterhorn only) and {@code
 *       full} for {@link ElevationQuality#HD} (IGN LiDAR HD, decks in the surface model), sections
 *       {@code elevation} and {@code summary} — plus {@code typology} when the caller wants the
 *       surface of the same {@code full} call ({@link #processReported(Path, String,
 *       ElevationQuality, boolean)}) — {@code input_with_breakpoints} sampling, {@code smoothing_m =
 *       150}. The 150 m smoothing is <b>not optional</b>: gpx2web smoothed over that
 *       window, and every route since was measured that way — it is now the service's {@code
 *       ele_smoothed}.
 *   <li><b>The ascent</b> is the service's ({@code dem} preset), read from its cumulatives and set
 *       on the dense path, which Douglas-Peucker carries over unchanged: measured after the
 *       simplification, the ramps of a bridge on a flat route vanish (0.49 of the true D+ on
 *       vcyclist's Nantes bench).
 *   <li>{@code simplify(p, 3.0, 3.0)} — gpx2web's Douglas-Peucker tolerance, with the same ×3
 *       vertical exaggeration its ECEF projection applied — and the climb detection stay
 *       vcyclist's.
 * </ul>
 *
 * <p><b>Failure.</b> A call that fails, or an answer that cannot be used, never throws: the
 * original elevations are kept, resampled, smoothed and measured by vcyclist as before, and {@link
 * Processed#fallbackAfterErrorKm} is the whole length — {@code elevationFallback} for a FAST save,
 * a retry for the HD catch-up. {@code fast} is called with {@code accept_partial}: a typology
 * outage still gives Mapterhorn elevations, structures uncorrected, rather than a 503. {@code full}
 * is not: any outage is then a 503, retried later.
 *
 * <p>The call parks the calling thread, up to 15 s for {@code fast} and 100 s for {@code full} per
 * slice of about 188 km (the gateway's read timeouts). That is harmless here because the pipeline
 * runs under {@code @Transactional(NOT_SUPPORTED)}, so no DB connection is held while it blocks,
 * and it is why a caller with a user waiting asks for {@code FAST}: a {@code fast} call that gets no
 * answer also makes the gateway skip the next ones for a moment, so a caller looping over lines or
 * tracks waits for one timeout rather than one each. {@code full} runs in the HD worker, and in
 * the request only when {@code pedalons.elevation.async-hd.enabled} is off.
 */
@ApplicationScoped
public class GpxPipeline {

  /**
   * Bumped whenever the pipeline changes what it makes of a GPX (elevations, ascent, climbs), so
   * that what was built from a GPX by an earlier pipeline can be told apart and rebuilt. The
   * biketeam migration appends it to the fingerprint it records per route: a replay rebuilds every
   * route an earlier version built, once.
   *
   * <ul>
   *   <li>1 — gpx2web, then vcyclist 6.0 (Mapterhorn, raw ascent after simplification).
   *   <li>2 — vcyclist 6.8 (IGN LiDAR HD, bridge decks and tunnels, dead-band ascent before
   *       simplification; docs/LEDGER_*.md API-104, API-106).
   *   <li>3 — osm-route-details (api &ge; 1.6, profile {@code fast} for FAST, {@code full} for HD;
   *       its {@code meta.rules_version} is logged): terrain, bridges and tunnels, the 150 m
   *       smoothing and the dead-band ascent ({@code dem} preset) read from the service; vcyclist
   *       keeps Douglas-Peucker 3/3 and the climb detection (docs/LEDGER_*.md API-150).
   * </ul>
   *
   * <p>{@link ElevationQuality#FAST} and {@link ElevationQuality#HD} do <b>not</b> change this
   * number: a track first computed FAST is later recomputed HD, and that final result is the one
   * this version describes.
   */
  public static final int VERSION = 3;

  /** The widest gap sent to the service: a third of its 150 m smoothing window. */
  static final double SENT_MAX_GAP_M = 50.0;

  /**
   * Under this length, a track is not sent: the service refuses fewer than two distinct points (a
   * 400), and a degenerate line has no profile worth asking for. It still needs an altitude, as a
   * planner source carries 0 m: it is read at its first point, with {@link #PROBE_M}.
   */
  static final double MIN_LENGTH_M = 1.0;

  /** The length of the line sent to read the altitude of a degenerate track. */
  static final double PROBE_M = 10.0;

  /** The smoothing applied on the fallback path, the service's {@code smoothing_m}. */
  private static final double FALLBACK_SMOOTHING_M = RouteDetailsOptions.SMOOTHING_M;

  private static final Logger LOG = Logger.getLogger(GpxPipeline.class);

  /** Package-private so that a plain unit test can set the test fake. */
  @Inject RouteDetailsGateway routeDetails;

  /**
   * Runs the full pipeline on {@code source}, returning a new path. Never throws on an elevation
   * failure: an IGN tile that cannot be read is served from Mapterhorn by the service (and counted
   * in {@link Processed#fallbackAfterErrorKm}); a call that fails keeps the original elevations and
   * the rest of the pipeline still runs.
   *
   * @param name only used for logging, so a failure can be traced back to a track
   * @param quality {@code FAST} asks the service's {@code fast} profile (Mapterhorn only), {@code
   *     HD} its {@code full} one (IGN LiDAR HD with Mapterhorn as fallback, bridge decks ridden);
   *     everything after the elevations is identical
   */
  public Path process(Path source, String name, ElevationQuality quality) {
    return processReported(source, name, quality).path();
  }

  /**
   * A processed path and how much of it the elevation source failed to serve.
   *
   * @param fallbackAfterErrorKm kilometres read from a fallback because the preferred source
   *     errored: the service's {@code quality.terrain[]} ranges flagged {@code
   *     fallback_after_error} plus its {@code elevation_unavailable} ranges (docs/LEDGER_*.md
   *     API-150); the whole length of the track when the call failed and the original elevations
   *     were kept. Zero means the requested quality was really obtained (docs/LEDGER_*.md API-131).
   * @param surface what the answer says of the surface along {@code path}, when it was asked for
   *     and the service answered; null otherwise
   */
  public record Processed(
      Path path, double fallbackAfterErrorKm, @Nullable RouteSurfaceAnswer surface) {

    public Processed(Path path, double fallbackAfterErrorKm) {
      this(path, fallbackAfterErrorKm, null);
    }
  }

  /** {@link #process}, keeping the part of the elevation report the HD catch-up decides on. */
  public Processed processReported(Path source, String name, ElevationQuality quality) {
    return processReported(source, name, quality, false);
  }

  /**
   * {@link #processReported(Path, String, ElevationQuality)} that can also keep the surface, read
   * from the same answer as the profile (docs/LEDGER_*.md API-150): one call, no second one.
   *
   * @param withSurface for an {@code HD} track, asks the {@code typology} section and fills {@link
   *     Processed#surface()}; ignored for {@code FAST}, the surface coming with the HD profile
   */
  public Processed processReported(
      Path source, String name, ElevationQuality quality, boolean withSurface) {
    boolean surface = withSurface && quality == ElevationQuality.HD;
    DenseResult dense = processDense(source, name, quality, surface);
    if (!surface) {
      Path simplified = PathSimplifierJvm.simplify(dense.path(), 3.0, 3.0);
      LOG.debugv("Simplified {0} to {1} points (Douglas-Peucker)", name, simplified.getSize());
      return new Processed(simplified, dense.fallbackAfterErrorKm());
    }
    // The same path as simplify, which delegates to it: the indices are what anchors the surface
    PathSimplifier.Simplified simplified =
        PathSimplifierJvm.simplifyWithIndices(dense.path(), 3.0, 3.0);
    LOG.debugv(
        "Simplified {0} to {1} points (Douglas-Peucker)", name, simplified.getPath().getSize());
    return new Processed(
        simplified.getPath(), dense.fallbackAfterErrorKm(), surfaceOf(dense, simplified, name));
  }

  /** What {@code dense} says of the surface of its simplified path, null when it says nothing. */
  private static @Nullable RouteSurfaceAnswer surfaceOf(
      DenseResult dense, PathSimplifier.Simplified simplified, String name) {
    RouteDetailsTrack.Dense answer = dense.answer();
    if (answer == null) {
      return null;
    }
    Path path = simplified.getPath();
    if (dense.probed()) {
      return RouteSurfaceAnswer.degenerate(
          path.getTotalDistance(), answer.dataVersions(), answer.complete());
    }
    List<RouteDetailsResponse.Segment> segments = answer.segments();
    if (segments == null) {
      LOG.warnf("osm-route-details answered no segments for %s, no surface", name);
      return null;
    }
    return answer.surfaceAnswer(segments, simplified.getIndices(), path);
  }

  /**
   * A processed path with, for each of its points, the ascent accumulated up to it (the service's
   * {@code gain_cum_m}, or vcyclist's dead-band {@link ElevationGainJvm#cumulativeGain} on the
   * fallback path).
   *
   * @param climb one value per point of {@code processed.path()}: non-decreasing, first 0, last the
   *     path's reported ascent
   */
  public record ProcessedWithClimb(Processed processed, double[] climb) {}

  /**
   * {@link #processReported} that also keeps the cumulative ascent of every retained point: the
   * same points, the same ascent, plus what the planner needs to cut a piece out of the track and
   * still know its ascent.
   */
  public ProcessedWithClimb processWithClimb(Path source, String name, ElevationQuality quality) {
    DenseResult dense = processDense(source, name, quality, false);
    PathSimplifier.Simplified simplified =
        PathSimplifierJvm.simplifyWithIndices(dense.path(), 3.0, 3.0);
    double[] climb = RouteDetailsTrack.pick(dense.climb(), simplified.getIndices());
    LOG.debugv(
        "Simplified {0} to {1} points (Douglas-Peucker)", name, simplified.getPath().getSize());
    return new ProcessedWithClimb(
        new Processed(simplified.getPath(), dense.fallbackAfterErrorKm()), climb);
  }

  /**
   * The elevated, smoothed and measured path before the simplification, with the cumulative ascent
   * of each of its points.
   *
   * @param answer the answer {@code path} comes from, null when the original elevations were kept
   * @param probed whether {@code answer} is that of a probe of the elevation, sent in place of a
   *     degenerate track: its points are not those of {@code path}
   */
  private record DenseResult(
      Path path,
      double[] climb,
      double fallbackAfterErrorKm,
      RouteDetailsTrack.@Nullable Dense answer,
      boolean probed) {

    /** The original elevations kept. */
    DenseResult(Path path, double[] climb, double fallbackAfterErrorKm) {
      this(path, climb, fallbackAfterErrorKm, null, false);
    }
  }

  private DenseResult processDense(
      Path source, String name, ElevationQuality quality, boolean withSurface) {
    if (source.getSize() == 0) {
      return fallback(source, 0.0, false);
    }
    RouteDetailsProfile profile =
        quality == ElevationQuality.FAST ? RouteDetailsProfile.FAST : RouteDetailsProfile.FULL;
    double wholeKm = Math.max(source.getTotalDistance() / 1000.0, Double.MIN_VALUE);
    if (source.getSize() < 2 || source.getTotalDistance() < MIN_LENGTH_M) {
      RouteDetailsTrack.Dense probe =
          read(RouteDetailsTrack.probe(source, PROBE_M), name, profile, false);
      if (probe == null) {
        return fallback(source, wholeKm, false);
      }
      Path flat = RouteDetailsTrack.flat(source, probe.path());
      ElevationGainJvm.annotate(flat);
      return new DenseResult(
          flat, ElevationGainJvm.cumulativeGain(flat), probe.fallbackAfterErrorKm(), probe, true);
    }
    RouteDetailsTrack.Dense dense =
        read(RouteDetailsTrack.densify(source, SENT_MAX_GAP_M), name, profile, withSurface);
    if (dense == null) {
      return fallback(source, wholeKm, true);
    }
    return new DenseResult(dense.path(), dense.climb(), dense.fallbackAfterErrorKm(), dense, false);
  }

  /**
   * The answer for {@code sent}, or null, logged, when the call failed or the answer is unusable.
   */
  private RouteDetailsTrack.@Nullable Dense read(
      RouteDetailsTrack.Sent sent, String name, RouteDetailsProfile profile, boolean withSurface) {
    try {
      RouteDetailsResponse response =
          routeDetails.details(sent.lat(), sent.lon(), options(profile, withSurface));
      RouteDetailsTrack.Dense dense = RouteDetailsTrack.toDense(sent.lat(), sent.lon(), response);
      logAnswer(response, dense, name, sent.size());
      return dense;
    } catch (RouteDetailsException e) {
      if (e.kind() == RouteDetailsException.Kind.BUG) {
        LOG.errorf(
            e,
            "Elevation (osm-route-details, %s) failed for %s, original elevations kept",
            profile.value(),
            name);
      } else {
        LOG.warnf(
            "Elevation (osm-route-details, %s) failed for %s, original elevations kept: %s",
            profile.value(), name, e.getMessage());
      }
    } catch (RuntimeException e) {
      // The slicer, the stitcher or the conversion refused the line or the answer: a bug
      LOG.errorf(
          e,
          "Elevation (osm-route-details, %s) unusable for %s, original elevations kept",
          profile.value(),
          name);
    }
    return null;
  }

  /**
   * The request of {@code profile}. One place, so that the surface widens the sections of the same
   * {@code full} call rather than making a second one. {@code FAST} never asks for it: the HD
   * catch-up that follows does.
   *
   * @param withSurface all three sections, the {@code typology} included
   */
  private static RouteDetailsOptions options(RouteDetailsProfile profile, boolean withSurface) {
    // accept_partial in fast only: Mapterhorn elevations rather than a 503 when the typology is
    // down; in full, an outage is a 503 and the catch-up retries it
    RouteDetailsOptions options =
        RouteDetailsOptions.of(profile, profile == RouteDetailsProfile.FAST);
    return withSurface
        ? options
        : options.withSections(List.of(RouteDetailsSection.ELEVATION, RouteDetailsSection.SUMMARY));
  }

  /**
   * The pre-API-150 behaviour on failure: the original elevations, resampled to the vcyclist grid
   * ({@link GpxLimits#RESAMPLING_STEP_METERS}), smoothed over 150 m and measured by vcyclist's
   * dead band. Not resampled for a degenerate line, which keeps its points.
   */
  private static DenseResult fallback(Path source, double fallbackKm, boolean resample) {
    double step = GpxLimits.RESAMPLING_STEP_METERS;
    Path p =
        resample
            ? PointPerDistance.INSTANCE.computeOnePointPerDistance(source, step / 2.0, step)
            : source;
    p = ElevationStepJvm.smoothElevation(p, FALLBACK_SMOOTHING_M);
    ElevationGainJvm.annotate(p);
    return new DenseResult(p, ElevationGainJvm.cumulativeGain(p), fallbackKm);
  }

  /** Detects the climbs of an already-processed path, in the frozen JSONB shape. */
  public List<ClimbData> climbs(Path path) {
    return ClimbDetectorJvm.detect(path).stream().map(ClimbData::from).toList();
  }

  /**
   * The answer's identity and figures at debug level; the warnings that say the profile is
   * knowingly degraded (a source down, a range without data or typology) at warn, the routine ones
   * at debug.
   */
  private static void logAnswer(
      RouteDetailsResponse response, RouteDetailsTrack.Dense dense, String name, int sentPoints) {
    if (LOG.isDebugEnabled()) {
      RouteDetailsResponse.Meta meta = response.meta();
      LOG.debugv(
          "Elevation of {0} (osm-route-details, profile {1}, rules {2}, {3}): {4} points sent,"
              + " {5} answered, D+ {6} m, fallback {7} km",
          name,
          meta == null ? null : meta.profile(),
          meta == null ? null : meta.rulesVersion(),
          response.status(),
          sentPoints,
          dense.path().getSize(),
          Math.round(dense.path().getReportedElevationGain()),
          dense.fallbackAfterErrorKm());
    }
    if (dense.interpolatedM() > 0) {
      LOG.warnf(
          "Elevation of %s: %.1f km without elevation, interpolated",
          name, dense.interpolatedM() / 1000.0);
    }
    RouteDetailsResponse.Quality quality = response.quality();
    if (quality == null || quality.warnings() == null) {
      return;
    }
    for (RouteDetailsResponse.Warning w : quality.warnings()) {
      if (w.code() != null && RouteDetailsTrack.DEGRADED_WARNINGS.contains(w.code())) {
        LOG.warnf(
            "Elevation of %s: %s [%s-%s m] %s", name, w.code(), w.fromM(), w.toM(), w.message());
      } else {
        LOG.debugv(
            "Elevation of {0}: {1} [{2}-{3} m] {4}",
            name, w.code(), w.fromM(), w.toM(), w.message());
      }
    }
  }
}
