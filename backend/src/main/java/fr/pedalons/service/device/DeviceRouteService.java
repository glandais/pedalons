package fr.pedalons.service.device;

import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.dto.device.response.DeviceRegisteredGroupDto;
import fr.pedalons.dto.device.response.DeviceRideDto;
import fr.pedalons.dto.device.response.DeviceRideEntryDto;
import fr.pedalons.dto.device.response.DeviceRouteDto;
import fr.pedalons.dto.device.response.DeviceRoutesResponse;
import fr.pedalons.dto.device.response.DeviceUserStatusResponse;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.Status;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.repository.common.TeamEntityQueryBasic;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import fr.pedalons.repository.ride.RegisteredGroupRow;
import fr.pedalons.repository.ride.RideParticipationRepository;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.route.RouteQuery;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.InputStream;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

/**
 * Unified service for aggregating routes for device applications (Garmin, Karoo, etc.). Returns
 * upcoming rides (D-1 to D+7) with their route entries, and latest standalone routes independently.
 */
@ApplicationScoped
public class DeviceRouteService {

  private static final int LATEST_ROUTES_PER_TEAM = 10;

  /**
   * Karoo System Service caps HTTP responses at 100KB (see karoo/CLAUDE.md). Per-team limits alone
   * don't bound the response: a user in many teams, or with one very active team, can still blow
   * past that cap once every membership's rides and routes are concatenated. These caps apply to
   * the merged, sorted lists so the payload stays bounded regardless of team count.
   */
  private static final int MAX_RIDES_IN_RESPONSE = 20;

  private static final int MAX_ROUTES_IN_RESPONSE = 20;

  private static final int MAX_REGISTERED_GROUPS_IN_RESPONSE = 20;

  /** A group that left up to this long ago is still listed: the ride may be under way. */
  private static final Duration REGISTERED_GROUPS_PAST = Duration.ofHours(12);

  private static final Duration REGISTERED_GROUPS_AHEAD = Duration.ofDays(7);

  @Inject PedalonsQueryContext pedalonsContext;
  @Inject UserTeamRepository userTeamRepository;
  @Inject RideRepository rideRepository;
  @Inject RouteRepository routeRepository;
  @Inject RideParticipationRepository rideParticipationRepository;
  @Inject GpsServiceConnectionRepository gpsServiceConnectionRepository;
  @Inject GpxProcessingService gpxProcessingService;

  /** Internal record for sorting routes by distance while keeping DTO separate. */
  private record RouteWithDistance(DeviceRouteDto dto, @Nullable Double distanceFromUser) {}

  /**
   * Get rides and routes for the authenticated user. Rides contain route entries from upcoming rides
   * (D-1 to D+7). Routes are the latest standalone routes per team. Both lists are independent.
   *
   * @param lat User's latitude (optional, for proximity sorting)
   * @param lon User's longitude (optional, for proximity sorting)
   * @return Response with rides and routes lists
   */
  @Logged
  public DeviceRoutesResponse getRoutesForUser(@Nullable Double lat, @Nullable Double lon) {
    Long userId = pedalonsContext.getUserId();
    List<UserTeam> memberships = userTeamRepository.findByUserId(userId);

    if (memberships.isEmpty()) {
      return DeviceRoutesResponse.builder()
          .rides(List.of())
          .routes(List.of())
          .registeredGroups(List.of())
          .build();
    }

    Instant now = Instant.now();
    Instant from = now.minus(1, ChronoUnit.DAYS);
    Instant to = now.plus(7, ChronoUnit.DAYS);

    List<DeviceRideDto> allRides = new ArrayList<>();
    List<RouteWithDistance> allRoutes = new ArrayList<>();

    for (UserTeam membership : memberships) {
      Team team = membership.getTeam();
      Long teamId = team.getId();
      Set<Long> teamIds = Set.of(teamId);

      // Rides: D-1 to D+7 with route entries
      List<DeviceRideDto> teamRides = getRidesWithEntries(teamIds, userId, from, to);
      allRides.addAll(teamRides);

      // Routes: latest per team (independent of rides)
      List<RouteWithDistance> teamRoutes = getLatestRoutes(teamIds, userId, lat, lon);
      allRoutes.addAll(teamRoutes);
    }

    // Sort rides by proximity to current time
    allRides.sort(
        Comparator.comparingLong(
            r ->
                r.startDateTime() != null
                    ? Math.abs(r.startDateTime().toEpochMilli() - now.toEpochMilli())
                    : Long.MAX_VALUE));

    // Sort routes by distance from user
    allRoutes.sort(
        Comparator.comparingDouble(
            r -> r.distanceFromUser() != null ? r.distanceFromUser() : Double.MAX_VALUE));

    List<DeviceRouteDto> routes =
        allRoutes.stream().map(RouteWithDistance::dto).collect(Collectors.toList());

    List<DeviceRideDto> boundedRides =
        allRides.size() > MAX_RIDES_IN_RESPONSE
            ? allRides.subList(0, MAX_RIDES_IN_RESPONSE)
            : allRides;
    List<DeviceRouteDto> boundedRoutes =
        routes.size() > MAX_ROUTES_IN_RESPONSE ? routes.subList(0, MAX_ROUTES_IN_RESPONSE) : routes;

    return DeviceRoutesResponse.builder()
        .rides(boundedRides)
        .routes(boundedRoutes)
        .registeredGroups(getRegisteredGroups(userId, now))
        .build();
  }

