package fr.pedalons.service.route;

import fr.pedalons.domain.route.ClimbData;
import io.github.glandais.elevation.ElevationProvider;
import io.github.glandais.engine.climb.ClimbDetectorJvm;
import io.github.glandais.engine.path.ElevationStepJvm;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathSimplifierJvm;
import io.github.glandais.engine.path.PointPerDistance;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import org.jboss.logging.Logger;

/**
 * The geometry pipeline, shared by every producer of a track: resample, fix and smooth elevation,
 * simplify. One place so route import, GPX previews and the planner cannot drift apart.
 *
 * <p>Deliberately free of {@code java.nio.file}: {@link Path} here is vcyclist's immutable point
 * array, and the collision with {@code java.nio.file.Path} is contained by never importing both in
 * the same file. Each step returns a <b>new</b> {@link Path}; nothing is mutated, which is what
 * lets a caller keep the raw geometry and the processed one side by side.
 *
 * <p>Every constant below is inherited from gpx2web, not chosen:
 *
 * <ul>
 *   <li>{@code 0.5 / 10.0} — points closer than 0.5 m are dropped, gaps over 10 m are densified.
 *       Raising the minimum to 10 m would drop far more points and shorten every route.
 *   <li>{@code smoothElevation(p, 150.0)} is <b>not optional</b>: gpx2web's elevation fixer set the
 *       elevations <em>and then</em> smoothed over a 150 m window. vcyclist splits the two, so
 *       skipping the second call would change the elevation gain of every route.
 *   <li>{@code simplify(p, 3.0, 3.0)} — gpx2web's Douglas-Peucker tolerance, with the same ×3
 *       vertical exaggeration its ECEF projection applied.
 * </ul>
 *
 * <p>{@code fixElevationBlocking} parks the calling thread for the whole elevation fetch (it is a
 * bare {@code runBlocking}; the hop onto the IO dispatcher happens inside the tile fetcher). That
 * is harmless here because the pipeline runs under {@code @Transactional(NOT_SUPPORTED)}, so no DB
 * connection is held while it blocks.
 */
@ApplicationScoped
public class GpxPipeline {

  private static final Logger LOG = Logger.getLogger(GpxPipeline.class);

  @Inject ElevationProvider elevationProvider;

  /**
   * Runs the full pipeline on {@code source}, returning a new path. Elevation failures degrade
   * gracefully: the original elevations are kept and the rest of the pipeline still runs.
   *
   * @param name only used for logging, so a failure can be traced back to a track
   */
  public Path process(Path source, String name) {
    Path p =
        PointPerDistance.INSTANCE.computeOnePointPerDistance(
            source, 0.5, GpxLimits.RESAMPLING_STEP_METERS);
    LOG.debugv("Resampled {0} to {1} points", name, p.getSize());

    try {
      p = ElevationStepJvm.fixElevationBlocking(p, elevationProvider);
      p = ElevationStepJvm.smoothElevation(p, 150.0);
    } catch (Exception e) {
      LOG.warnf(e, "Elevation fix failed for %s, using original elevations", name);
    }

    Path simplified = PathSimplifierJvm.simplify(p, 3.0, 3.0);
    LOG.debugv("Simplified {0} to {1} points (Douglas-Peucker)", name, simplified.getSize());
    return simplified;
  }

  /** Detects the climbs of an already-processed path, in the frozen JSONB shape. */
  public List<ClimbData> climbs(Path path) {
    return ClimbDetectorJvm.detect(path).stream().map(ClimbData::from).toList();
  }
}
