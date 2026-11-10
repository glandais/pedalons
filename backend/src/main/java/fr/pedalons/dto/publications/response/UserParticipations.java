package fr.pedalons.dto.publications.response;

import fr.pedalons.dto.gps.response.RouteGpsSyncStatuses;
import fr.pedalons.dto.rides.response.RideGroupDto;
import java.util.Map;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * What the current user is registered to, among a known set of rides and trips, loaded once for a
 * whole page (or once for a single detail row).
 *
 * <p>This is the "me" half of a publication payload: {@code registered} and {@code
 * registeredGroupId} depend on who is asking, while {@link PublicationListSummaries} does not.
 * Keeping the two apart is what lets the summaries stay a pure per-entity aggregate.
 *
 * <p>Built by {@code fr.pedalons.service.common.ParticipationLookup}, which resolves the current
 * user itself — an anonymous caller gets {@link #NONE} and every "me" field reads false/null rather
 * than failing.
 *
 * @param registeredGroupIdByRideId ride id → the group of that ride the user joined; a ride absent
 *     from the map is a ride the user did not join
 * @param registeredTripIds the trip ids the user joined
 * @param registeredGroupByRideId ride id → the joined group, rendered — filled only on the list
 *     path, where a row has no {@code groups} to find it in (docs/LEDGER_*.md API-4); empty
 *     elsewhere
 * @param gpsSync the caller's sync statuses of the page's ride routes and of the joined groups'
 *     routes (docs/LEDGER_*.md API-120) — the one {@code GpsSyncLookup} call of a list page, made
 *     with the joined groups since their routes are only known then; {@link
 *     RouteGpsSyncStatuses#NONE} elsewhere
 */
public record UserParticipations(
    Map<Long, Long> registeredGroupIdByRideId,
    Set<Long> registeredTripIds,
    Map<Long, RideGroupDto> registeredGroupByRideId,
    RouteGpsSyncStatuses gpsSync) {

  /** Nobody is registered to anything — what an anonymous caller sees. */
  public static final UserParticipations NONE = new UserParticipations(Map.of(), Set.of());

  /** The ids only, without the rendered groups — the detail and the calendar need no more. */
  public UserParticipations(
      Map<Long, Long> registeredGroupIdByRideId, Set<Long> registeredTripIds) {
    this(registeredGroupIdByRideId, registeredTripIds, Map.of(), RouteGpsSyncStatuses.NONE);
  }

  /** The group of this ride the user joined, rendered, or {@code null}. */
  public @Nullable RideGroupDto registeredGroup(Long rideId) {
    return registeredGroupByRideId.get(rideId);
  }

  /** The group of this ride the user joined, or {@code null} if they did not join it. */
  public @Nullable Long registeredGroupId(Long rideId) {
    return registeredGroupIdByRideId.get(rideId);
  }

  public boolean isRegisteredToRide(Long rideId) {
    return registeredGroupIdByRideId.containsKey(rideId);
  }

  public boolean isRegisteredToTrip(Long tripId) {
    return registeredTripIds.contains(tripId);
  }
}