  /**
   * The groups the user is registered in, leaving between 12 hours ago and 7 days ahead, earliest
   * first, each with the route a device loads for it: the group's own, the ride's when it has none;
   * a group with neither is left out, there is nothing to load. One query whatever their number.
   */
  private List<DeviceRegisteredGroupDto> getRegisteredGroups(Long userId, Instant now) {
    return rideParticipationRepository
        .findUpcomingRegisteredGroups(
            pedalonsContext.getDomainId(),
            userId,
            pedalonsContext.getPinnedTeamIdNullable(),
            now.minus(REGISTERED_GROUPS_PAST),
            now.plus(REGISTERED_GROUPS_AHEAD),
            MAX_REGISTERED_GROUPS_IN_RESPONSE)
        .stream()
        .map(DeviceRouteService::toRegisteredGroup)
        .toList();
  }

  private static DeviceRegisteredGroupDto toRegisteredGroup(RegisteredGroupRow row) {
    // The query only returns rows where one of the two routes is live: the group's wins.
    boolean ownRoute = row.groupRouteSlug() != null;
    String routeSlug = ownRoute ? row.groupRouteSlug() : row.rideRouteSlug();
    String routeName = ownRoute ? row.groupRouteName() : row.rideRouteName();
    Float distance = ownRoute ? row.groupRouteDistance() : row.rideRouteDistance();
    Float elevationGain = ownRoute ? row.groupRouteElevationGain() : row.rideRouteElevationGain();
    return DeviceRegisteredGroupDto.builder()
        .teamSlug(row.teamSlug())
        .rideSlug(row.rideSlug())
        .rideName(row.rideName())
        .groupName(row.groupName())
        .routeSlug(Objects.requireNonNull(routeSlug))
        .routeName(Objects.requireNonNull(routeName))
        .distance(distance != null ? distance : 0f)
        .elevationGain(elevationGain != null ? elevationGain : 0f)
        .startDateTime(row.startAt())
        .timezone(row.timezone())
        .build();
  }

  /**
   * Get user status including connected GPS services.
   *
   * @return User status with list of connected GPS services
   */
  @Logged
  public DeviceUserStatusResponse getUserStatus() {
    Long userId = pedalonsContext.getUserId();
    List<GpsServiceType> connectedServices =
        gpsServiceConnectionRepository.findByUser(userId).stream()
            .map(GpsServiceConnection::getServiceType)
            .toList();
    return DeviceUserStatusResponse.builder().connectedGpsServices(connectedServices).build();
  }

  private List<DeviceRideDto> getRidesWithEntries(
      Set<Long> teamIds, Long userId, Instant from, Instant to) {

    TeamEntityQueryBasic query =
        TeamEntityQueryBasic.builder()
            .domainId(pedalonsContext.getDomainId())
            .pinnedTeamId(pedalonsContext.getPinnedTeamIdNullable())
            .teamIds(teamIds)
            .userId(userId)
            .from(from)
            .to(to)
            .page(0)
            .size(50)
            .includeDeleted(false)
            .platformAdmin(false)
            .build();

    // find(), not findAll(): findAll() ignores page/size entirely (it's meant for callers that
    // genuinely want every match, e.g. the ICS calendar feed), so it would silently return every
    // ride in the window instead of respecting size(50) above.
    List<Ride> rides = rideRepository.find(query).items();

    List<Ride> publishedRides =
        rides.stream().filter(r -> r.getStatus() == Status.PUBLISHED).toList();

    List<DeviceRideDto> result = new ArrayList<>();

    for (Ride ride : publishedRides) {
      List<DeviceRideEntryDto> entries = new ArrayList<>();

      // Ride-level route (groupName = null)
      if (ride.getRoute() != null && !ride.getRoute().isDeleted()) {
        entries.add(toRideEntry(ride.getRoute(), null, ride.getDateTime()));
      }

      // Group-level routes, each from the group's stored start_at — the instant the weather and
      // the stored end read too (docs/LEDGER_*.md API-60).
      for (RideGroup group : ride.getGroups()) {
        Route groupRoute = group.getRoute();
        if (groupRoute == null || groupRoute.isDeleted()) {
          continue;
        }

        entries.add(toRideEntry(groupRoute, group.getName(), group.getStartAt()));
      }

      // Only include rides that have at least one route entry
      if (!entries.isEmpty()) {
        result.add(
            DeviceRideDto.builder()
                .teamSlug(ride.getTeam().getSlug())
                .rideSlug(ride.getSlug())
                .rideName(ride.getName())
                // An absolute instant, as stored: the devices render it in their own zone
                // (docs/LEDGER_*.md API-78). No reading at the departure's local time here.
                .startDateTime(ride.getDateTime())
                // The stored zone, the team's on a row an older backend wrote (docs/LEDGER_*.md
                // API-60).
                .timezone(ride.zone().getId())
                .entries(entries)
                .build());
      }
    }

    return result;
  }

