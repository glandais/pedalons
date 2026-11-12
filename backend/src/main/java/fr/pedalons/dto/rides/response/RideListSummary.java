package fr.pedalons.dto.rides.response;

import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.service.ride.RideDisplayFigures;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * What a ride list row needs to know about a ride's groups and participants, without loading a
 * single {@code RideGroup}, {@code RideParticipation} or {@code User} entity.
 *
 * <p>Built in bulk for a whole page by {@link
 * fr.pedalons.repository.ride.RideSummaryRepository#loadListSummaries}.
 *
 * @param full every group of the ride has a capacity and has reached it. A ride with no groups, or
 *     with at least one uncapped group, is never full.
 * @param maxParticipants the sum of the groups' capacities, or {@code null} when the ride has no
 *     group or at least one uncapped group — the same rides {@code full} can never be true for
 * @param groups every group of the ride, in sort order
 * @param firstGroupRoute the route metrics of the first group (in sort order) that has a route —
 *     what the row shows when the ride itself has no route. Null when no group has one.
 * @param groupRoutes every group of the ride with its own live route, in sort order — what {@link
 *     RideDisplayFigures} picks the reader's figures from (docs/LEDGER_*.md API-178)
 */
public record RideListSummary(
    int groupCount,
    int participantCount,
    boolean full,
    @Nullable Integer maxParticipants,
    List<PublicUserDto> topParticipants,
    List<RideGroupSummaryDto> groups,
    @Nullable RouteMetrics firstGroupRoute,
    List<RideDisplayFigures.GroupRoute> groupRoutes) {

  /** A ride with no groups at all. */
  public static final RideListSummary EMPTY =
      new RideListSummary(0, 0, false, null, List.of(), List.of(), null, List.of());

  /** The figures of a route a ride card shows. */
  public record RouteMetrics(
      @Nullable Float distance, @Nullable Float elevationGain, @Nullable SurfaceType surfaceType) {}
}
