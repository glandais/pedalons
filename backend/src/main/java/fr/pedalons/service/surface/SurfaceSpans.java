package fr.pedalons.service.surface;

import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.dto.routes.response.SurfaceSpanDto;
import fr.pedalons.enums.TrackSurface;
import java.util.ArrayList;
import java.util.List;

/**
 * The surface classes of the contract, derived on reading from a stored document (docs/LEDGER_*.md
 * WEB-100, C1b).
 *
 * <p>The distances are rescaled to the length the track has <em>now</em>, here and never in the
 * document: the HD catch-up of a route updates its track in place (the previous release too, during
 * a rolling deploy) and re-simplifies it, which moves its length by a few metres at most. The
 * document stays right, and follows the new length with no write.
 */
public final class SurfaceSpans {

  private SurfaceSpans() {}

  /**
   * @param trackLength the length of the track now: the {@code M} of its last point
   * @return contiguous spans from 0 to {@code trackLength}, neighbours of the same class merged;
   *     empty for a track without length
   */
  public static List<SurfaceSpanDto> toDto(TrackSurfaceDocument doc, double trackLength) {
    if (!(trackLength > 0)) {
      return List.of();
    }
    double scale = doc.distance() > 0 ? trackLength / doc.distance() : 1;
    List<SurfaceSpanDto> spans = new ArrayList<>();
    for (SurfaceRange range : doc.surfaces()) {
      TrackSurface surface = TrackSurface.ofCode(range.code());
      double to = range.to() * scale;
      if (!spans.isEmpty() && spans.getLast().surface() == surface) {
        SurfaceSpanDto last = spans.removeLast();
        spans.add(new SurfaceSpanDto(last.from(), to, surface));
      } else {
        spans.add(new SurfaceSpanDto(range.from() * scale, to, surface));
      }
    }
    if (spans.isEmpty()) {
      return List.of(
          new SurfaceSpanDto(0, SurfaceRanges.decimetre(trackLength), TrackSurface.UNKNOWN));
    }
    List<SurfaceSpanDto> out = new ArrayList<>(spans.size());
    for (int i = 0; i < spans.size(); i++) {
      SurfaceSpanDto span = spans.get(i);
      double from = i == 0 ? 0 : out.getLast().to();
      double to = i == spans.size() - 1 ? trackLength : span.to();
      out.add(new SurfaceSpanDto(from, SurfaceRanges.decimetre(to), span.surface()));
    }
    return out;
  }
}
