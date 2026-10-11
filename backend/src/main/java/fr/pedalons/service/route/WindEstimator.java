package fr.pedalons.service.route;

import fr.pedalons.enums.WindDirection;
import io.github.glandais.elevation.Vector3D;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathWindJvm;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;
import org.jspecify.annotations.Nullable;

/**
 * Turns a route's dominant headwind vector into the compass sector the wind is estimated to blow
 * from.
 *
 * <p>Lives outside {@link GpxProcessingService} so the estimation can be unit-tested without a
 * Quarkus context — and because its reference frame is the one thing this migration could silently
 * get wrong. gpx2web computed the vector in Web Mercator <b>pixel</b> space, where {@code y} points
 * <b>south</b>; vcyclist's {@code dominantHeadwindDirection} returns a unit vector in a local
 * <b>east/north</b> frame, where {@code y} points <b>north</b>. Hence the {@code -v.getY()} in
 * {@link #estimate}: the scoring method below keeps gpx2web's frame and is untouched by the swap.
 */
public final class WindEstimator {

  private WindEstimator() {}

  /**
   * The migrated entry point: dominant headwind over every processed path of a route.
   *
   * <p>{@code null} in two genuine cases vcyclist documents — fewer than four contributing points,
   * or a symmetric out-and-back whose average cancels out. {@code WindDirection} is already
   * nullable in {@code TrackMetadata}, so it is just a guard.
   */
  @Nullable
  public static WindDirection estimate(List<Path> paths) {
    Vector3D v = PathWindJvm.dominantHeadwindDirection(paths);
    return v == null ? null : findDirectionFromVector(v.getX(), -v.getY());
  }

  /**
   * The verbatim body of gpx2web's {@code GpxProcessingService.findDirectionFromVector}: for each
   * compass sector, scores how anti-parallel its reference unit vector is to {@code (x, y)}, and
   * keeps the <b>lowest</b> score.
   *
   * <p>Two properties look like bugs and are not: the {@code y1 = Math.sin(angle) * -1} flips into
   * gpx2web's Mercator frame (Y south), and {@code .sorted(...).findFirst()} keeps the minimum, not
   * the maximum. Both are load-bearing — inverting either changes the wind direction reported for
   * every route. See migration plan §4.
   */
  @Nullable
  public static WindDirection findDirectionFromVector(double x, double y) {
    return Stream.of(WindDirection.values())
        .map(
            wd -> {
              double angle = Math.toRadians(90 - wd.getAngle());
              double x1 = Math.cos(angle);
              double y1 = Math.sin(angle) * -1;
              double x2 = x;
              double y2 = y;
              double dotProduct = (x1 * x2) + (y1 * y2);
              return new WindScore(wd, 0.5 + (0.5 * dotProduct));
            })
        .sorted(Comparator.comparing(WindScore::score))
        .map(WindScore::wd)
        .findFirst()
        .orElse(null);
  }

  private record WindScore(WindDirection wd, double score) {}
}
