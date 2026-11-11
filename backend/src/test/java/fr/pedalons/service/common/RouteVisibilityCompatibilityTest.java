package fr.pedalons.service.common;

import static fr.pedalons.util.WallTimes.wall;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.IncompatibleRouteDto;
import fr.pedalons.dto.error.IncompatibleRouteUsageDto;
import fr.pedalons.dto.error.IncompatibleVisibilityDetails;
import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.rides.response.RideDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDetailDto;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.dto.teams.request.TeamRequest;
import fr.pedalons.dto.trips.request.StageRequest;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.dto.trips.response.TripDto;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.ride.RideService;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.team.TeamService;
import fr.pedalons.service.trip.TripService;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

/**
 * The invariant of docs/LEDGER_*.md API-176, plan §4.4 — a ride or a trip that is not {@code TEAM}
 * only uses routes that are not {@code TEAM} — in both directions, through the services that write
 * it: raising a container (refused with the routes, then aligned with {@code alignVisibility},
 * decision D5), lowering a route (refused with the usages, never aligned, decision D6), restoring a
 * container, the route detail's {@code allowedVisibilities}, and the team going private.
 */
@QuarkusTest
class RouteVisibilityCompatibilityTest extends AbstractBaseTest {

  private static final List<Visibility> ALL =
      List.of(Visibility.TEAM, Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC);
  private static final List<Visibility> NOT_TEAM =
      List.of(Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC);

