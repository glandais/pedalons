package fr.pedalons.service.common;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.IncompatibleRouteDto;
import fr.pedalons.dto.error.IncompatibleRouteUsageDto;
import fr.pedalons.dto.error.IncompatibleVisibilityDetails;
import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Visibility;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;
import org.jspecify.annotations.Nullable;

/**
 * The one rule tying the visibility of a ride or a trip to the visibility of its routes
 * (docs/LEDGER_*.md API-176, plan §4.4): <b>a container that is not {@code TEAM} only uses routes
 * that are not {@code TEAM}.</b> The containers and their routes are {@code Ride.route}, {@code
 * RideGroup.route}, {@code Trip.route} and {@code TripStage.route}; a stage has its trip's
 * visibility, a ride template has no route, a place no visibility.
 *
 * <p>Held here, in both directions, and nowhere else:
 *
 * <ul>
 *   <li><b>Saving a ride or a trip</b> ({@link #fitRoutes}): creation, update and restore. A
 *       {@code TEAM} route under a container that is not {@code TEAM} is refused with {@link
 *       ErrorCode#INCOMPATIBLE_VISIBILITY}, listing the routes; with {@code alignVisibility} they
 *       are raised to {@link #ALIGNED_VISIBILITY} in the same transaction (decision D5).
 *   <li><b>Saving a route as {@code TEAM}</b> ({@link #requireNoNonTeamUse}): refused when a ride
 *       or a trip that is not {@code TEAM} and not deleted uses it, listing those usages. No
 *       alignment this way: a ride is never closed by ricochet (decision D6). A draft counts — it
 *       will be published as it is; a deleted container does not, and its restore comes back
 *       through {@link #fitRoutes}.
 *   <li><b>The route's {@code permissions.allowedVisibilities}</b> on a detail ({@link
 *       #routesInNonTeamUse}, {@link #allowedForRoute}): {@code TEAM} is left out exactly when the
 *       save above would refuse it, so an editor offers what the server accepts.
 * </ul>
 *
 * <p>Not here: a team going private ({@code TeamService.makeContentTeamOnly}) turns every container
 * and every route of the team {@code TEAM} in one statement, which keeps the invariant without
 * asking anything.
 */
@ApplicationScoped
public class RouteVisibilityCompatibility {

  /**
   * What an aligned route is raised to: the lowest visibility that satisfies the invariant, even
   * under a {@code PUBLIC} container — a route never becomes {@code PUBLIC} without an explicit
   * decision (plan §3).
   */
  public static final Visibility ALIGNED_VISIBILITY = Visibility.PUBLIC_UNLISTED;

  @Inject EntityManager entityManager;

  @Inject ContentVisibilityRules contentVisibilityRules;

  /** A ride or a trip that is not {@code TEAM} using one of the routes asked about. */
  public record RouteUse(
      Long routeId, PublicationType type, String slug, String name, Visibility visibility) {}

  /** Whether a container of {@code containerVisibility} may use a route of {@code route}. */
  public static boolean compatible(Visibility containerVisibility, Visibility routeVisibility) {
    return containerVisibility == Visibility.TEAM || routeVisibility != Visibility.TEAM;
  }

