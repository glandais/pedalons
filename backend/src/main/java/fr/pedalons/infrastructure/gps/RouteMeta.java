package fr.pedalons.infrastructure.gps;

import fr.pedalons.infrastructure.gpx.CoursePoint;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * What a route is sent with besides its GPX.
 *
 * @param name the name the service shows (Hammerhead takes it from the file name)
 * @param externalId Wahoo's {@code external_id}: stable for a route Pédalons keeps in sync ({@code
 *     pedalons-{domainId}-{rideId}}, docs/LEDGER_*.md API-120 D10); null for a manual upload, which
 *     keeps the SHA-256 of the GPX. Ignored by the other services, and by Wahoo's {@code PUT}, which
 *     cannot change it.
 * @param coursePoints the waypoints on the track, with their distance along it (docs/LEDGER_*.md
 *     WEB-100, C3c): the FIT Wahoo is sent and the Garmin course carry them. The GPX alone cannot
 *     say where a point sits on a route that passes twice by it. Hammerhead reads its points from
 *     the GPX and ignores this.
 */
public record RouteMeta(String name, @Nullable String externalId, List<CoursePoint> coursePoints) {

  public RouteMeta(String name, @Nullable String externalId) {
    this(name, externalId, List.of());
  }

  public static RouteMeta manual(String name) {
    return new RouteMeta(name, null, List.of());
  }

  public static RouteMeta manual(String name, List<CoursePoint> coursePoints) {
    return new RouteMeta(name, null, coursePoints);
  }
}