  @Inject RouteVisibilityCompatibility compatibility;
  @Inject RideService rideService;
  @Inject TripService tripService;
  @Inject RouteService routeService;
  @Inject TeamService teamService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  private Team team;
  private Team otherTeam;
  private User admin;
  private User organizer;
  private Instant soon;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    organizer = dataService.createUser("organizer@example.com", "Organizer");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    dataService.addUserToTeam(organizer, team, TeamRole.ORGANIZER);
    User otherAdmin = dataService.createUser("other@example.com", "Other");
    otherTeam = dataService.createTeam(otherAdmin, "Other Team", "other-team", Visibility.PUBLIC);
    soon = Instant.now().plus(7, ChronoUnit.DAYS);
  }

  // ==================== Requests ====================

  private static RideRequest rideRequest(
      String name,
      Visibility visibility,
      @Nullable String routeSlug,
      List<GroupRequest> groups,
      @Nullable Boolean align) {
    return new RideRequest(
        name,
        MediaDto.builder().build(),
        wall(Instant.now().plus(7, ChronoUnit.DAYS)),
        Status.PUBLISHED,
        visibility,
        routeSlug,
        null,
        null,
        null,
        groups,
        null,
        null,
        align);
  }

  private static GroupRequest group(String name, @Nullable String routeSlug) {
    return GroupRequest.builder().name(name).routeSlug(routeSlug).build();
  }

  private static TripRequest tripRequest(
      String name,
      Visibility visibility,
      @Nullable String routeSlug,
      List<StageRequest> stages,
      @Nullable Boolean align) {
    return new TripRequest(
        name,
        MediaDto.builder().build(),
        wall(Instant.now().plus(7, ChronoUnit.DAYS)),
        Status.PUBLISHED,
        visibility,
        routeSlug,
        null,
        stages,
        null,
        align);
  }

  private static StageRequest stage(String name, @Nullable String routeSlug) {
    return StageRequest.builder()
        .name(name)
        .dateTime(wall(Instant.now().plus(7, ChronoUnit.DAYS)))
        .routeSlug(routeSlug)
        .media(MediaDto.builder().build())
        .build();
  }

  private static RouteRequest routeRequest(String name, Visibility visibility) {
    return new RouteRequest(
        name, MediaDto.builder().build(), SurfaceType.ROAD, visibility, List.of());
  }

  private static IncompatibleVisibilityDetails details(PedalonsException e) {
    assertEquals(ErrorCode.INCOMPATIBLE_VISIBILITY, e.getErrorCode());
    return (IncompatibleVisibilityDetails) e.getErrorDetails();
  }

  private static IncompatibleRouteDto misfit(Route route) {
    return new IncompatibleRouteDto(
        route.getSlug(), route.getName(), Visibility.TEAM, Visibility.PUBLIC_UNLISTED);
  }

  private static IncompatibleRouteUsageDto usage(
      PublicationType type, String slug, String name, Visibility visibility) {
    return new IncompatibleRouteUsageDto(type, slug, name, visibility);
  }

  // ==================== Raising a ride or a trip (D5) ====================

  @Nested
  class RaisingAContainer {

    @Test
    void aRideRaisedWithATeamRoute_isRefusedWithTheRoute_thenAlignedToUnlisted() {
      Route route = dataService.createRoute(team, admin, "Members Loop", Visibility.TEAM);
      queryContext.setUserForTest(organizer);
      RideDto created =
          rideService.createRide(
              team.getSlug(),
              rideRequest("Team Ride", Visibility.TEAM, route.getSlug(), List.of(), null));

      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () ->
                  rideService.updateRide(
                      team.getSlug(),
                      created.getSlug(),
                      rideRequest(
                          "Team Ride", Visibility.PUBLIC, route.getSlug(), List.of(), null)));
      IncompatibleVisibilityDetails details = details(refused);
      assertEquals(List.of(misfit(route)), details.getRoutes());
      assertTrue(details.getUsages().isEmpty());
      // Nothing written: the ride stays TEAM, the route too.
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
      assertEquals(
          Visibility.TEAM, rideService.getDto(team.getSlug(), created.getSlug()).getVisibility());

      RideDto aligned =
          rideService.updateRide(
              team.getSlug(),
              created.getSlug(),
              rideRequest("Team Ride", Visibility.PUBLIC, route.getSlug(), List.of(), true));
      assertEquals(Visibility.PUBLIC, aligned.getVisibility());
      // PUBLIC_UNLISTED under a PUBLIC ride: a route never becomes PUBLIC without a decision.
      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(route));
    }

    @Test
    void aRideCreatedWithATeamGroupRoute_isRefused_thenAligned() {
      Route own = dataService.createRoute(team, admin, "Open Loop", Visibility.PUBLIC);
      Route members = dataService.createRoute(team, admin, "Group Loop", Visibility.TEAM);
      List<GroupRequest> groups =
          List.of(group("Fast", members.getSlug()), group("Slow", members.getSlug()));
      queryContext.setUserForTest(organizer);

      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () ->
                  rideService.createRide(
                      team.getSlug(),
                      rideRequest("Public Ride", Visibility.PUBLIC, own.getSlug(), groups, null)));
      // Once, though two groups ride it; the PUBLIC route is not at fault.
      assertEquals(List.of(misfit(members)), details(refused).getRoutes());
      assertEquals(Visibility.TEAM, dataService.routeVisibility(members));

      RideDto created =
          rideService.createRide(
              team.getSlug(),
              rideRequest("Public Ride", Visibility.PUBLIC, own.getSlug(), groups, true));
      assertEquals(Visibility.PUBLIC, created.getVisibility());
      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(members));
      assertEquals(Visibility.PUBLIC, dataService.routeVisibility(own));
    }

    @Test
    void anUnlistedRide_withATeamRoute_isRefusedAsWell() {
      Route route = dataService.createRoute(team, admin, "Members Loop", Visibility.TEAM);
      queryContext.setUserForTest(organizer);
      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () ->
                  rideService.createRide(
                      team.getSlug(),
                      rideRequest(
                          "Unlisted",
                          Visibility.PUBLIC_UNLISTED,
                          route.getSlug(),
                          List.of(),
                          false)));
      assertEquals(List.of(misfit(route)), details(refused).getRoutes());
    }

    @Test
    void attachingATeamRoute_toAnAlreadyPublicRide_isRefused() {
      Ride ride =
          dataService.createRide(
              team, admin, "Public Ride", "public-ride", soon, Visibility.PUBLIC);
      dataService.createRideGroup(admin, ride, "Group");
      Route route = dataService.createRoute(team, admin, "Members Loop", Visibility.TEAM);
      queryContext.setUserForTest(organizer);

      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () ->
                  rideService.updateRide(
                      team.getSlug(),
                      ride.getSlug(),
                      rideRequest(
                          "Public Ride",
                          Visibility.PUBLIC,
                          null,
                          List.of(group("New group", route.getSlug())),
                          null)));
      assertEquals(List.of(misfit(route)), details(refused).getRoutes());
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
    }

    @Test
    void aTripCreatedWithATeamRoute_isRefused_thenAligned() {
      Route route = dataService.createRoute(team, admin, "Trip Line", Visibility.TEAM);
      queryContext.setUserForTest(organizer);

      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () ->
                  tripService.createTrip(
                      team.getSlug(),
                      tripRequest(
                          "Public Trip", Visibility.PUBLIC, route.getSlug(), List.of(), null)));
      assertEquals(List.of(misfit(route)), details(refused).getRoutes());
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));

      TripDto created =
          tripService.createTrip(
              team.getSlug(),
              tripRequest("Public Trip", Visibility.PUBLIC, route.getSlug(), List.of(), true));
      assertEquals(Visibility.PUBLIC, created.getVisibility());
      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(route));
    }

    @Test
    void aTripRaisedWithATeamStageRoute_isRefused_thenAligned() {
      Route stageRoute = dataService.createRoute(team, admin, "Day One", Visibility.TEAM);
      Route tripRoute = dataService.createRoute(team, admin, "Whole Line", Visibility.TEAM);
      queryContext.setUserForTest(organizer);
      TripDto created =
          tripService.createTrip(
              team.getSlug(),
              tripRequest(
                  "Team Trip",
                  Visibility.TEAM,
                  tripRoute.getSlug(),
                  List.of(stage("Day 1", stageRoute.getSlug())),
                  null));
      String stageId = created.getStages().getFirst().id();
      StageRequest sameStage =
          StageRequest.builder()
              .id(stageId)
              .name("Day 1")
              .dateTime(wall(Instant.now().plus(7, ChronoUnit.DAYS)))
              .routeSlug(stageRoute.getSlug())
              .media(MediaDto.builder().build())
              .build();

      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () ->
                  tripService.updateTrip(
                      team.getSlug(),
                      created.getSlug(),
                      tripRequest(
                          "Team Trip",
                          Visibility.PUBLIC_UNLISTED,
                          tripRoute.getSlug(),
                          List.of(sameStage),
                          null)));
      // Both, sorted by name.
      assertEquals(List.of(misfit(stageRoute), misfit(tripRoute)), details(refused).getRoutes());

      TripDto aligned =
          tripService.updateTrip(
              team.getSlug(),
              created.getSlug(),
              tripRequest(
                  "Team Trip",
                  Visibility.PUBLIC_UNLISTED,
                  tripRoute.getSlug(),
                  List.of(sameStage),
                  true));
      assertEquals(Visibility.PUBLIC_UNLISTED, aligned.getVisibility());
      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(stageRoute));
      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(tripRoute));
    }

    @Test
    void aTeamRide_takesTeamRoutes_andAlignTouchesNothing() {
      Route route = dataService.createRoute(team, admin, "Members Loop", Visibility.TEAM);
      queryContext.setUserForTest(organizer);
      rideService.createRide(
          team.getSlug(),
          rideRequest("Team Ride", Visibility.TEAM, route.getSlug(), List.of(), true));
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
    }

    /** Routes are looked up in the ride's team: another team's route of the same slug stays put. */
    @Test
    void anAlignment_neverTouchesAnotherTeamsRoute() {
      Route own = dataService.createRoute(team, admin, "Shared Name", Visibility.TEAM);
      Route foreign = dataService.createRoute(otherTeam, admin, "Shared Name", Visibility.TEAM);
      assertEquals(own.getSlug(), foreign.getSlug());
      queryContext.setUserForTest(organizer);

      rideService.createRide(
          team.getSlug(),
          rideRequest("Public Ride", Visibility.PUBLIC, own.getSlug(), List.of(), true));

      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(own));
      assertEquals(Visibility.TEAM, dataService.routeVisibility(foreign));
    }

    /** The component itself: a route of another team is refused, never raised. */
    @Test
    void fitRoutes_refusesAnotherTeamsRoute_evenWithAlign() {
      Route foreign = dataService.createRoute(otherTeam, admin, "Foreign", Visibility.TEAM);
      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () -> compatibility.fitRoutes(team, Visibility.PUBLIC, List.of(foreign), true));
      assertEquals(List.of(misfit(foreign)), details(refused).getRoutes());
      assertEquals(Visibility.TEAM, foreign.getVisibility());
      assertEquals(Visibility.TEAM, dataService.routeVisibility(foreign));
    }

    /**
     * A deleted route is never raised: an admin may still name one, but the request is refused as
     * if align were false, the route left as it is.
     */
    @Test
    void fitRoutes_neverRaisesADeletedRoute() {
      Route route = dataService.createRoute(team, admin, "Gone Loop", Visibility.TEAM);
      dataService.deleteRoute(route);
      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () -> compatibility.fitRoutes(team, Visibility.PUBLIC, List.of(route), true));
      assertEquals(List.of(misfit(route)), details(refused).getRoutes());
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
    }

    /**
     * The check reads the routes' visibility as committed, under a row lock, not the one loaded
     * with them: a route lowered since it was read is seen as TEAM.
     */
    @Test
    void fitRoutes_readsTheCommittedVisibility_notTheLoadedOne() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC_UNLISTED);
      dataService.setRouteVisibility(route, Visibility.TEAM);
      // The instance at hand still says PUBLIC_UNLISTED.
      assertEquals(Visibility.PUBLIC_UNLISTED, route.getVisibility());
      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () -> compatibility.fitRoutes(team, Visibility.PUBLIC, List.of(route), false));
      assertEquals(List.of(misfit(route)), details(refused).getRoutes());
    }

    /** Aligning asks the team's rule for routes: a team that accepts only TEAM refuses it. */
    @Test
    void fitRoutes_askTheTeamsRuleBeforeRaising() {
      Team closed = dataService.createTeam(admin, "Closed", "closed", Visibility.TEAM);
      Route route = dataService.createRoute(closed, admin, "Closed Loop", Visibility.TEAM);
      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () -> compatibility.fitRoutes(closed, Visibility.PUBLIC, List.of(route), true));
      assertEquals(ErrorCode.INVALID_VISIBILITY, refused.getErrorCode());
      assertEquals(Visibility.TEAM, route.getVisibility());
    }

    /** A private team with publicContentAllowed publishes a ride by link and aligns its route. */
    @Test
    void aPrivateTeamWithTheFlag_alignsItsRouteToUnlisted() {
      Team closed = dataService.createTeam(admin, "Closed", "closed", Visibility.TEAM);
      dataService.addUserToTeam(organizer, closed, TeamRole.ORGANIZER);
      dataService.setTeamPublicContentAllowed(closed, true);
      Route route = dataService.createRoute(closed, admin, "Closed Loop", Visibility.TEAM);
      queryContext.setUserForTest(organizer);

      RideDto created =
          rideService.createRide(
              closed.getSlug(),
              rideRequest("By Link", Visibility.PUBLIC, route.getSlug(), List.of(), true));
      assertEquals(Visibility.PUBLIC, created.getVisibility());
      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(route));
    }
  }

  // ==================== Lowering a route (D6) ====================

  @Nested
  class LoweringARoute {

    private void lower(Route route) {
      routeService.updateRoute(
          team.getSlug(), route.getSlug(), routeRequest(route.getName(), Visibility.TEAM), null);
    }

    private IncompatibleVisibilityDetails refusedLowering(Route route) {
      queryContext.setUserForTest(organizer);
      PedalonsException refused = assertThrows(PedalonsException.class, () -> lower(route));
      // Never closed by ricochet: the route stays as it was.
      assertEquals(Visibility.PUBLIC, dataService.routeVisibility(route));
      IncompatibleVisibilityDetails details = details(refused);
      assertTrue(details.getRoutes().isEmpty());
      return details;
    }

    @Test
    void usedByAPublicRide_isRefusedWithTheRide() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Sunday", "sunday", soon, Visibility.PUBLIC);
      dataService.setRideRoute(ride, route);

      assertEquals(
          List.of(usage(PublicationType.RIDE, "sunday", "Sunday", Visibility.PUBLIC)),
          refusedLowering(route).getUsages());
    }

    @Test
    void usedByADraftUnlistedRide_isRefused() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride =
          dataService.createRide(
              team, admin, "Draft", "draft", soon, Visibility.PUBLIC_UNLISTED, Status.DRAFT);
      dataService.setRideRoute(ride, route);

      assertEquals(
          List.of(usage(PublicationType.RIDE, "draft", "Draft", Visibility.PUBLIC_UNLISTED)),
          refusedLowering(route).getUsages());
    }

    @Test
    void usedByAGroupOfAPublicRide_isRefused() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Sunday", "sunday", soon, Visibility.PUBLIC);
      dataService.setRideGroupRoute(dataService.createRideGroup(admin, ride, "Fast"), route);
      RideGroup second = dataService.createRideGroup(admin, ride, "Slow", 1);
      dataService.setRideGroupRoute(second, route);
      // The ride's own route too: still one usage.
      dataService.setRideRoute(ride, route);

      assertEquals(
          List.of(usage(PublicationType.RIDE, "sunday", "Sunday", Visibility.PUBLIC)),
          refusedLowering(route).getUsages());
    }

    @Test
    void usedByAPublicTrip_isRefused() {
      Route route = dataService.createRoute(team, admin, "Line", Visibility.PUBLIC);
      Trip trip = dataService.createTrip(team, admin, "Summer Tour", soon, Visibility.PUBLIC);
      dataService.setTripRoute(trip, route);

      assertEquals(
          List.of(usage(PublicationType.TRIP, trip.getSlug(), "Summer Tour", Visibility.PUBLIC)),
          refusedLowering(route).getUsages());
    }

    @Test
    void usedByAStageOfAPublicTrip_isRefused_butNotByADroppedStage() {
      Route route = dataService.createRoute(team, admin, "Day One", Visibility.PUBLIC);
      Trip trip = dataService.createTrip(team, admin, "Summer Tour", soon, Visibility.PUBLIC);
      TripStage stage = dataService.createTripStage(admin, trip, "Day 1", 0);
      dataService.setTripStageRoute(stage, route);

      assertEquals(
          List.of(usage(PublicationType.TRIP, trip.getSlug(), "Summer Tour", Visibility.PUBLIC)),
          refusedLowering(route).getUsages());

      dataService.deleteTripStage(stage);
      lower(route);
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
    }

    @Test
    void usedByRidesAndTrips_listsEveryUsage_ridesFirst() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride b = dataService.createRide(team, admin, "B ride", "b-ride", soon, Visibility.PUBLIC);
      Ride a = dataService.createRide(team, admin, "A ride", "a-ride", soon, Visibility.PUBLIC);
      Trip trip = dataService.createTrip(team, admin, "Tour", soon, Visibility.PUBLIC_UNLISTED);
      dataService.setRideRoute(b, route);
      dataService.setRideRoute(a, route);
      dataService.setTripRoute(trip, route);

      assertEquals(
          List.of(
              usage(PublicationType.RIDE, "a-ride", "A ride", Visibility.PUBLIC),
              usage(PublicationType.RIDE, "b-ride", "B ride", Visibility.PUBLIC),
              usage(PublicationType.TRIP, trip.getSlug(), "Tour", Visibility.PUBLIC_UNLISTED)),
          refusedLowering(route).getUsages());
    }

    @Test
    void usedByADeletedRide_isAccepted() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Gone", "gone", soon, Visibility.PUBLIC);
      dataService.setRideRoute(ride, route);
      dataService.deleteRide(ride);

      queryContext.setUserForTest(organizer);
      lower(route);
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
    }

    @Test
    void usedByADeletedTrip_isAccepted() {
      Route route = dataService.createRoute(team, admin, "Line", Visibility.PUBLIC);
      Trip trip = dataService.createTrip(team, admin, "Gone Tour", soon, Visibility.PUBLIC);
      dataService.setTripStageRoute(dataService.createTripStage(admin, trip, "Day 1", 0), route);
      dataService.deleteTrip(trip);

      queryContext.setUserForTest(organizer);
      lower(route);
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
    }

    @Test
    void usedByATeamRide_isAccepted() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Members", "members", soon, Visibility.TEAM);
      dataService.setRideRoute(ride, route);

      queryContext.setUserForTest(organizer);
      lower(route);
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
    }

    /** A TEAM route an older release left under a public ride is not saved as TEAM again. */
    @Test
    void aTeamRouteAlreadyUnderAPublicRide_cannotBeSavedAsTeam() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Sunday", "sunday", soon, Visibility.PUBLIC);
      dataService.setRideRoute(ride, route);
      dataService.setRouteVisibility(route, Visibility.TEAM);

      queryContext.setUserForTest(organizer);
      PedalonsException refused = assertThrows(PedalonsException.class, () -> lower(route));
      assertEquals(
          List.of(usage(PublicationType.RIDE, "sunday", "Sunday", Visibility.PUBLIC)),
          details(refused).getUsages());
      // Raising it is always accepted.
      routeService.updateRoute(
          team.getSlug(), route.getSlug(), routeRequest("Loop", Visibility.PUBLIC_UNLISTED), null);
      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(route));
    }
  }

  // ==================== Restoring a container ====================

  @Nested
  class Restoring {

    @Test
    void aPublicRide_whoseRouteWentTeamWhileDeleted_isRefused_untilTheRouteIsRaised() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Sunday", "sunday", soon, Visibility.PUBLIC);
      dataService.setRideGroupRoute(dataService.createRideGroup(admin, ride, "Fast"), route);
      queryContext.setUserForTest(organizer);
      rideService.deleteRide(team.getSlug(), ride.getSlug());
      // Deleted, the ride holds nothing back.
      routeService.updateRoute(
          team.getSlug(), route.getSlug(), routeRequest("Loop", Visibility.TEAM), null);

      // A deleted ride is found by an admin only (IncludeDeletedService): restoring is theirs.
      queryContext.setUserForTest(admin);
      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () -> rideService.undeleteRide(team.getSlug(), ride.getSlug()));
      assertEquals(List.of(misfit(route)), details(refused).getRoutes());
      assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
      assertTrue(dataService.getRide(ride.getId()).isDeleted());

      routeService.updateRoute(
          team.getSlug(), route.getSlug(), routeRequest("Loop", Visibility.PUBLIC_UNLISTED), null);
      RideDto restored = rideService.undeleteRide(team.getSlug(), ride.getSlug());
      assertFalse(restored.isDeleted());
    }

    @Test
    void aPublicTrip_whoseStageRouteWentTeamWhileDeleted_isRefused() {
      Route route = dataService.createRoute(team, admin, "Day One", Visibility.PUBLIC);
      Trip trip = dataService.createTrip(team, admin, "Summer Tour", soon, Visibility.PUBLIC);
      dataService.setTripStageRoute(dataService.createTripStage(admin, trip, "Day 1", 0), route);
      queryContext.setUserForTest(organizer);
      tripService.deleteTrip(team.getSlug(), trip.getSlug());
      routeService.updateRoute(
          team.getSlug(), route.getSlug(), routeRequest("Day One", Visibility.TEAM), null);

      queryContext.setUserForTest(admin);
      PedalonsException refused =
          assertThrows(
              PedalonsException.class,
              () -> tripService.undeleteTrip(team.getSlug(), trip.getSlug()));
      assertEquals(List.of(misfit(route)), details(refused).getRoutes());
    }

    /** A stage dropped from the trip uses nothing: its TEAM route does not hold the restore. */
    @Test
    void aPublicTrip_withADroppedStageOnATeamRoute_isRestored() {
      Route kept = dataService.createRoute(team, admin, "Day One", Visibility.PUBLIC);
      Route dropped = dataService.createRoute(team, admin, "Day Two", Visibility.PUBLIC);
      Trip trip = dataService.createTrip(team, admin, "Summer Tour", soon, Visibility.PUBLIC);
      dataService.setTripStageRoute(dataService.createTripStage(admin, trip, "Day 1", 0), kept);
      TripStage stage = dataService.createTripStage(admin, trip, "Day 2", 1);
      dataService.setTripStageRoute(stage, dropped);
      dataService.deleteTripStage(stage);
      queryContext.setUserForTest(organizer);
      tripService.deleteTrip(team.getSlug(), trip.getSlug());
      dataService.setRouteVisibility(dropped, Visibility.TEAM);

      queryContext.setUserForTest(admin);
      assertFalse(tripService.undeleteTrip(team.getSlug(), trip.getSlug()).isDeleted());
    }

    @Test
    void aTeamRide_isRestoredWhateverItsRoutes() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.TEAM);
      Ride ride = dataService.createRide(team, admin, "Members", "members", soon, Visibility.TEAM);
      dataService.setRideRoute(ride, route);
      dataService.deleteRide(ride);

      queryContext.setUserForTest(admin);
      assertFalse(rideService.undeleteRide(team.getSlug(), ride.getSlug()).isDeleted());
    }
  }

  // ==================== allowedVisibilities of the route detail ====================

  @Nested
  class AllowedVisibilities {

    @Test
    void theRouteDetail_leavesTeamOut_whileANonTeamContainerUsesIt() {
      Route used = dataService.createRoute(team, admin, "Used", Visibility.PUBLIC);
      Route teamUse = dataService.createRoute(team, admin, "Team Use", Visibility.PUBLIC);
      Route unused = dataService.createRoute(team, admin, "Unused", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Sunday", "sunday", soon, Visibility.PUBLIC);
      dataService.setRideRoute(ride, used);
      Ride members =
          dataService.createRide(team, admin, "Members", "members", soon, Visibility.TEAM);
      dataService.setRideRoute(members, teamUse);

      queryContext.setUserForTest(organizer);
      assertEquals(
          NOT_TEAM,
          routeService.getDto(team.getSlug(), used.getSlug()).permissions().allowedVisibilities());
      assertEquals(
          ALL,
          routeService
              .getDto(team.getSlug(), teamUse.getSlug())
              .permissions()
              .allowedVisibilities());
      assertEquals(
          ALL,
          routeService
              .getDto(team.getSlug(), unused.getSlug())
              .permissions()
              .allowedVisibilities());

      // The bulk rows are details too, read for the whole batch at once.
      List<RouteDetailDto> bulk =
          routeService
              .getRoutesBulk(team.getSlug(), List.of(used.getSlug(), unused.getSlug()), false)
              .routes();
      assertEquals(NOT_TEAM, bulk.get(0).permissions().allowedVisibilities());
      assertEquals(ALL, bulk.get(1).permissions().allowedVisibilities());

      // The answer of a route save says the same.
      RouteDto saved =
          routeService.updateRoute(
              team.getSlug(), used.getSlug(), routeRequest("Used", Visibility.PUBLIC), null);
      assertEquals(NOT_TEAM, saved.permissions().allowedVisibilities());
    }

    @Test
    void aDeletedRide_givesTeamBack() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Gone", "gone", soon, Visibility.PUBLIC);
      dataService.setRideRoute(ride, route);
      dataService.deleteRide(ride);

      queryContext.setUserForTest(organizer);
      assertEquals(
          ALL,
          routeService.getDto(team.getSlug(), route.getSlug()).permissions().allowedVisibilities());
    }

    @Test
    void listRows_carryNoVisibilities() {
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride ride = dataService.createRide(team, admin, "Sunday", "sunday", soon, Visibility.PUBLIC);
      dataService.setRideRoute(ride, route);

      queryContext.setUserForTest(organizer);
      routeService
          .listTeamSection(team, 10)
          .routes()
          .forEach(row -> assertNull(row.permissions().allowedVisibilities()));
    }

    /**
     * A private team whose flag was withdrawn accepts only TEAM, which the public usage forbids:
     * the list is empty, and saving the route either way is refused.
     */
    @Test
    void aWithdrawnFlag_withAPublicUsage_leavesNothingToChoose() {
      Team closed = dataService.createTeam(admin, "Closed", "closed", Visibility.TEAM);
      dataService.addUserToTeam(organizer, closed, TeamRole.ORGANIZER);
      Route route = dataService.createRoute(closed, admin, "Loop", Visibility.PUBLIC_UNLISTED);
      Ride ride = dataService.createRide(closed, admin, "Link", "link", soon, Visibility.PUBLIC);
      dataService.setRideRoute(ride, route);

      queryContext.setUserForTest(organizer);
      assertEquals(
          List.of(),
          routeService
              .getDto(closed.getSlug(), route.getSlug())
              .permissions()
              .allowedVisibilities());
      // TEAM: the public usage forbids it.
      PedalonsException lowered =
          assertThrows(
              PedalonsException.class,
              () ->
                  routeService.updateRoute(
                      closed.getSlug(),
                      route.getSlug(),
                      routeRequest("Loop", Visibility.TEAM),
                      null));
      assertEquals(ErrorCode.INCOMPATIBLE_VISIBILITY, lowered.getErrorCode());
      // Anything else: the team no longer accepts it.
      for (Visibility visibility : List.of(Visibility.PUBLIC_UNLISTED, Visibility.PUBLIC)) {
        PedalonsException kept =
            assertThrows(
                PedalonsException.class,
                () ->
                    routeService.updateRoute(
                        closed.getSlug(), route.getSlug(), routeRequest("Loop", visibility), null));
        assertEquals(ErrorCode.INVALID_VISIBILITY, kept.getErrorCode(), visibility.name());
      }
      assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(route));
    }

    /**
     * Only an editor's list leaves TEAM out: a member reading the route is not told that a draft,
     * which it cannot see, uses it.
     */
    @Test
    void aMember_isNotToldOfAUsage_itCannotSee() {
      User member = dataService.createUser("member@example.com", "Member");
      dataService.addUserToTeam(member, team, TeamRole.MEMBER);
      Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
      Ride draft =
          dataService.createRide(
              team, admin, "Draft", "draft", soon, Visibility.PUBLIC, Status.DRAFT);
      dataService.setRideRoute(draft, route);

      queryContext.setUserForTest(member);
      assertEquals(
          ALL,
          routeService.getDto(team.getSlug(), route.getSlug()).permissions().allowedVisibilities());
      queryContext.setUserForTest(organizer);
      assertEquals(
          NOT_TEAM,
          routeService.getDto(team.getSlug(), route.getSlug()).permissions().allowedVisibilities());
    }
  }

  // ==================== The team going private ====================

  /**
   * makeContentTeamOnly turns every ride, trip and route of the team TEAM at once: the route check
   * is not in its way, and the invariant holds after it.
   */
  @Test
  void theTeamGoingPrivate_stillWorks_andLeavesEverythingTeam() {
    dataService.setTeamVisibilityEditable(team, true);
    Route route = dataService.createRoute(team, admin, "Loop", Visibility.PUBLIC);
    Route stageRoute = dataService.createRoute(team, admin, "Day One", Visibility.PUBLIC);
    Ride ride = dataService.createRide(team, admin, "Sunday", "sunday", soon, Visibility.PUBLIC);
    dataService.setRideRoute(ride, route);
    Trip trip = dataService.createTrip(team, admin, "Summer Tour", soon, Visibility.PUBLIC);
    dataService.setTripStageRoute(dataService.createTripStage(admin, trip, "Day 1", 0), stageRoute);

    queryContext.setUserForTest(admin);
    teamService.updateTeam(
        team.getSlug(),
        new TeamRequest(
            "Test Team",
            MediaDto.builder().build(),
            Visibility.TEAM,
            true,
            true,
            true,
            true,
            true,
            false,
            null,
            null,
            null));

    assertEquals(Visibility.TEAM, dataService.getRide(ride.getId()).getVisibility());
    assertEquals(Visibility.TEAM, dataService.routeVisibility(route));
    assertEquals(Visibility.TEAM, dataService.routeVisibility(stageRoute));
    assertTrue(
        compatibility.routesInNonTeamUse(List.of(route.getId(), stageRoute.getId())).isEmpty());
  }
}