  /**
   * Makes the routes of a ride or a trip fit the visibility it is saved with.
   *
   * <p>Refuses while any of them is {@code TEAM} under a container that is not; with {@code align},
   * raises them to {@link #ALIGNED_VISIBILITY} instead — only routes of {@code team}, and only when
   * the team accepts that visibility for routes ({@link ContentVisibilityRules}; it does whenever it
   * accepted the container's, the rule being the same for both types). A route of another team, or
   * a deleted one, is never touched: the request is refused as if {@code align} were false. Nothing
   * is written before every check has passed.
   *
   * <p>The routes are locked first, and their visibility read as committed ({@link
   * #lockedVisibilities}), so this check and {@link
   * #requireNoNonTeamUse}, which runs under the same lock in {@code RouteService.updateRoute}, never
   * interleave: without it a ride raised without alignment, which only reads its routes, and a route
   * lowered at the same time would both pass and commit a public ride on a {@code TEAM} route.
   *
   * @param routes the container's own route and those of its live groups or stages, nulls allowed
   * @throws BusinessException {@link ErrorCode#INCOMPATIBLE_VISIBILITY}, or {@link
   *     ErrorCode#INVALID_VISIBILITY} when the team would not accept the aligned visibility
   */
  @Transactional
  public void fitRoutes(
      Team team,
      Visibility containerVisibility,
      Collection<? extends @Nullable Route> routes,
      boolean align) {
    if (containerVisibility == Visibility.TEAM) {
      return;
    }
    Map<Long, Visibility> current = lockedVisibilities(routes);
    Map<Long, Route> misfits = new LinkedHashMap<>();
    for (Route route : routes) {
      if (route != null
          && !compatible(
              containerVisibility, current.getOrDefault(route.getId(), route.getVisibility()))) {
        misfits.putIfAbsent(route.getId(), route);
      }
    }
    if (misfits.isEmpty()) {
      return;
    }
    boolean alignable =
        misfits.values().stream()
            .allMatch(route ->
                !route.isDeleted() && Objects.equals(route.getTeam().getId(), team.getId()));
    if (!align || !alignable) {
      throw new BusinessException(
          ErrorCode.INCOMPATIBLE_VISIBILITY,
          IncompatibleVisibilityDetails.ofRoutes(
              misfits.values().stream()
                  .sorted(Comparator.comparing(Route::getName).thenComparing(Route::getSlug))
                  .map(route ->
                      new IncompatibleRouteDto(
                          route.getSlug(),
                          route.getName(),
                          current.getOrDefault(route.getId(), route.getVisibility()),
                          ALIGNED_VISIBILITY))
                  .toList()),
          null);
    }
    contentVisibilityRules.requireAllowed(team, EntityType.ROUTE, ALIGNED_VISIBILITY);
    misfits.values().forEach(route -> route.setVisibility(ALIGNED_VISIBILITY));
  }

  /**
   * Locks the rows of {@code routes} ({@code SELECT … FOR UPDATE}) until the end of the transaction,
   * in id order so that two saves sharing routes cannot deadlock, and returns their visibility as
   * committed. The row lock is the one {@code RouteService.updateRoute} takes: a save waits for a
   * route update in flight, then reads the visibility it left rather than the one loaded before
   * (docs/LEDGER_*.md API-176). A native query rather than {@code lock()} or {@code refresh()}: the
   * routes may be detached, and a refresh would cascade to their tracks and waypoints.
   */
  private Map<Long, Visibility> lockedVisibilities(Collection<? extends @Nullable Route> routes) {
    Set<Long> ids = new TreeSet<>();
    routes.stream().filter(Objects::nonNull).forEach(route -> ids.add(route.getId()));
    Map<Long, Visibility> visibilities = new HashMap<>();
    if (ids.isEmpty()) {
      return visibilities;
    }
    @SuppressWarnings("unchecked")
    List<Object[]> rows =
        entityManager
            .createNativeQuery(
                "select id, visibility from team_entities where id in (:ids) order by id"
                    + " for update")
            .setParameter("ids", ids)
            .getResultList();
    for (Object[] row : rows) {
      visibilities.put(((Number) row[0]).longValue(), Visibility.valueOf((String) row[1]));
    }
    return visibilities;
  }

  /**
   * Refuses to save {@code route} as {@code newVisibility} when that is {@code TEAM} and a ride or
   * a trip that is not {@code TEAM} and not deleted uses it. Checked whatever the route's visibility
   * before: a route left {@code TEAM} under a public ride by an older release is not saved as it is
   * either, which is what its {@code allowedVisibilities} says.
   *
   * @throws BusinessException {@link ErrorCode#INCOMPATIBLE_VISIBILITY}, listing the usages
   */
  public void requireNoNonTeamUse(Route route, Visibility newVisibility) {
    if (newVisibility != Visibility.TEAM) {
      return;
    }
    List<RouteUse> uses = nonTeamUses(List.of(route.getId()));
    if (uses.isEmpty()) {
      return;
    }
    throw new BusinessException(
        ErrorCode.INCOMPATIBLE_VISIBILITY,
        IncompatibleVisibilityDetails.ofUsages(
            uses.stream()
                .map(use ->
                    new IncompatibleRouteUsageDto(
                        use.type(), use.slug(), use.name(), use.visibility()))
                .toList()),
        null);
  }

