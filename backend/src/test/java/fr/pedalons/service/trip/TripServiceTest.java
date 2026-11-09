package fr.pedalons.service.trip;

import static fr.pedalons.util.WallTimes.wall;
import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.trips.request.StageRequest;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.dto.trips.response.TripDto;
import fr.pedalons.dto.trips.response.TripParticipationDto;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TripServiceTest extends AbstractBaseTest {

  @Inject TripService tripService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext userService;
  @Inject DomainResolver domainResolver;

  private Domain domain;
  private Team team;
  private User admin;
  private User organizer;
  private User member;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    organizer = dataService.createUser("organizer@example.com", "Organizer");
    member = dataService.createUser("member@example.com", "Member");
    dataService.addUserToTeam(organizer, team, TeamRole.ORGANIZER);
    dataService.addUserToTeam(member, team, TeamRole.MEMBER);
  }

  // ==================== Get Trip Detail ====================

  @Nested
  class GetTripDetail {

    @Test
    void shouldReturnTrip() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      userService.setUserForTest(null);
      TripDto result = tripService.getDto(team.getSlug(), trip.getSlug());

      assertEquals("Test Trip", result.getName());
      assertEquals(trip.getSlug(), result.getSlug());
    }

    @Test
    void shouldThrowForNonexistent() {
      userService.setUserForTest(null);
      assertThrows(
          PedalonsException.class, () -> tripService.getDto(team.getSlug(), "nonexistent"));
    }

    @Test
    void shouldShowDraftToOrganizer() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Draft Trip", Instant.now(), Visibility.PUBLIC, Status.DRAFT, null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.getDto(team.getSlug(), trip.getSlug());

      assertEquals(Status.DRAFT, result.getStatus());
    }

    @Test
    void shouldHideDraftFromMember() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Draft Trip", Instant.now(), Visibility.PUBLIC, Status.DRAFT, null);

      userService.setUserForTest(member);
      assertThrows(
          PedalonsException.class, () -> tripService.getDto(team.getSlug(), trip.getSlug()));
    }

    @Test
    void shouldIncludeStages() {
      Trip trip = dataService.createTrip(team, admin, "Trip with Stages", Instant.now());
      dataService.createTripStage(admin, trip, "Stage 1", 0);
      dataService.createTripStage(admin, trip, "Stage 2", 1);

      userService.setUserForTest(organizer);
      TripDto result = tripService.getDto(team.getSlug(), trip.getSlug());

      assertEquals(2, result.getStages().size());
      assertEquals(2, result.getStageCount());
    }
  }

  // ==================== Create Trip ====================

  @Nested
  class CreateTrip {

    @Test
    void shouldCreateWithSlug() {
      TripRequest request =
          new TripRequest(
              "Summer Tour",
              MediaDto.builder().markdown("A nice trip").build(),
              wall(Instant.now().plusSeconds(24 * 3600 * 7)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.createTrip(team.getSlug(), request);

      assertNotNull(result);
      assertEquals("Summer Tour", result.getName());
      assertEquals("summer-tour", result.getSlug());
      assertEquals(Status.DRAFT, result.getStatus());
    }

    @Test
    void shouldHandleSlugCollision() {
      dataService.createTrip(team, admin, "Test Trip", Instant.now());
      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.createTrip(team.getSlug(), request);

      assertNotEquals("test-trip", result.getSlug());
      assertTrue(result.getSlug().startsWith("test-trip-"));
    }

    @Test
    void shouldCreateWithRoute() {
      var route = dataService.createRoute(team, admin, "Test Route", Visibility.PUBLIC);

      TripRequest request =
          new TripRequest(
              "Trip with Route",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              route.getSlug(),
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.createTrip(team.getSlug(), request);

      assertNotNull(result);
      assertEquals(route.getSlug(), result.getRouteSlug());
    }

    @Test
    void shouldCreateWithStages() {
      StageRequest stage1 =
          StageRequest.builder()
              .name("Stage 1")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .averageSpeed(22f)
              .media(MediaDto.builder().build())
              .build();
      StageRequest stage2 =
          StageRequest.builder()
              .name("Stage 2")
              .dateTime(wall(Instant.now().plusSeconds(48 * 3600)))
              .media(MediaDto.builder().build())
              .build();

      TripRequest request =
          new TripRequest(
              "Multi-Stage Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage1, stage2),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.createTrip(team.getSlug(), request);

      assertEquals(2, result.getStages().size());
      assertEquals("Stage 1", result.getStages().get(0).name());
      assertEquals("Stage 2", result.getStages().get(1).name());
      assertEquals(22f, result.getStages().get(0).averageSpeed());
      assertNull(result.getStages().get(1).averageSpeed());
    }

    @Test
    void shouldThrowForNonOrganizer() {
      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(member);
      assertThrows(PedalonsException.class, () -> tripService.createTrip(team.getSlug(), request));
    }

    @Test
    void shouldThrowForPublicTripInTeamVisibilityTeam() {
      Team privateTeam =
          dataService.createTeam(organizer, "Private Team", "private-team", Visibility.TEAM);

      TripRequest request =
          new TripRequest(
              "Public Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class,
              () -> tripService.createTrip(privateTeam.getSlug(), request));

      assertTrue(exception.getMessage().contains("INVALID_VISIBILITY"));
    }

    @Test
    void shouldThrowForRouteFromDifferentTeam() {
      Team otherTeam = dataService.createTeam(admin, "Other Team", "other-team", Visibility.PUBLIC);
      var foreignRoute =
          dataService.createRoute(otherTeam, admin, "Foreign Route", Visibility.PUBLIC);

      TripRequest request =
          new TripRequest(
              "Trip with Foreign Route",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              foreignRoute.getSlug(),
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      assertThrows(PedalonsException.class, () -> tripService.createTrip(team.getSlug(), request));
    }

    @Test
    void shouldThrowForPrivateRouteOnPublicTrip() {
      var privateRoute = dataService.createRoute(team, admin, "Private Route", Visibility.TEAM);

      TripRequest request =
          new TripRequest(
              "Public Trip with Private Route",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              privateRoute.getSlug(),
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class, () -> tripService.createTrip(team.getSlug(), request));

      assertTrue(exception.getMessage().contains("PUBLIC_TRIP_PRIVATE_ROUTE"));
    }

    @Test
    void shouldAllowTeamRouteOnTeamTrip() {
      var teamRoute = dataService.createRoute(team, admin, "Team Route", Visibility.TEAM);

      TripRequest request =
          new TripRequest(
              "Team Trip with Team Route",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.TEAM,
              teamRoute.getSlug(),
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.createTrip(team.getSlug(), request);

      assertNotNull(result);
      assertEquals(teamRoute.getSlug(), result.getRouteSlug());
    }

    @Test
    void shouldThrowForInvalidRouteSlug() {
      TripRequest request =
          new TripRequest(
              "Trip with Invalid Route",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              "nonexistent-route",
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      assertThrows(PedalonsException.class, () -> tripService.createTrip(team.getSlug(), request));
    }

    @Test
    void shouldAllowTeamTripInTeamTeam() {
      Team privateTeam =
          dataService.createTeam(organizer, "Private Team", "private-team", Visibility.TEAM);

      TripRequest request =
          new TripRequest(
              "Team Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.TEAM,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.createTrip(privateTeam.getSlug(), request);

      assertNotNull(result);
      assertEquals(Visibility.TEAM, result.getVisibility());
    }

    @Test
    void shouldCreateStageWithStartAndEndPlaces() {
      var startPlace = dataService.createPlace(team, admin, "Start Location", true, false);
      var endPlace = dataService.createPlace(team, admin, "End Location", false, true);

      StageRequest stage =
          StageRequest.builder()
              .name("Stage with Places")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .startPlaceId(TsidUtils.toString(startPlace.getId()))
              .endPlaceId(TsidUtils.toString(endPlace.getId()))
              .build();

      TripRequest request =
          new TripRequest(
              "Trip with Stage Places",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.createTrip(team.getSlug(), request);

      assertNotNull(result);
      assertEquals(1, result.getStages().size());
      assertNotNull(result.getStages().get(0).startPlace());
      assertNotNull(result.getStages().get(0).endPlace());
      assertEquals("Start Location", result.getStages().get(0).startPlace().name());
      assertEquals("End Location", result.getStages().get(0).endPlace().name());
    }

    @Test
    void shouldThrowForStageWithInvalidStartPlaceId() {
      StageRequest stage =
          StageRequest.builder()
              .name("Stage with Invalid Start")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .startPlaceId(TsidUtils.toString(9999L))
              .build();

      TripRequest request =
          new TripRequest(
              "Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      assertThrows(PedalonsException.class, () -> tripService.createTrip(team.getSlug(), request));
    }

    @Test
    void shouldThrowForStageWithInvalidEndPlaceId() {
      StageRequest stage =
          StageRequest.builder()
              .name("Stage with Invalid End")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .endPlaceId(TsidUtils.toString(9999L))
              .build();

      TripRequest request =
          new TripRequest(
              "Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      assertThrows(PedalonsException.class, () -> tripService.createTrip(team.getSlug(), request));
    }

    @Test
    void shouldThrowForStageWithPlaceFromDifferentTeam() {
      Team otherTeam = dataService.createTeam(admin, "Other Team", "other-team", Visibility.PUBLIC);
      var foreignPlace = dataService.createPlace(otherTeam, admin, "Foreign Place");

      StageRequest stage =
          StageRequest.builder()
              .name("Stage with Foreign Place")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .startPlaceId(TsidUtils.toString(foreignPlace.getId()))
              .build();

      TripRequest request =
          new TripRequest(
              "Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      assertThrows(PedalonsException.class, () -> tripService.createTrip(team.getSlug(), request));
    }
  }

  // ==================== Update Trip ====================

  @Nested
  class UpdateTrip {

    @Test
    void shouldUpdateFields() {
      Trip trip = dataService.createTrip(team, admin, "Original", Instant.now());

      TripRequest request =
          new TripRequest(
              "Updated Title",
              MediaDto.builder().markdown("Updated description").build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.CANCELLED,
              Visibility.TEAM,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertEquals("Updated Title", result.getName());
      assertEquals(Status.CANCELLED, result.getStatus());
      assertEquals(Visibility.TEAM, result.getVisibility());
    }

    @Test
    void shouldUpdateWithRoute() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      var route = dataService.createRoute(team, admin, "Test Route", Visibility.PUBLIC);

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              route.getSlug(),
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertEquals(route.getSlug(), result.getRouteSlug());
    }

    @Test
    void shouldClearRoute() {
      var route = dataService.createRoute(team, admin, "Test Route", Visibility.PUBLIC);
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      trip.setRoute(route);

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertNull(result.getRouteSlug());
    }

    @Test
    void shouldThrowForRouteFromDifferentTeam() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      Team otherTeam = dataService.createTeam(admin, "Other Team", "other-team", Visibility.PUBLIC);
      var foreignRoute =
          dataService.createRoute(otherTeam, admin, "Foreign Route", Visibility.PUBLIC);

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              foreignRoute.getSlug(),
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      assertThrows(
          PedalonsException.class,
          () -> tripService.updateTrip(team.getSlug(), trip.getSlug(), request));
    }

    @Test
    void shouldThrowForPrivateRouteOnPublicTrip() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      var privateRoute = dataService.createRoute(team, admin, "Private Route", Visibility.TEAM);

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              privateRoute.getSlug(),
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class,
              () -> tripService.updateTrip(team.getSlug(), trip.getSlug(), request));

      assertTrue(exception.getMessage().contains("PUBLIC_TRIP_PRIVATE_ROUTE"));
    }

    @Test
    void shouldAllowTeamRouteOnTeamTrip() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Team Trip", Instant.now(), Visibility.TEAM, Status.DRAFT, null);
      var teamRoute = dataService.createRoute(team, admin, "Team Route", Visibility.TEAM);

      TripRequest request =
          new TripRequest(
              "Team Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.TEAM,
              teamRoute.getSlug(),
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertNotNull(result);
      assertEquals(teamRoute.getSlug(), result.getRouteSlug());
    }

    @Test
    void shouldThrowForNonOrganizer() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      TripRequest request =
          new TripRequest(
              "Updated",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(member);
      assertThrows(
          PedalonsException.class,
          () -> tripService.updateTrip(team.getSlug(), trip.getSlug(), request));
    }

    @Test
    void shouldThrowForPublicVisibilityInTeamVisibilityTeam() {
      Team privateTeam =
          dataService.createTeam(organizer, "Private Team", "private-team", Visibility.TEAM);
      Trip trip =
          dataService.createTrip(
              privateTeam,
              organizer,
              "Team Trip",
              Instant.now(),
              Visibility.TEAM,
              Status.DRAFT,
              null);

      TripRequest request =
          new TripRequest(
              "Title",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class,
              () -> tripService.updateTrip(privateTeam.getSlug(), trip.getSlug(), request));

      assertTrue(exception.getMessage().contains("INVALID_VISIBILITY"));
    }

    @Test
    void shouldAllowTeamTripUpdateInTeamTeam() {
      Team privateTeam =
          dataService.createTeam(organizer, "Private Team", "private-team", Visibility.TEAM);
      Trip trip =
          dataService.createTrip(
              privateTeam,
              organizer,
              "Team Trip",
              Instant.now(),
              Visibility.TEAM,
              Status.DRAFT,
              null);

      TripRequest request =
          new TripRequest(
              "Updated Team Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.PUBLISHED,
              Visibility.TEAM,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(privateTeam.getSlug(), trip.getSlug(), request);

      assertNotNull(result);
      assertEquals("Updated Team Trip", result.getName());
      assertEquals(Visibility.TEAM, result.getVisibility());
      assertEquals(Status.PUBLISHED, result.getStatus());
    }

    @Test
    void shouldAddNewStages() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      StageRequest newStage =
          StageRequest.builder()
              .name("New Stage")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .build();

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(newStage),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertEquals(1, result.getStages().size());
      assertEquals("New Stage", result.getStages().get(0).name());
    }

    @Test
    void shouldUpdateExistingStages() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      TripStage existingStage = dataService.createTripStage(admin, trip, "Original Stage", 0);
      String stageId = TsidUtils.toString(existingStage.getId());

      StageRequest updatedStage =
          StageRequest.builder()
              .id(stageId)
              .name("Updated Stage")
              .dateTime(wall(Instant.now().plusSeconds(48 * 3600)))
              .media(MediaDto.builder().build())
              .build();

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(updatedStage),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertEquals(1, result.getStages().size());
      assertEquals("Updated Stage", result.getStages().get(0).name());
    }

    @Test
    void shouldRemoveStagesNotInRequest() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      dataService.createTripStage(admin, trip, "Stage 1", 0);
      dataService.createTripStage(admin, trip, "Stage 2", 1);

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertEquals(0, result.getStages().size());
    }

    @Test
    void shouldUpdateStageWithStartAndEndPlaces() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      var startPlace = dataService.createPlace(team, admin, "Start Location", true, false);
      var endPlace = dataService.createPlace(team, admin, "End Location", false, true);

      StageRequest stage =
          StageRequest.builder()
              .name("Stage with Places")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .startPlaceId(TsidUtils.toString(startPlace.getId()))
              .endPlaceId(TsidUtils.toString(endPlace.getId()))
              .build();

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertEquals(1, result.getStages().size());
      assertNotNull(result.getStages().get(0).startPlace());
      assertNotNull(result.getStages().get(0).endPlace());
      assertEquals("Start Location", result.getStages().get(0).startPlace().name());
      assertEquals("End Location", result.getStages().get(0).endPlace().name());
    }

    @Test
    void shouldThrowForStageWithInvalidStartPlaceId() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      StageRequest stage =
          StageRequest.builder()
              .name("Stage with Invalid Start")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .startPlaceId(TsidUtils.toString(9999L))
              .build();

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      assertThrows(
          PedalonsException.class,
          () -> tripService.updateTrip(team.getSlug(), trip.getSlug(), request));
    }

    @Test
    void shouldThrowForStageWithInvalidEndPlaceId() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      StageRequest stage =
          StageRequest.builder()
              .name("Stage with Invalid End")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .endPlaceId(TsidUtils.toString(9999L))
              .build();

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      assertThrows(
          PedalonsException.class,
          () -> tripService.updateTrip(team.getSlug(), trip.getSlug(), request));
    }

    @Test
    void shouldThrowForStageWithPlaceFromDifferentTeam() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      Team otherTeam = dataService.createTeam(admin, "Other Team", "other-team", Visibility.PUBLIC);
      var foreignPlace = dataService.createPlace(otherTeam, admin, "Foreign Place");

      StageRequest stage =
          StageRequest.builder()
              .name("Stage with Foreign Place")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .startPlaceId(TsidUtils.toString(foreignPlace.getId()))
              .build();

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      assertThrows(
          PedalonsException.class,
          () -> tripService.updateTrip(team.getSlug(), trip.getSlug(), request));
    }

    @Test
    void shouldClearStagePlaces() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());
      var startPlace = dataService.createPlace(team, admin, "Start", true, false);
      var endPlace = dataService.createPlace(team, admin, "End", false, true);
      TripStage existingStage = dataService.createTripStage(admin, trip, "Stage", 0);
      existingStage.setStartPlace(startPlace);
      existingStage.setEndPlace(endPlace);
      String stageId = TsidUtils.toString(existingStage.getId());

      StageRequest stage =
          StageRequest.builder()
              .id(stageId)
              .name("Stage")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .startPlaceId(null)
              .endPlaceId(null)
              .build();

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      TripDto result = tripService.updateTrip(team.getSlug(), trip.getSlug(), request);

      assertEquals(1, result.getStages().size());
      assertNull(result.getStages().get(0).startPlace());
      assertNull(result.getStages().get(0).endPlace());
    }

    @Test
    void shouldThrowForStageWithInvalidId() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      StageRequest stage =
          StageRequest.builder()
              .id(TsidUtils.toString(9999L))
              .name("Stage with Invalid ID")
              .dateTime(wall(Instant.now().plusSeconds(24 * 3600)))
              .media(MediaDto.builder().build())
              .build();

      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(stage),
              null);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class,
              () -> tripService.updateTrip(team.getSlug(), trip.getSlug(), request));

      assertTrue(exception.getMessage().contains("NOT_FOUND"));
    }
  }

  // ==================== Delete Trip ====================

  @Nested
  class DeleteTrip {

    @Test
    void shouldSoftDelete() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      userService.setUserForTest(organizer);
      tripService.deleteTrip(team.getSlug(), trip.getSlug());

      userService.setUserForTest(organizer);
      assertThrows(
          PedalonsException.class, () -> tripService.getDto(team.getSlug(), trip.getSlug()));
    }

    @Test
    void shouldThrowForNonOrganizer() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      userService.setUserForTest(member);
      assertThrows(
          PedalonsException.class, () -> tripService.deleteTrip(team.getSlug(), trip.getSlug()));
    }
  }

  // ==================== Undelete Trip ====================

  @Nested
  class UndeleteTrip {

    @Test
    void shouldRestoreDeletedTrip() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      userService.setUserForTest(organizer);
      tripService.deleteTrip(team.getSlug(), trip.getSlug());

      userService.setUserForTest(admin);
      TripDto result = tripService.undeleteTrip(team.getSlug(), trip.getSlug());

      assertFalse(result.isDeleted());
      assertEquals(trip.getSlug(), result.getSlug());
    }

    @Test
    void shouldThrowForNonOrganizer() {
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      userService.setUserForTest(organizer);
      tripService.deleteTrip(team.getSlug(), trip.getSlug());

      userService.setUserForTest(member);
      assertThrows(
          PedalonsException.class, () -> tripService.undeleteTrip(team.getSlug(), trip.getSlug()));
    }
  }

  // ==================== Join Trip ====================

  /** A trip joined in these tests must not be over yet: joining one is refused (TRIP_FINISHED). */
  private static Instant tomorrow() {
    return Instant.now().plus(1, ChronoUnit.DAYS);
  }

  @Nested
  class JoinTrip {

    @Test
    void shouldRefuseATripThatIsOver() {
      Trip trip =
          dataService.createTrip(
              team,
              admin,
              "Past Trip",
              Instant.now().minus(3, ChronoUnit.DAYS),
              Visibility.PUBLIC,
              Status.PUBLISHED,
              null);
      dataService.createTripStage(admin, trip, "Last day", Instant.now().minus(2, ChronoUnit.DAYS));

      userService.setUserForTest(member);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class, () -> tripService.joinTrip(team.getSlug(), trip.getSlug()));

      assertEquals("TRIP_FINISHED", exception.getMessage());
    }

    /** Under way, its last stage still ahead: a trip stays open to join. */
    @Test
    void shouldAcceptATripUnderWay() {
      Trip trip =
          dataService.createTrip(
              team,
              admin,
              "Ongoing Trip",
              Instant.now().minus(1, ChronoUnit.DAYS),
              Visibility.PUBLIC,
              Status.PUBLISHED,
              null);
      dataService.createTripStage(admin, trip, "Day 1", Instant.now().minus(1, ChronoUnit.DAYS));
      dataService.createTripStage(admin, trip, "Day 2", tomorrow());

      userService.setUserForTest(member);
      TripParticipationDto result = tripService.joinTrip(team.getSlug(), trip.getSlug());

      assertNotNull(result);
    }

    @Test
    void shouldCreateParticipation() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Test Trip", tomorrow(), Visibility.PUBLIC, Status.PUBLISHED, null);

      userService.setUserForTest(member);
      TripParticipationDto result = tripService.joinTrip(team.getSlug(), trip.getSlug());

      assertNotNull(result);
      assertEquals(member.getId(), TsidUtils.toLong(result.userId()));
    }

    @Test
    void shouldThrowForDraftTripAsMember() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Draft Trip", Instant.now(), Visibility.PUBLIC, Status.DRAFT, null);

      userService.setUserForTest(member);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class, () -> tripService.joinTrip(team.getSlug(), trip.getSlug()));

      // Member can't see draft trips, so they get "not found"
      assertTrue(exception.getMessage().contains("NOT_FOUND"));
    }

    @Test
    void shouldThrowForDraftTripAsOrganizer() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Draft Trip", Instant.now(), Visibility.PUBLIC, Status.DRAFT, null);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class, () -> tripService.joinTrip(team.getSlug(), trip.getSlug()));

      // Access denied for draft trips
      assertTrue(exception.getMessage().contains("FORBIDDEN"));
    }

    @Test
    void shouldThrowWhenAlreadyJoined() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Test Trip", tomorrow(), Visibility.PUBLIC, Status.PUBLISHED, null);
      dataService.createTripParticipation(trip, member);

      userService.setUserForTest(member);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class, () -> tripService.joinTrip(team.getSlug(), trip.getSlug()));

      assertTrue(exception.getMessage().contains("ALREADY_REGISTERED"));
    }

    @Test
    void shouldRestoreSoftDeletedParticipation() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Test Trip", tomorrow(), Visibility.PUBLIC, Status.PUBLISHED, null);
      userService.setUserForTest(member);
      tripService.joinTrip(team.getSlug(), trip.getSlug());
      tripService.leaveTrip(team.getSlug(), trip.getSlug());

      TripParticipationDto result = tripService.joinTrip(team.getSlug(), trip.getSlug());

      assertNotNull(result);
      assertEquals(member.getId(), TsidUtils.toLong(result.userId()));
    }
  }

  // ==================== Leave Trip ====================

  @Nested
  class LeaveTrip {

    @Test
    void shouldRemoveParticipation() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Test Trip", tomorrow(), Visibility.PUBLIC, Status.PUBLISHED, null);
      userService.setUserForTest(member);
      tripService.joinTrip(team.getSlug(), trip.getSlug());

      tripService.leaveTrip(team.getSlug(), trip.getSlug());

      // Member can rejoin after leaving
      TripParticipationDto newParticipation = tripService.joinTrip(team.getSlug(), trip.getSlug());
      assertNotNull(newParticipation);
    }

    @Test
    void shouldThrowWhenNotJoined() {
      Trip trip =
          dataService.createTrip(
              team, admin, "Test Trip", tomorrow(), Visibility.PUBLIC, Status.PUBLISHED, null);

      userService.setUserForTest(member);
      assertThrows(
          PedalonsException.class, () -> tripService.leaveTrip(team.getSlug(), trip.getSlug()));
    }
  }

  // ==================== Trips Disabled ====================

  @Nested
  class TripsDisabled {

    @BeforeEach
    void disableTrips() {
      team.setEnableTrips(false);
      team = dataService.updateTeam(team);
    }

    @Test
    void shouldThrowOnCreateWhenTripsDisabled() {
      TripRequest request =
          new TripRequest(
              "Test Trip",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class, () -> tripService.createTrip(team.getSlug(), request));

      assertTrue(exception.getMessage().contains("FORBIDDEN"));
    }

    @Test
    void shouldThrowOnUpdateWhenTripsDisabled() {
      // Create trip while trips are enabled
      team.setEnableTrips(true);
      team = dataService.updateTeam(team);
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      // Disable trips
      team.setEnableTrips(false);
      team = dataService.updateTeam(team);

      TripRequest request =
          new TripRequest(
              "Updated Title",
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              Visibility.PUBLIC,
              null,
              null,
              List.of(),
              null);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class,
              () -> tripService.updateTrip(team.getSlug(), trip.getSlug(), request));

      assertTrue(exception.getMessage().contains("FORBIDDEN"));
    }

    @Test
    void shouldThrowOnDeleteWhenTripsDisabled() {
      // Create trip while trips are enabled
      team.setEnableTrips(true);
      team = dataService.updateTeam(team);
      Trip trip = dataService.createTrip(team, admin, "Test Trip", Instant.now());

      // Disable trips
      team.setEnableTrips(false);
      team = dataService.updateTeam(team);

      userService.setUserForTest(organizer);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class,
              () -> tripService.deleteTrip(team.getSlug(), trip.getSlug()));

      assertTrue(exception.getMessage().contains("FORBIDDEN"));
    }

    @Test
    void shouldThrowOnJoinWhenTripsDisabled() {
      // Create trip while trips are enabled
      team.setEnableTrips(true);
      team = dataService.updateTeam(team);
      Trip trip =
          dataService.createTrip(
              team, admin, "Test Trip", tomorrow(), Visibility.PUBLIC, Status.PUBLISHED, null);

      // Disable trips
      team.setEnableTrips(false);
      team = dataService.updateTeam(team);

      userService.setUserForTest(member);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class, () -> tripService.joinTrip(team.getSlug(), trip.getSlug()));

      assertTrue(exception.getMessage().contains("FORBIDDEN"));
    }

    @Test
    void shouldThrowOnLeaveWhenTripsDisabled() {
      // Create trip and join while trips are enabled
      team.setEnableTrips(true);
      team = dataService.updateTeam(team);
      Trip trip =
          dataService.createTrip(
              team, admin, "Test Trip", tomorrow(), Visibility.PUBLIC, Status.PUBLISHED, null);
      userService.setUserForTest(member);
      tripService.joinTrip(team.getSlug(), trip.getSlug());

      // Disable trips
      team.setEnableTrips(false);
      team = dataService.updateTeam(team);

      userService.setUserForTest(member);
      PedalonsException exception =
          assertThrows(
              PedalonsException.class, () -> tripService.leaveTrip(team.getSlug(), trip.getSlug()));

      assertTrue(exception.getMessage().contains("FORBIDDEN"));
    }
  }
}
