package fr.pedalons.repository.ride;

import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * One ride group a user is registered in, as scalars: the group, its ride, and both candidate
 * routes (the group's own, the ride's), each null when absent or deleted. Selected in a single
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
    @Nullable String groupRouteSlug,
    @Nullable String groupRouteName,
    @Nullable Float groupRouteDistance,
    @Nullable Float groupRouteElevationGain,
    @Nullable String rideRouteSlug,
    @Nullable String rideRouteName,
    @Nullable Float rideRouteDistance,
    @Nullable Float rideRouteElevationGain) {

  /** The group's departure: its own start, the ride's when it has none. */
  public Instant startAt() {
    return groupStartAt != null ? groupStartAt : rideDateTime;
  }
}
