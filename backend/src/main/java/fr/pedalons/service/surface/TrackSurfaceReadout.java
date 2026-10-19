package fr.pedalons.service.surface;

import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.dto.routes.response.SurfaceSpanDto;
import fr.pedalons.enums.TrackSurfaceState;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * What the API knows of one track's surface when it builds the track: its stored document, and
 * whether a computation is queued (docs/LEDGER_*.md WEB-100, C1b).
 */
public record TrackSurfaceReadout(@Nullable TrackSurfaceDocument document, boolean pending) {

  /** Nothing known, nothing queued: the track is served without a surface state. */
  public static final TrackSurfaceReadout NONE = new TrackSurfaceReadout(null, false);

  /** A document, ready or not, wins over a pending request (a recompute keeps serving the old one). */
  public @Nullable TrackSurfaceState state() {
    if (document != null) {
      return document.ok() ? TrackSurfaceState.READY : TrackSurfaceState.UNAVAILABLE;
    }
    return pending ? TrackSurfaceState.PENDING : null;
  }

  /** The spans of a ready surface at the length the track has now, else null. */
  public @Nullable List<SurfaceSpanDto> spans(double trackLength) {
    return document != null && document.ok() ? SurfaceSpans.toDto(document, trackLength) : null;
  }
}
