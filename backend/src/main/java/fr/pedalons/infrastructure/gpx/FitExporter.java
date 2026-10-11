package fr.pedalons.infrastructure.gpx;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import io.github.glandais.engine.path.Path;
import io.github.glandais.fit.FitUnits;
import io.github.glandais.fit.PathToFitJvm;
import java.util.List;
import org.jboss.logging.Logger;

/**
 * The single place where a FIT course is built from vcyclist paths.
 *
 * <p>Two callers need it and neither may diverge from the other: route import writes the FIT next to
 * the two GPX serializations, and the Wahoo upload builds one on the fly because Wahoo's {@code POST
 * /v1/routes} takes a FIT payload and nothing else.
 *
 * <p>{@code startTime} is mandatory (FIT has no relative clock): the first point's own timestamp,
 * but never before the FIT epoch (1989-12-31). A route carries no time — every stored track is
 * stripped of it (docs/LEDGER_*.md API-44) — so its first point sits at Unix epoch 0, which FIT
 * cannot represent: the unsigned field wraps and the course comes out dated 2106. Starting it at
 * the FIT epoch writes the one date that plainly means "no clock". The library rebases each path
 * onto that start itself; rebasing here too would overwrite every timestamp.
 */
public final class FitExporter {

  private static final Logger LOG = Logger.getLogger(FitExporter.class);

  private FitExporter() {}

  /**
   * FIT bytes for {@code paths}, under the course name {@code name}.
   *
   * <p>Empty paths are filtered out because the writer rejects them outright.
   *
   * @throws BusinessException {@code GPX_EMPTY} when nothing is left to write, {@code GPX_FAILURE}
   *     when the writer refuses the geometry
   */
  public static byte[] toFitBytes(List<Path> paths, String name) {
    List<Path> nonEmpty =
        paths.stream().filter(p -> p.getSize() > 0).map(FitExporter::monotonic).toList();
    if (nonEmpty.isEmpty()) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    long startMillis = Math.max((long) nonEmpty.getFirst().time(0), FitUnits.FIT_EPOCH_OFFSET_MS);
    try {
      return PathToFitJvm.toFitBytes(nonEmpty, name, startMillis);
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /**
   * The same path, or — when its timestamps go backwards — the same geometry with no clock at all,
   * which is what {@code PathToFit} accepts.
   *
   * <p>The writer requires monotonic time, which gpx2web never checked: a recording whose clock
   * resynchronised mid-ride used to import fine. Rather than reject the whole file, such a path is
   * exported without its timestamps — the FIT then reads as a course, which is what these files are
   * used for anyway.
   */
  private static Path monotonic(Path path) {
    for (int i = 1; i < path.getSize(); i++) {
      if (path.time(i) < path.time(i - 1)) {
        LOG.warn("Path has non-monotonic timestamps, exporting it to FIT without any");
        return path.withoutTime();
      }
    }
    return path;
  }
}
