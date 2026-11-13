package fr.pedalons.repository.ride;

import fr.pedalons.enums.Status;
import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * One ride group a user is registered in, as scalars: the group, its ride, and both candidate
 * routes (the group's own, the ride's), each null when absent or deleted; then what a device shows
 * beside them — the team's name, the name of the ride's start place, the ride's status and the
 * group's speed, from which its arrival is estimated (docs/LEDGER_*.md API-194). Selected in a single
 * query so nothing enters the persistence context — see {@link
 * RideParticipationRepository#findUpcomingRegisteredGroups}.
 */
public record RegisteredGroupRow(
    String teamSlug,
    String rideSlug,
    String rideName,
    String groupName,
    @Nullable Instant groupStartAt,
    Instant rideDateTime,
    String timezone,
    @Nullable Long groupRouteId,
    @Nullable String groupRouteSlug,
    @Nullable String groupRouteName,
    @Nullable Float groupRouteDistance,
    @Nullable Float groupRouteElevationGain,
    @Nullable Long rideRouteId,
    @Nullable String rideRouteSlug,
    @Nullable String rideRouteName,
    @Nullable Float rideRouteDistance,
    @Nullable Float rideRouteElevationGain,
    String teamName,
    @Nullable String startPlaceName,
    Status rideStatus,
    @Nullable Float groupAverageSpeed) {

  /** The group's departure: its own start, the ride's when it has none. */
  public Instant startAt() {
    return groupStartAt != null ? groupStartAt : rideDateTime;
  }

  /** Whether the group's own route is the one to load (it wins over the ride's). */
  public boolean ownRoute() {
    return groupRouteSlug != null;
  }

  /** The id of the route to load: the group's own, the ride's when it has none. */
  public @Nullable Long effectiveRouteId() {
    return ownRoute() ? groupRouteId : rideRouteId;
  }
}
