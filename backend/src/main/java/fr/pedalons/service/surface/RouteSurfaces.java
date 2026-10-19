package fr.pedalons.service.surface;

import fr.pedalons.domain.route.TrackSurfaceDocument;
import java.util.Map;

/**
 * The surfaces of the tracks of one route, read for its detail (docs/LEDGER_*.md WEB-100, C1b).
 *
 * @param byTrackId the stored documents, tracks without one absent
 * @param pending whether a computation is queued for the route
 */
public record RouteSurfaces(Map<Long, TrackSurfaceDocument> byTrackId, boolean pending) {

  /** Not read: the bulk endpoint, a list in the sense of the page rule. */
  public static final RouteSurfaces NONE = new RouteSurfaces(Map.of(), false);

  public TrackSurfaceReadout of(Long trackId) {
    return new TrackSurfaceReadout(byTrackId.get(trackId), pending);
  }
}
