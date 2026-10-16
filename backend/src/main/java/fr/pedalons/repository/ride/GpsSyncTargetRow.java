package fr.pedalons.repository.ride;

import fr.pedalons.enums.GpsServiceType;
import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * One registration whose route a GPS service connection should hold, as ids and scalars: the
 * connection, the ride, the group, and both candidate routes (the group's own, the ride's), each
 * null when absent or deleted. Selected in a single query per domain — see {@link
 * RideParticipationRepository#findGpsSyncTargets} — and used by the automatic route sync
 * (docs/LEDGER_*.md API-120).
 */
public record GpsSyncTargetRow(
    Long connectionId,
    GpsServiceType serviceType,
    Long userId,
    Long rideId,
    Long groupId,
    String groupName,
    Instant groupStartAt,
    String timezone,
    @Nullable Long groupRouteId,
    @Nullable String groupRouteName,
    @Nullable Long rideRouteId,
    @Nullable String rideRouteName) {

  /** The route the group rides: its own, failing that its ride's. */
  public @Nullable Long effectiveRouteId() {
    return groupRouteId != null ? groupRouteId : rideRouteId;
  }

  public @Nullable String effectiveRouteName() {
    return groupRouteId != null ? groupRouteName : rideRouteName;
  }
}