  private DeviceRideEntryDto toRideEntry(
      Route route, @Nullable String groupName, Instant startDateTime) {
    Point<G2D> start = route.getStart();
    G2D position = start.getPosition();

    return DeviceRideEntryDto.builder()
        .routeSlug(route.getSlug())
        .routeName(route.getName())
        .groupName(groupName)
        .distance(route.getDistance())
        .elevationGain(route.getElevationGain())
        .startLat(position.getLat())
        .startLon(position.getLon())
        .startDateTime(startDateTime)
        .build();
  }

  private List<RouteWithDistance> getLatestRoutes(
      Set<Long> teamIds, Long userId, @Nullable Double lat, @Nullable Double lon) {

    RouteQuery query =
        RouteQuery.builder()
            .domainId(pedalonsContext.getDomainId())
            .pinnedTeamId(pedalonsContext.getPinnedTeamIdNullable())
            .teamIds(teamIds)
            .userId(userId)
            .page(0)
            .size(LATEST_ROUTES_PER_TEAM)
            .includeDeleted(false)
            .platformAdmin(false)
            .build();

    // find(), not findAll(): see the comment in getRidesWithEntries — findAll() would ignore
    // size(LATEST_ROUTES_PER_TEAM) and return every published route on the team.
    List<Route> routes = routeRepository.find(query).items();

    return routes.stream()
        .filter(r -> r.getStatus() == Status.PUBLISHED)
        .map(route -> toRouteWithDistance(route, lat, lon))
        .toList();
  }

  private RouteWithDistance toRouteWithDistance(
      Route route, @Nullable Double userLat, @Nullable Double userLon) {

    Point<G2D> start = route.getStart();
    G2D position = start.getPosition();
    double startLat = position.getLat();
    double startLon = position.getLon();

    Double distanceFromUser = null;
    if (userLat != null && userLon != null) {
      distanceFromUser = haversineDistance(userLat, userLon, startLat, startLon);
    }

    DeviceRouteDto dto =
        DeviceRouteDto.builder()
            .teamSlug(route.getTeam().getSlug())
            .routeSlug(route.getSlug())
            .routeName(route.getName())
            .distance(route.getDistance())
            .elevationGain(route.getElevationGain())
            .startLat(startLat)
            .startLon(startLon)
            .build();

    return new RouteWithDistance(dto, distanceFromUser);
  }

  /** Get FIT content for a specific route. */
  @Logged
  public InputStream getFitContent(String teamSlug, String routeSlug) {
    Route route = findRouteBySlug(teamSlug, routeSlug);
    return gpxProcessingService.getFitContent(route);
  }

  /** Get filtered GPX content for a specific route. */
  @Logged
  public InputStream getGpxContent(String teamSlug, String routeSlug) {
    Route route = findRouteBySlug(teamSlug, routeSlug);
    return gpxProcessingService.getFilteredGpxContent(route);
  }

  /** Find a route by team and route slugs, verifying user membership. */
  private Route findRouteBySlug(String teamSlug, String routeSlug) {
    Long userId = pedalonsContext.getUserId();

    // Find team by slug from user's memberships
    List<UserTeam> memberships = userTeamRepository.findByUserId(userId);
    Team team =
        memberships.stream()
            .map(UserTeam::getTeam)
            .filter(t -> t.getSlug().equals(teamSlug))
            .findFirst()
            .orElseThrow(() -> new NotFoundException(EntityType.TEAM, teamSlug));

    // Find route (domainId from team for multi-tenant isolation)
    Long domainId = team.getDomain().getId();
    return routeRepository
        .findByTeamAndSlug(domainId, team.getId(), userId, routeSlug, false, false)
        .orElseThrow(() -> new NotFoundException(EntityType.ROUTE, routeSlug));
  }

  /** Calculate Haversine distance between two points in meters. */
  private double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    final double R = 6371000; // Earth radius in meters

    double dLat = Math.toRadians(lat2 - lat1);
    double dLon = Math.toRadians(lon2 - lon1);

    double a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2)
                * Math.sin(dLon / 2);

    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }
}
