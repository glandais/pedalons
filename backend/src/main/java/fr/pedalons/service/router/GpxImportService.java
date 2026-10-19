package fr.pedalons.service.router;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.router.response.GpxImportResponse;
import fr.pedalons.dto.router.response.GpxImportTrack;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.GpxProcessingService.RawTracks;
import fr.pedalons.service.security.annotation.Logged;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.path.Path;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.function.Supplier;
import org.jspecify.annotations.Nullable;

/**
 * Loads a GPX file into the route editor (docs/LEDGER_*.md WEB-100, C4b): every track goes through
 * the pipeline with the FAST elevations — the editor edits a quick copy, the saved route is
 * recomputed as any other — and comes back as polylines, with the ascent accumulated up to each
 * point so a piece cut out of it keeps its ascent. Nothing is stored.
 *
 * <p>Not transactional: no connection is held while the pipeline waits for the elevation tiles.
 */
@ApplicationScoped
public class GpxImportService {

  private static final int MAX_NAME_LENGTH = 250;

  @Inject PlannerAccess plannerAccess;

  @Inject GpxProcessingService gpxProcessingService;

  @Inject GpxPipeline pipeline;

  /**
   * @param teamSlug the team the route is drawn for, if any (see {@link PlannerAccess#check})
   * @param file the uploaded file, asked for once the rights are checked: it refuses an oversized
   *     one (FILE_TOO_LARGE) before anything reads it
   * @param fileName the client-side file name, the last resort for the name
   */
  @Logged
  public GpxImportResponse importGpx(
      @Nullable String teamSlug, Supplier<java.nio.file.Path> file, @Nullable String fileName) {
    plannerAccess.check(teamSlug);
    // The size bound is applied by the supplier, after the rights and before the read.
    GpxDocument parsed = gpxProcessingService.parseGpx(file.get());
    RawTracks raw = gpxProcessingService.rawTracks(parsed);
    if (raw.paths().size() > GpxLimits.MAX_PLANNER_SOURCES) {
      throw new BusinessException(ErrorCode.PLANNER_IMPORT_TOO_LARGE);
    }

    List<GpxImportTrack> tracks = new ArrayList<>(raw.paths().size());
    int points = 0;
    boolean fallback = false;
    for (int i = 0; i < raw.paths().size(); i++) {
      GpxPipeline.ProcessedWithClimb result =
          pipeline.processWithClimb(
              raw.paths().get(i), raw.trackNames().get(i), ElevationQuality.FAST);
      Path path = result.processed().path();
      points += path.getSize();
      if (points > GpxLimits.MAX_PLANNER_POINTS) {
        throw new BusinessException(ErrorCode.PLANNER_IMPORT_TOO_LARGE);
      }
      fallback |= result.processed().fallbackAfterErrorKm() > 0.0;
      tracks.add(PlannerTracks.toTrack(path, result.climb()));
    }

    String documentName = GpxProcessingService.documentName(parsed);
    String name = documentName != null ? documentName : baseName(fileName);
    return new GpxImportResponse(cleanName(name), tracks, parsed.getWaypoints().size(), fallback);
  }

  /**
   * Control characters out, then cut to {@link #MAX_NAME_LENGTH} UTF-16 units without splitting a
   * surrogate pair: the name the editor pre-fills is one the route save accepts.
   */
  static String cleanName(String name) {
    String cleaned = name.replaceAll("\\p{Cntrl}", " ").strip();
    if (cleaned.length() > MAX_NAME_LENGTH) {
      int end = MAX_NAME_LENGTH;
      if (Character.isHighSurrogate(cleaned.charAt(end - 1))) {
        end--;
      }
      cleaned = cleaned.substring(0, end).strip();
    }
    return cleaned.isEmpty() ? "GPX" : cleaned;
  }

  /** A client-side file name without its {@code .gpx} extension, or "GPX" when there is none. */
  private static String baseName(@Nullable String fileName) {
    if (fileName == null || fileName.isBlank()) {
      return "GPX";
    }
    String trimmed = fileName.strip();
    return trimmed.toLowerCase(Locale.ROOT).endsWith(".gpx") && trimmed.length() > 4
        ? trimmed.substring(0, trimmed.length() - 4)
        : trimmed;
  }
}