  /**
   * The routes among {@code routeIds} that a ride or a trip that is not {@code TEAM} uses — those
   * that may not go {@code TEAM}. Four queries whatever the number of routes: for a detail or a
   * batch of details, never once per row.
   */
  public Set<Long> routesInNonTeamUse(Collection<Long> routeIds) {
    Set<Long> used = new HashSet<>();
    nonTeamUses(routeIds).forEach(use -> used.add(use.routeId()));
    return used;
  }

  /**
   * {@code accepted}, the team's list for routes, without {@code TEAM} when the route is used by a
   * container that is not {@code TEAM}: what {@link #requireNoNonTeamUse} lets through. May be
   * empty — a private team whose {@code publicContentAllowed} was withdrawn accepts only {@code
   * TEAM}, which its public usages forbid: the route cannot be saved until they go {@code TEAM}.
   */
  public static List<Visibility> allowedForRoute(List<Visibility> accepted, boolean inNonTeamUse) {
    return inNonTeamUse
        ? accepted.stream().filter(visibility -> visibility != Visibility.TEAM).toList()
        : accepted;
  }

  /**
   * Every ride and trip, not {@code TEAM} and not deleted, using one of {@code routeIds}: by its own
   * route, a group's, its trip route or a live stage's. One entry per route and container, sorted by
   * type then name. Not filtered by team or domain: a route is its team's, and whichever container
   * uses it is what the invariant is about.
   */
  public List<RouteUse> nonTeamUses(Collection<Long> routeIds) {
    if (routeIds.isEmpty()) {
      return List.of();
    }
    Map<String, RouteUse> uses = new LinkedHashMap<>();
    collect(
        uses,
        PublicationType.RIDE,
        "select r.route.id, r.slug, r.name, r.visibility from Ride r"
            + " where r.route.id in :routeIds and r.deleted = false and r.visibility <> :team",
        routeIds);
    collect(
        uses,
        PublicationType.RIDE,
        "select g.route.id, r.slug, r.name, r.visibility from RideGroup g join g.ride r"
            + " where g.route.id in :routeIds and r.deleted = false and r.visibility <> :team",
        routeIds);
    collect(
        uses,
        PublicationType.TRIP,
        "select t.route.id, t.slug, t.name, t.visibility from Trip t"
            + " where t.route.id in :routeIds and t.deleted = false and t.visibility <> :team",
        routeIds);
    // A stage dropped from its trip is soft-deleted (TripService.updateTrip): it uses nothing.
    collect(
        uses,
        PublicationType.TRIP,
        "select s.route.id, t.slug, t.name, t.visibility from TripStage s join s.trip t"
            + " where s.route.id in :routeIds and s.deleted = false and t.deleted = false"
            + " and t.visibility <> :team",
        routeIds);
    List<RouteUse> sorted = new ArrayList<>(uses.values());
    sorted.sort(
        Comparator.comparing(RouteUse::type)
            .thenComparing(RouteUse::name)
            .thenComparing(RouteUse::slug));
    return sorted;
  }

  private void collect(
      Map<String, RouteUse> uses, PublicationType type, String query, Collection<Long> routeIds) {
    List<Object[]> rows =
        entityManager
            .createQuery(query, Object[].class)
            .setParameter("routeIds", routeIds)
            .setParameter("team", Visibility.TEAM)
            .getResultList();
    for (Object[] row : rows) {
      RouteUse use =
          new RouteUse((Long) row[0], type, (String) row[1], (String) row[2], (Visibility) row[3]);
      uses.putIfAbsent(use.routeId() + "/" + type + "/" + use.slug(), use);
    }
  }
}
