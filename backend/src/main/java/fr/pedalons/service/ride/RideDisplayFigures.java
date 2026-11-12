package fr.pedalons.service.ride;

import fr.pedalons.domain.route.Route;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * The one distance and elevation gain a ride card shows, for the person reading it
 * (docs/LEDGER_*.md API-178, rule R3 of the card audit).
 *
 * <p>The rule: the route of <em>their</em> group when they are registered; otherwise the route the
 * whole ride shares; otherwise nothing. A group rides its own route, else the ride's — the same
 * « ridden route » as {@code PublicationEndCalculator}, a deleted route counting as none. The shared
 * route is the one every group rides (the ride's own when it has no group); as soon as two groups
 * ride different routes, or one rides none, a reader who has not joined gets nothing rather than one
 * group's figures passed off as the ride's.
 *
 * <p>Pure: it takes figures already loaded for a whole page — {@code RideSummaryRepository} on the
 * list path, the ride's groups on the detail, {@code RideGroupRepository#findGroupRoutesByRideIds} for the
 * calendar — and runs no query, so no caller can make it cost one per row.
 */
public final class RideDisplayFigures {

  private RideDisplayFigures() {}

  /** The figures of one live route. */
  public record RouteFigures(
      Long routeId, @Nullable Float distance, @Nullable Float elevationGain) {}

  /**
   * One group of a ride, for this rule.
   *
   * @param ownRoute the group's own route, null when it has none or it is deleted — it then rides
   *     the ride's
   */
  public record GroupRoute(Long groupId, @Nullable RouteFigures ownRoute) {}

  /** What a card shows; both null when the rule says nothing. */
  public record Figures(@Nullable Float distance, @Nullable Float elevationGain) {
    public static final Figures NONE = new Figures(null, null);

    static Figures of(@Nullable RouteFigures route) {
      return route == null ? NONE : new Figures(route.distance(), route.elevationGain());
    }
  }

  /** The figures of {@code route}, or null when there is none or it is deleted. */
  public static @Nullable RouteFigures live(@Nullable Route route) {
    return route == null || route.isDeleted()
        ? null
        : new RouteFigures(route.getId(), route.getDistance(), route.getElevationGain());
  }

  /**
   * @param rideRoute the ride's own live route, null when it has none
   * @param groups every group of the ride
   * @param registeredGroupId the group the reader joined, null when they joined none — anonymous,
   *     outside the team, or simply not registered
   */
  public static Figures resolve(
      @Nullable RouteFigures rideRoute, List<GroupRoute> groups, @Nullable Long registeredGroupId) {
    if (registeredGroupId != null) {
      for (GroupRoute group : groups) {
        if (group.groupId().equals(registeredGroupId)) {
          return Figures.of(ridden(group, rideRoute));
        }
      }
    }
    if (groups.isEmpty()) {
      return Figures.of(rideRoute);
    }
    Set<@Nullable Long> riddenRouteIds = new HashSet<>();
    RouteFigures shared = null;
    for (GroupRoute group : groups) {
      RouteFigures ridden = ridden(group, rideRoute);
      riddenRouteIds.add(ridden != null ? ridden.routeId() : null);
      shared = ridden;
    }
    return riddenRouteIds.size() == 1 && shared != null ? Figures.of(shared) : Figures.NONE;
  }

  private static @Nullable RouteFigures ridden(GroupRoute group, @Nullable RouteFigures rideRoute) {
    return group.ownRoute() != null ? group.ownRoute() : rideRoute;
  }
}
