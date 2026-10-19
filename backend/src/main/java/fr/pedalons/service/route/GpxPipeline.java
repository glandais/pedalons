package fr.pedalons.service.route;

import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.infrastructure.gpx.ElevationTier;
import io.github.glandais.elevation.ElevationProvider;
import io.github.glandais.engine.ElevationCorrectionJvm;
import io.github.glandais.engine.EngineModelJvm;
import io.github.glandais.engine.climb.ClimbDetectorJvm;
import io.github.glandais.engine.path.ElevationCorrections;
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

/**
 * The geometry pipeline, shared by every producer of a track: fix the elevations (bridge decks and
 * tunnels included), smooth them, measure the ascent, simplify. One place so route import, GPX
 * previews and the planner cannot drift apart.
 *
 * <p>Deliberately free of {@code java.nio.file}: {@link Path} here is vcyclist's immutable point
 * array, and the collision with {@code java.nio.file.Path} is contained by never importing both in
 * the same file. Each step returns a <b>new</b> {@link Path}; nothing is mutated, which is what
 * lets a caller keep the raw geometry and the processed one side by side.
 *
 * <ul>
 *   <li>{@code fixAndCorrect} brings its own grid — 30 m for the DEM read, then a refinement — and
 *       ours is only its upper bound, {@link GpxLimits#RESAMPLING_STEP_METERS}: a point every 5 to
 *       10 m. vcyclist's default is 2 m, but a path costs 352 bytes a point and SEC-6 sizes the
 *       memory of a request on 10 m. The deck and tunnel detectors read their own 5 m stations
 *       whatever the grid, and the 150 m smoothing does not tell 10 m from 5 m.
 *   <li>{@code smoothElevation(p, 150.0)} is <b>not optional</b>: gpx2web's elevation fixer set the
 *       elevations <em>and then</em> smoothed over a 150 m window, and every route since was
 *       measured that way.
 *   <li>{@code ElevationGainJvm.annotate} runs <b>before</b> the simplification, which carries the
 *       figure over: the D+ is the dead-band ascent of the unsmoothed profile (bridge decks
 *       included), read through {@code getReportedElevationGain()}. Measured after Douglas-Peucker,
 *       the ramps of a bridge on a flat route vanish (0.49 of the true D+ on vcyclist's Nantes
 *       bench).
 *   <li>{@code simplify(p, 3.0, 3.0)} — gpx2web's Douglas-Peucker tolerance, with the same ×3
 *       vertical exaggeration its ECEF projection applied.
 * </ul>
 *
 * <p>{@code fixAndCorrectBlocking} parks the calling thread for the whole elevation fetch (a bare
 * {@code runBlocking}; the hop onto the IO dispatcher happens inside the tile fetcher). That is
 * harmless here because the pipeline runs under {@code @Transactional(NOT_SUPPORTED)}, so no DB
 * connection is held while it blocks. The wait is a few seconds for {@code FAST} and up to ~20 s
 * on a cold {@code HD} route, which is why a caller with a user waiting asks for {@code FAST}.
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
   * </ul>
   *
   * <p>{@link ElevationQuality#FAST} and {@link ElevationQuality#HD} do <b>not</b> change this
   * number: a track first computed FAST is later recomputed HD, and that final result is the one
   * this version describes.
   */
  public static final int VERSION = 2;

  private static final Logger LOG = Logger.getLogger(GpxPipeline.class);

  @Inject
  @ElevationTier(ElevationQuality.FAST)
  ElevationProvider fastElevationProvider;

  @Inject
  @ElevationTier(ElevationQuality.HD)
  ElevationProvider hdElevationProvider;

  /**
   * Runs the full pipeline on {@code source}, returning a new path. An IGN tile that cannot be read
   * never throws: its points are read from Mapterhorn instead, and a bridge deck or tunnel step
   * that cannot read its tiles leaves the profile as the DEM read made it — both say so in the
   * path's report, which is logged here. Only when Mapterhorn fails too does the fix throw; the
   * original elevations are then kept and the rest of the pipeline still runs.
   *
   * @param name only used for logging, so a failure can be traced back to a track
   * @param quality {@code FAST} reads Mapterhorn only, {@code HD} IGN LiDAR HD with Mapterhorn as
   *     fallback and bridge decks ridden; everything after the elevation fix is identical
   */
  public Path process(Path source, String name, ElevationQuality quality) {
    return processReported(source, name, quality).path();
  }

  /**
   * A processed path and how much of it the elevation source failed to serve.
   *
   * @param fallbackAfterErrorKm kilometres read from a fallback because the preferred source
   *     errored (vcyclist's {@code TerrainProvenance.fallbackAfterErrorKm}); the whole length of the
   *     track when the fix itself threw and the original elevations were kept. Zero means the
   *     requested quality was really obtained (docs/LEDGER_*.md API-131).
   */
  public record Processed(Path path, double fallbackAfterErrorKm) {}

  /** {@link #process}, keeping the part of the elevation report the HD catch-up decides on. */
  public Processed processReported(Path source, String name, ElevationQuality quality) {
    DenseResult dense = processDense(source, name, quality);
    Path simplified = PathSimplifierJvm.simplify(dense.path(), 3.0, 3.0);
    LOG.debugv("Simplified {0} to {1} points (Douglas-Peucker)", name, simplified.getSize());
    return new Processed(simplified, dense.fallbackAfterErrorKm());
  }

  /**
   * A processed path with, for each of its points, the ascent accumulated up to it (the dead-band
   * ascent of {@link ElevationGainJvm#cumulativeGain}, same options as the annotation).
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
    DenseResult dense = processDense(source, name, quality);
    double[] cumulative = ElevationGainJvm.cumulativeGain(dense.path());
    PathSimplifier.Simplified simplified =
        PathSimplifierJvm.simplifyWithIndices(dense.path(), 3.0, 3.0);
    int[] indices = simplified.getIndices();
    double[] climb = new double[indices.length];
    for (int k = 0; k < indices.length; k++) {
      climb[k] = cumulative[indices[k]];
    }
    LOG.debugv(
        "Simplified {0} to {1} points (Douglas-Peucker)", name, simplified.getPath().getSize());
    return new ProcessedWithClimb(
        new Processed(simplified.getPath(), dense.fallbackAfterErrorKm()), climb);
  }

  /** The resampled, corrected, smoothed and annotated path, before the simplification. */
  private record DenseResult(Path path, double fallbackAfterErrorKm) {}

  private DenseResult processDense(Path source, String name, ElevationQuality quality) {
    double fallbackKm = 0.0;
    ElevationProvider elevationProvider =
        quality == ElevationQuality.FAST ? fastElevationProvider : hdElevationProvider;
    double step = GpxLimits.RESAMPLING_STEP_METERS;
    Path p;
    try {
      p =
          ElevationCorrectionJvm.fixAndCorrectBlocking(
              source, elevationProvider, EngineModelJvm.elevationCorrectionOptions(), step);
      logCorrections(p.getElevationCorrections(), name);
      ElevationCorrections report = p.getElevationCorrections();
      if (report != null && report.getTerrain() != null) {
        fallbackKm = report.getTerrain().getFallbackAfterErrorKm();
      }
    } catch (Exception e) {
      LOG.warnf(e, "Elevation fix failed for %s, using original elevations", name);
      fallbackKm = Math.max(source.getTotalDistance() / 1000.0, Double.MIN_VALUE);
      p = PointPerDistance.INSTANCE.computeOnePointPerDistance(source, step / 2.0, step);
    }
    LOG.debugv("Resampled {0} to {1} points", name, p.getSize());

    p = ElevationStepJvm.smoothElevation(p, 150.0);
    ElevationGainJvm.annotate(p);
    return new DenseResult(p, fallbackKm);
  }

  /** Detects the climbs of an already-processed path, in the frozen JSONB shape. */
  public List<ClimbData> climbs(Path path) {
    return ClimbDetectorJvm.detect(path).stream().map(ClimbData::from).toList();
  }

  /**
   * The warnings vcyclist raises only when the profile is knowingly wrong or depends on the network
   * (a tile it could not read, a deck it found but could not ride); the statuses at debug level.
   */
  private static void logCorrections(ElevationCorrections report, String name) {
    if (report == null) {
      return;
    }
    LOG.debugv(
        "Elevation corrections of {0}: bridge decks {1} ({2}), tunnels {3} ({4})",
        name,
        report.getBridgeDecks().getId(),
        report.getBridgeDecksApplied(),
        report.getTunnels().getId(),
        report.getTunnelsApplied());
    report.getWarnings().forEach(w -> LOG.warnf("Elevation corrections of %s: %s", name, w));
  }
}
