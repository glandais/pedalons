package fr.pedalons.service.ride;

import static fr.pedalons.util.WallTimes.wall;
import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.rides.response.*;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.repository.ride.RideParticipationRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class RideServiceTest extends AbstractBaseTest {

  @Inject RideService rideService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext userService;
  @Inject DomainResolver domainResolver;
  @Inject RideParticipationRepository participationRepository;

  private Domain domain;
  private Team team;
  private User admin;
  private User organizer;
  private User member;
  private User user2;

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
    user2 = dataService.createUser("user2@example.com", "user2");
  }

  // ==================== Get Ride ====================

  @Test
  void getRideBySlug_shouldReturnRide() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    userService.setUserForTest(null);
    RideDto result = rideService.getDto(team.getSlug(), "test-ride");

    assertEquals("Test Ride", result.getName());
    assertEquals("test-ride", result.getSlug());
  }

  @Test
  void getRideBySlug_shouldThrowForNonexistent() {
    userService.setUserForTest(null);
    assertThrows(PedalonsException.class, () -> rideService.getDto(team.getSlug(), "nonexistent"));
  }

  @Test
  void getRideBySlug_shouldShowDraftToOrganizer() {
    dataService.createRide(team, admin, "Draft", "draft", Instant.now(), Status.DRAFT);
    userService.setUserForTest(organizer);
    RideDto result = rideService.getDto(team.getSlug(), "draft");

    assertEquals(Status.DRAFT, result.getStatus());
  }

  @Test
  void getRideBySlug_shouldHideDraftFromMember() {
    dataService.createRide(team, admin, "Draft", "draft", Instant.now(), Status.DRAFT);

    userService.setUserForTest(member);
    assertThrows(PedalonsException.class, () -> rideService.getDto(team.getSlug(), "draft"));
  }

  // ==================== Create Ride ====================

  @Test
  void createRide_shouldCreateWithSlug() {
    RideRequest request =
        new RideRequest(
            "Sunday Ride",
            MediaDto.builder().markdown("A nice ride").build(),
            wall(Instant.now().plusSeconds(24 * 3600 * 7)),
            Status.DRAFT,
            Visibility.TEAM,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.createRide(team.getSlug(), request);

    assertNotNull(result);
    assertEquals("Sunday Ride", result.getName());
    assertEquals("sunday-ride", result.getSlug());
    assertEquals(Status.DRAFT, result.getStatus());
  }

  @Test
  void createRide_shouldHandleSlugCollision() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.createRide(team.getSlug(), request);

    assertNotEquals("test-ride", result.getSlug());
    assertTrue(result.getSlug().startsWith("test-ride-"));
  }

  @Test
  void createRide_shouldCreateWithGroups() {
    GroupRequest group1 = new GroupRequest(null, "Fast", null, 30.0f, 10, null);
    GroupRequest group2 = new GroupRequest(null, "Slow", null, 20.0f, 15, null);
    RideRequest request =
        new RideRequest(
            "Group Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(group1, group2),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.createRide(team.getSlug(), request);

    assertEquals("Group Ride", result.getName());
    List<RideGroupDto> groups = result.getGroups();
    assertEquals(2, groups.size());
  }

  @Test
  void createRide_shouldThrowForNonOrganizer() {
    RideRequest request =
        new RideRequest(
            "Test",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(member);
    assertThrows(PedalonsException.class, () -> rideService.createRide(team.getSlug(), request));
  }

  @Test
  void createRide_shouldThrowForPublicRideInTeamVisibilityTeam() {
    Team privateTeam =
        dataService.createTeam(user2, "Private Team", "private-team", Visibility.TEAM);
    dataService.addUserToTeam(organizer, privateTeam, TeamRole.ORGANIZER);

    RideRequest request =
        new RideRequest(
            "Public Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class, () -> rideService.createRide(privateTeam.getSlug(), request));

    assertTrue(exception.getMessage().contains("INVALID_VISIBILITY"));
  }

  /** A private team the platform admin allowed may publish by link (docs/LEDGER_*.md API-176). */
  @Test
  void createRide_shouldSucceedForPublicRideInPrivateTeamWithPublicContentAllowed() {
    Team privateTeam =
        dataService.createTeam(user2, "Private Team", "private-team", Visibility.TEAM);
    dataService.addUserToTeam(organizer, privateTeam, TeamRole.ORGANIZER);
    dataService.setTeamPublicContentAllowed(privateTeam, true);

    userService.setUserForTest(organizer);
    for (Visibility visibility : List.of(Visibility.PUBLIC, Visibility.PUBLIC_UNLISTED)) {
      RideRequest request =
          new RideRequest(
              "Ride " + visibility,
              MediaDto.builder().build(),
              wall(Instant.now().plusSeconds(24 * 3600)),
              Status.DRAFT,
              visibility,
              null,
              null,
              null,
              null,
              List.of(),
              null);
      RideDto result = rideService.createRide(privateTeam.getSlug(), request);
      assertEquals(visibility, result.getVisibility());
    }
  }

  @Test
  void createRide_shouldSucceedForTeamRideInTeamVisibilityTeam() {
    Team privateTeam =
        dataService.createTeam(user2, "Private Team", "private-team", Visibility.TEAM);
    dataService.addUserToTeam(organizer, privateTeam, TeamRole.ORGANIZER);

    RideRequest request =
        new RideRequest(
            "Team Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.TEAM,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.createRide(privateTeam.getSlug(), request);

    assertNotNull(result);
    assertEquals("Team Ride", result.getName());
    assertEquals(Visibility.TEAM, result.getVisibility());
  }

  @Test
  void createRide_shouldCreateWithRoute() {
    var route = dataService.createRoute(team, admin, "Test Route", Visibility.PUBLIC);

    RideRequest request =
        new RideRequest(
            "Ride with Route",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            route.getSlug(),
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.createRide(team.getSlug(), request);

    assertNotNull(result);
    assertNotNull(result.getRouteSlug());
    assertEquals(route.getSlug(), result.getRouteSlug());
  }

  @Test
  void createRide_shouldThrowForInvalidRouteSlug() {
    RideRequest request =
        new RideRequest(
            "Ride with Invalid Route",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            "nonexistent-route",
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(PedalonsException.class, () -> rideService.createRide(team.getSlug(), request));
  }

  @Test
  void createRide_shouldThrowForRouteFromDifferentTeam() {
    Team otherTeam = dataService.createTeam(user2, "Other Team", "other-team", Visibility.PUBLIC);
    var foreignRoute =
        dataService.createRoute(otherTeam, user2, "Foreign Route", Visibility.PUBLIC);

    RideRequest request =
        new RideRequest(
            "Ride with Foreign Route",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            foreignRoute.getSlug(),
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(PedalonsException.class, () -> rideService.createRide(team.getSlug(), request));
  }

  @Test
  void createRide_shouldThrowForPrivateRouteOnPublicTeam() {
    var privateRoute = dataService.createRoute(team, admin, "Private Route", Visibility.TEAM);

    RideRequest request =
        new RideRequest(
            "Public Ride with Private Route",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            privateRoute.getSlug(),
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class, () -> rideService.createRide(team.getSlug(), request));

    assertTrue(exception.getMessage().contains("PUBLIC_RIDE_PRIVATE_ROUTE"));
  }

  @Test
  void createRide_shouldAllowTeamRouteOnTeamRide() {
    var teamRoute = dataService.createRoute(team, admin, "Team Route", Visibility.TEAM);

    RideRequest request =
        new RideRequest(
            "Team Ride with Team Route",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.TEAM,
            teamRoute.getSlug(),
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.createRide(team.getSlug(), request);

    assertNotNull(result);
    assertEquals(teamRoute.getSlug(), result.getRouteSlug());
  }

  @Test
  void createRide_shouldCreateWithStartAndEndPlaces() {
    var startPlace = dataService.createPlace(team, admin, "Start Location", true, false);
    var endPlace = dataService.createPlace(team, admin, "End Location", false, true);
    String startPlaceId = TsidUtils.toString(startPlace.getId());
    String endPlaceId = TsidUtils.toString(endPlace.getId());

    RideRequest request =
        new RideRequest(
            "Ride with Places",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            startPlaceId,
            endPlaceId,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.createRide(team.getSlug(), request);

    assertNotNull(result);
    assertNotNull(result.getStartPlace());
    assertNotNull(result.getEndPlace());
    assertEquals("Start Location", result.getStartPlace().name());
    assertEquals("End Location", result.getEndPlace().name());
  }

  @Test
  void createRide_shouldThrowForInvalidStartPlaceId() {
    RideRequest request =
        new RideRequest(
            "Ride with Invalid Start",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            TsidUtils.toString(9999L),
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(PedalonsException.class, () -> rideService.createRide(team.getSlug(), request));
  }

  @Test
  void createRide_shouldThrowForInvalidEndPlaceId() {
    RideRequest request =
        new RideRequest(
            "Ride with Invalid End",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            TsidUtils.toString(9999L),
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(PedalonsException.class, () -> rideService.createRide(team.getSlug(), request));
  }

  @Test
  void createRide_shouldThrowForPlaceFromDifferentTeam() {
    Team otherTeam = dataService.createTeam(user2, "Other Team", "other-team", Visibility.PUBLIC);
    var foreignPlace = dataService.createPlace(otherTeam, user2, "Foreign Place");
    String foreignPlaceId = TsidUtils.toString(foreignPlace.getId());

    RideRequest request =
        new RideRequest(
            "Ride with Foreign Place",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            foreignPlaceId,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(PedalonsException.class, () -> rideService.createRide(team.getSlug(), request));
  }

  // ==================== Update Ride ====================

  @Test
  void updateRide_shouldUpdateFields() {
    dataService.createRide(team, admin, "Original", "original", Instant.now());
    RideRequest request =
        new RideRequest(
            "Updated Title",
            MediaDto.builder().markdown("Updated description").build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.CANCELLED,
            Visibility.TEAM,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "original", request);

    assertEquals("Updated Title", result.getName());
    assertEquals("Updated description", result.getMedia().markdown());
    assertEquals(Status.CANCELLED, result.getStatus());
    assertEquals(Visibility.TEAM, result.getVisibility());
  }

  @Test
  void updateRide_shouldUpdatePartialFields() {
    dataService.createRide(team, admin, "Original", "original", Instant.now());
    RideRequest request =
        new RideRequest(
            "New Title",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "original", request);

    assertEquals("New Title", result.getName());
    assertEquals(Status.PUBLISHED, result.getStatus());
  }

  @Test
  void updateRide_shouldPreserveStatusWhenNull() {
    dataService.createRide(
        team,
        admin,
        "Published Ride",
        "published-ride",
        Instant.now(),
        Visibility.PUBLIC,
        Status.PUBLISHED);
    RideRequest request =
        new RideRequest(
            "Updated Title",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "published-ride", request);

    assertEquals("Updated Title", result.getName());
    assertEquals(Status.PUBLISHED, result.getStatus());
  }

  @Test
  void updateRide_shouldThrowForNonOrganizer() {
    dataService.createRide(team, admin, "Test", "test", Instant.now());
    RideRequest request =
        new RideRequest(
            "New",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(member);
    assertThrows(
        PedalonsException.class, () -> rideService.updateRide(team.getSlug(), "test", request));
  }

  @Test
  void updateRide_shouldThrowForPublicVisibilityInTeamVisibilityTeam() {
    Team privateTeam =
        dataService.createTeam(user2, "Private Team", "private-team", Visibility.TEAM);
    dataService.addUserToTeam(organizer, privateTeam, TeamRole.ORGANIZER);
    dataService.createRide(
        privateTeam,
        organizer,
        "Team Ride",
        "team-ride",
        Instant.now(),
        Visibility.TEAM,
        Status.DRAFT);

    RideRequest request =
        new RideRequest(
            "Title",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.updateRide(privateTeam.getSlug(), "team-ride", request));

    assertTrue(exception.getMessage().contains("INVALID_VISIBILITY"));
  }

  @Test
  void updateRide_shouldSucceedForTeamVisibilityInTeamVisibilityTeam() {
    Team privateTeam =
        dataService.createTeam(user2, "Private Team", "private-team", Visibility.TEAM);
    dataService.addUserToTeam(organizer, privateTeam, TeamRole.ORGANIZER);
    dataService.createRide(
        privateTeam,
        organizer,
        "Team Ride",
        "team-ride",
        Instant.now(),
        Visibility.TEAM,
        Status.DRAFT);

    RideRequest request =
        new RideRequest(
            "Updated Title",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.TEAM,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(privateTeam.getSlug(), "team-ride", request);

    assertEquals("Updated Title", result.getName());
    assertEquals(Visibility.TEAM, result.getVisibility());
  }

  @Test
  void updateRide_shouldAddNewGroups() {
    Ride ride = dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());

    GroupRequest newGroup = new GroupRequest(null, "New Group", null, 25.0f, 10, null);
    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(newGroup),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertEquals(1, result.getGroups().size());
    assertEquals("New Group", result.getGroups().getFirst().name());
    assertEquals(25, result.getGroups().getFirst().averageSpeed());
  }

  @Test
  void updateRide_shouldUpdateExistingGroups() {
    Ride ride = dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    RideGroup existingGroup = dataService.createRideGroup(admin, ride, "Original Group", 0);
    String groupId = TsidUtils.toString(existingGroup.getId());

    GroupRequest updatedGroup = new GroupRequest(groupId, "Updated Group", null, 30.0f, 15, null);
    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(updatedGroup),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertEquals(1, result.getGroups().size());
    assertEquals("Updated Group", result.getGroups().getFirst().name());
    assertEquals(30, result.getGroups().getFirst().averageSpeed());
  }

  @Test
  void updateRide_shouldRemoveGroupsNotInRequest() {
    Ride ride = dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    dataService.createRideGroup(admin, ride, "Group 1", 0);
    dataService.createRideGroup(admin, ride, "Group 2", 1);

    // Update with empty groups list - should remove all groups
    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertEquals(0, result.getGroups().size());
  }

  @Test
  void updateRide_shouldReorderGroups() {
    Ride ride = dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    RideGroup group1 = dataService.createRideGroup(admin, ride, "Group A", 0);
    RideGroup group2 = dataService.createRideGroup(admin, ride, "Group B", 1);
    String group1Id = TsidUtils.toString(group1.getId());
    String group2Id = TsidUtils.toString(group2.getId());

    // Swap order: B first, then A
    GroupRequest reorderedGroup1 = new GroupRequest(group2Id, "Group B", null, 25.0f, 10, null);
    GroupRequest reorderedGroup2 = new GroupRequest(group1Id, "Group A", null, 20.0f, 5, null);
    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(reorderedGroup1, reorderedGroup2),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertEquals(2, result.getGroups().size());
    assertEquals("Group B", result.getGroups().get(0).name());
    assertEquals("Group A", result.getGroups().get(1).name());
  }

  @Test
  void updateRide_shouldAddAndKeepExistingGroups() {
    Ride ride = dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    RideGroup existingGroup = dataService.createRideGroup(admin, ride, "Existing Group", 0);
    String existingGroupId = TsidUtils.toString(existingGroup.getId());

    GroupRequest keepExisting =
        new GroupRequest(existingGroupId, "Existing Group", null, 25.0f, 10, null);
    GroupRequest addNew = new GroupRequest(null, "New Group", null, 30.0f, 15, null);
    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(keepExisting, addNew),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertEquals(2, result.getGroups().size());
    assertEquals("Existing Group", result.getGroups().get(0).name());
    assertEquals("New Group", result.getGroups().get(1).name());
  }

  @Test
  void updateRide_shouldThrowForGroupWithInvalidId() {
    Ride ride = dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());

    GroupRequest invalidGroup =
        new GroupRequest(TsidUtils.toString(9999L), "Invalid Group", null, 25.0f, 10, null);
    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(invalidGroup),
            null);

    userService.setUserForTest(organizer);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.updateRide(team.getSlug(), "test-ride", request));

    assertTrue(exception.getMessage().contains("NOT_FOUND"));
  }

  @Test
  void updateRide_shouldUpdateWithStartAndEndPlaces() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    var startPlace = dataService.createPlace(team, admin, "Start Location", true, false);
    var endPlace = dataService.createPlace(team, admin, "End Location", false, true);
    String startPlaceId = TsidUtils.toString(startPlace.getId());
    String endPlaceId = TsidUtils.toString(endPlace.getId());

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            startPlaceId,
            endPlaceId,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertNotNull(result.getStartPlace());
    assertNotNull(result.getEndPlace());
    assertEquals("Start Location", result.getStartPlace().name());
    assertEquals("End Location", result.getEndPlace().name());
  }

  @Test
  void updateRide_shouldThrowForInvalidStartPlaceId() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            TsidUtils.toString(9999L),
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(
        PedalonsException.class,
        () -> rideService.updateRide(team.getSlug(), "test-ride", request));
  }

  @Test
  void updateRide_shouldThrowForInvalidEndPlaceId() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            TsidUtils.toString(9999L),
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(
        PedalonsException.class,
        () -> rideService.updateRide(team.getSlug(), "test-ride", request));
  }

  @Test
  void updateRide_shouldThrowForPlaceFromDifferentTeam() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    Team otherTeam = dataService.createTeam(user2, "Other Team", "other-team", Visibility.PUBLIC);
    var foreignPlace = dataService.createPlace(otherTeam, admin, "Foreign Place");
    String foreignPlaceId = TsidUtils.toString(foreignPlace.getId());

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            foreignPlaceId,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(
        PedalonsException.class,
        () -> rideService.updateRide(team.getSlug(), "test-ride", request));
  }

  @Test
  void updateRide_shouldClearStartAndEndPlaces() {
    var startPlace = dataService.createPlace(team, admin, "Start", true, false);
    var endPlace = dataService.createPlace(team, admin, "End", false, true);
    Ride ride = dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    ride.setStart(startPlace);
    ride.setEnd(endPlace);

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertNull(result.getStartPlace());
    assertNull(result.getEndPlace());
  }

  @Test
  void updateRide_shouldUpdateWithRoute() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    var route = dataService.createRoute(team, admin, "Test Route", Visibility.PUBLIC);

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            route.getSlug(),
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertNotNull(result.getRouteSlug());
    assertEquals(route.getSlug(), result.getRouteSlug());
  }

  @Test
  void updateRide_shouldThrowForInvalidRouteSlug() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            "nonexistent-route",
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(
        PedalonsException.class,
        () -> rideService.updateRide(team.getSlug(), "test-ride", request));
  }

  @Test
  void updateRide_shouldThrowForRouteFromDifferentTeam() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    Team otherTeam = dataService.createTeam(user2, "Other Team", "other-team", Visibility.PUBLIC);
    var foreignRoute =
        dataService.createRoute(otherTeam, admin, "Foreign Route", Visibility.PUBLIC);

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            foreignRoute.getSlug(),
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    assertThrows(
        PedalonsException.class,
        () -> rideService.updateRide(team.getSlug(), "test-ride", request));
  }

  @Test
  void updateRide_shouldThrowForPrivateRouteOnPublicRide() {
    dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    var privateRoute = dataService.createRoute(team, admin, "Private Route", Visibility.TEAM);

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            privateRoute.getSlug(),
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.updateRide(team.getSlug(), "test-ride", request));

    assertTrue(exception.getMessage().contains("PUBLIC_RIDE_PRIVATE_ROUTE"));
  }

  @Test
  void updateRide_shouldAllowTeamRouteOnTeamRide() {
    Ride ride =
        dataService.createRide(
            team, admin, "Team Ride", "team-ride", Instant.now(), Visibility.TEAM, Status.DRAFT);
    var teamRoute = dataService.createRoute(team, admin, "Team Route", Visibility.TEAM);

    RideRequest request =
        new RideRequest(
            "Team Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.TEAM,
            teamRoute.getSlug(),
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "team-ride", request);

    assertNotNull(result);
    assertEquals(teamRoute.getSlug(), result.getRouteSlug());
  }

  @Test
  void updateRide_shouldClearRoute() {
    var route = dataService.createRoute(team, admin, "Test Route", Visibility.PUBLIC);
    Ride ride = dataService.createRide(team, admin, "Test Ride", "test-ride", Instant.now());
    ride.setRoute(route);

    RideRequest request =
        new RideRequest(
            "Test Ride",
            MediaDto.builder().build(),
            wall(Instant.now().plusSeconds(24 * 3600)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(),
            null);

    userService.setUserForTest(organizer);
    RideDto result = rideService.updateRide(team.getSlug(), "test-ride", request);

    assertNull(result.getRouteSlug());
  }

  // ==================== Delete Ride ====================

  @Test
  void deleteRide_shouldSoftDelete() {
    dataService.createRide(team, admin, "Test", "test", Instant.now());

    userService.setUserForTest(organizer);
    rideService.deleteRide(team.getSlug(), "test");

    userService.setUserForTest(organizer);
    assertThrows(PedalonsException.class, () -> rideService.getDto(team.getSlug(), "test"));
  }

  @Test
  void deleteRide_shouldThrowForNonOrganizer() {
    dataService.createRide(team, admin, "Test", "test", Instant.now());

    userService.setUserForTest(member);
    assertThrows(PedalonsException.class, () -> rideService.deleteRide(team.getSlug(), "test"));
  }

  // ==================== Undelete Ride ====================

  @Test
  void undeleteRide_shouldRestoreDeletedRide() {
    dataService.createRide(team, admin, "Test", "test", Instant.now());

    userService.setUserForTest(organizer);
    rideService.deleteRide(team.getSlug(), "test");

    userService.setUserForTest(admin);
    RideDto result = rideService.undeleteRide(team.getSlug(), "test");

    assertFalse(result.isDeleted());
    assertEquals("test", result.getSlug());
  }

  @Test
  void undeleteRide_shouldThrowForNonOrganizer() {
    dataService.createRide(team, admin, "Test", "test", Instant.now());

    userService.setUserForTest(organizer);
    rideService.deleteRide(team.getSlug(), "test");

    userService.setUserForTest(member);
    assertThrows(PedalonsException.class, () -> rideService.undeleteRide(team.getSlug(), "test"));
  }

  // ==================== List Groups ====================

  @Test
  void listGroups_shouldReturnGroupsOrderedBySortOrder() {
    Ride ride = dataService.createRide(team, admin, "Test", "test", Instant.now());
    dataService.createRideGroup(admin, ride, "Group 1", 2);
    dataService.createRideGroup(admin, ride, "Group 2", 1);

    userService.setUserForTest(admin);
    RideDto rideDto = rideService.getDto(team.getSlug(), ride.getSlug());
    List<RideGroupDto> groups = rideDto.getGroups();

    assertEquals(2, groups.size());
    assertEquals("Group 2", groups.get(0).name());
    assertEquals("Group 1", groups.get(1).name());
  }

  @Test
  void listGroups_shouldReturnEmptyForNoGroups() {
    Ride ride = dataService.createRide(team, admin, "Test", "test", Instant.now());

    userService.setUserForTest(admin);
    RideDto rideDto = rideService.getDto(team.getSlug(), ride.getSlug());

    assertEquals(0, rideDto.getGroups().size());
    assertEquals(0, rideDto.getGroupCount());
  }

  // ==================== Join Group ====================

  @Test
  void joinGroup_shouldCreateParticipation() {
    Ride ride =
        dataService.createRide(
            team, admin, "Test", "test", Instant.now().plus(1, ChronoUnit.DAYS), Status.PUBLISHED);
    RideGroup group = dataService.createRideGroup(admin, ride, "Group");

    userService.setUserForTest(member);
    RideParticipationDto result = rideService.joinGroup(team.getSlug(), "test", group.getId());

    assertNotNull(result);
    assertEquals(member.getId(), TsidUtils.toLong(result.userId()));
  }

  @Test
  void joinGroup_shouldRefuseARideThatIsOver() {
    Ride ride =
        dataService.createRide(
            team,
            admin,
            "Yesterday",
            "yesterday",
            Instant.now().minus(1, ChronoUnit.DAYS),
            Status.PUBLISHED);
    RideGroup group = dataService.createRideGroup(admin, ride, "Group");

    userService.setUserForTest(member);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.joinGroup(team.getSlug(), "yesterday", group.getId()));

    assertEquals("RIDE_PAST", exception.getMessage());
  }

  @Test
  void joinGroup_shouldThrowForDraftRide() {
    Ride ride =
        dataService.createRide(
            team, admin, "Draft", "draft", Instant.now(), Visibility.PUBLIC, Status.DRAFT);
    RideGroup group = dataService.createRideGroup(admin, ride, "Group");

    userService.setUserForTest(member);
    assertThrows(
        PedalonsException.class,
        () -> rideService.joinGroup(team.getSlug(), "draft", group.getId()));
  }

  @Test
  void joinGroup_shouldThrowForDraftRideEvenForOrganizer() {
    Ride ride =
        dataService.createRide(
            team, admin, "Draft", "draft", Instant.now(), Visibility.PUBLIC, Status.DRAFT);
    RideGroup group = dataService.createRideGroup(admin, ride, "Group");

    userService.setUserForTest(organizer);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.joinGroup(team.getSlug(), "draft", group.getId()));

    assertTrue(exception.getMessage().contains("FORBIDDEN"));
  }

  @Test
  void joinGroup_shouldThrowWhenAlreadyInGroup() {
    Ride ride = dataService.createRide(team, admin, "Test", "test", Instant.now());
    RideGroup group = dataService.createRideGroup(admin, ride, "Group");
    dataService.createParticipation(group, member);

    userService.setUserForTest(member);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.joinGroup(team.getSlug(), "test", group.getId()));

    assertTrue(exception.getMessage().contains("ALREADY_REGISTERED"));
  }

  @Test
  void joinGroup_shouldThrowWhenGroupFull() {
    Ride ride =
        dataService.createRide(team, admin, "Test", "test", Instant.now().plus(1, ChronoUnit.DAYS));
    RideGroup group = dataService.createRideGroupWithMaxParticipants(admin, ride, "Group", 1);
    dataService.createParticipation(group, organizer);

    userService.setUserForTest(member);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.joinGroup(team.getSlug(), "test", group.getId()));

    assertTrue(exception.getMessage().contains("GROUP_FULL"));
  }

  // ==================== Leave Group ====================

  @Test
  void leaveGroup_shouldRemoveParticipation() {
    Ride ride =
        dataService.createRide(team, admin, "Test", "test", Instant.now().plus(1, ChronoUnit.DAYS));
    RideGroup group = dataService.createRideGroup(admin, ride, "Group");
    dataService.createParticipation(group, member);

    userService.setUserForTest(member);
    rideService.leaveGroup(team.getSlug(), "test", group.getId());

    // Member can now rejoin (participation was soft-deleted)
    userService.setUserForTest(member);
    RideParticipationDto newParticipation =
        rideService.joinGroup(team.getSlug(), "test", group.getId());
    assertNotNull(newParticipation);
  }

  @Test
  void leaveGroup_shouldThrowWhenNotInGroup() {
    Ride ride = dataService.createRide(team, admin, "Test", "test", Instant.now());
    RideGroup group = dataService.createRideGroup(admin, ride, "Group");

    userService.setUserForTest(member);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.leaveGroup(team.getSlug(), "test", group.getId()));

    assertTrue(exception.getMessage().contains("NOT_REGISTERED"));
  }

  // ==================== Join, judged on the group (docs/LEDGER_*.md API-170) ====================

  @Test
  void joinGroup_aLaterGroup_shouldStayOpenOnceTheRideHasLeft() {
    Ride ride =
        dataService.createRide(
            team,
            admin,
            "Two starts",
            "two-starts",
            Instant.now().minus(1, ChronoUnit.HOURS),
            Status.PUBLISHED);
    RideGroup later = dataService.createRideGroup(admin, ride, "Later");
    dataService.setRideGroupStart(later, Instant.now().plus(1, ChronoUnit.HOURS));

    userService.setUserForTest(member);
    RideParticipationDto result =
        rideService.joinGroup(team.getSlug(), "two-starts", later.getId());

    assertEquals(member.getId(), TsidUtils.toLong(result.userId()));
  }

  @Test
  void joinGroup_aGroupGone_shouldBeRefused_evenWhenTheRideIsAhead() {
    Ride ride =
        dataService.createRide(
            team,
            admin,
            "Early group",
            "early-group",
            Instant.now().plus(1, ChronoUnit.HOURS),
            Status.PUBLISHED);
    RideGroup early = dataService.createRideGroup(admin, ride, "Early");
    dataService.setRideGroupStart(early, Instant.now().minus(1, ChronoUnit.HOURS));

    userService.setUserForTest(member);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.joinGroup(team.getSlug(), "early-group", early.getId()));

    assertEquals("RIDE_PAST", exception.getMessage());
  }

  // ==================== Switch Group (docs/LEDGER_*.md API-171) ====================

  /** The group the member is registered in on {@code ride}, null when none. */
  private Long registeredGroupOf(User user, Ride ride) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            participationRepository
                .findByUserAndRide(user.getId(), ride.getId())
                .map(p -> p.getRideGroup().getId())
                .orElse(null));
  }

  private Ride tomorrowRide(String slug) {
    return dataService.createRide(
        team, admin, "Ride " + slug, slug, Instant.now().plus(1, ChronoUnit.DAYS));
  }

  @Test
  void switchGroup_shouldMoveTheRegistration() {
    Ride ride = tomorrowRide("switch");
    RideGroup a = dataService.createRideGroup(admin, ride, "A", 0);
    RideGroup b = dataService.createRideGroup(admin, ride, "B", 1);
    dataService.createParticipation(a, member);

    userService.setUserForTest(member);
    RideSwitchAnswer result = rideService.switchGroup(team.getSlug(), "switch", b.getId());

    assertTrue(result.created());
    assertEquals(member.getId(), TsidUtils.toLong(result.participation().userId()));
    assertEquals(b.getId(), registeredGroupOf(member, ride));
    assertEquals(
        1,
        (long)
            QuarkusTransaction.requiringNew()
                .call(() ->
                    participationRepository.count(
                        "user.id = ?1 and rideGroup.ride.id = ?2", member.getId(), ride.getId())));
  }

  @Test
  void switchGroup_toTheGroupAlreadyJoined_shouldChangeNothing() {
    Ride ride = tomorrowRide("switch-same");
    RideGroup a = dataService.createRideGroup(admin, ride, "A", 0);
    var participation = dataService.createParticipation(a, member);

    userService.setUserForTest(member);
    RideSwitchAnswer result = rideService.switchGroup(team.getSlug(), "switch-same", a.getId());

    assertFalse(result.created());
    assertEquals(participation.getId(), TsidUtils.toLong(result.participation().id()));
    assertEquals(a.getId(), registeredGroupOf(member, ride));
  }

  @Test
  void switchGroup_toAFullGroup_shouldKeepTheRegistration() {
    Ride ride = tomorrowRide("switch-full");
    RideGroup a = dataService.createRideGroup(admin, ride, "A", 0);
    RideGroup full = dataService.createRideGroupWithMaxParticipants(admin, ride, "Full", 1);
    dataService.createParticipation(a, member);
    dataService.createParticipation(full, organizer);

    userService.setUserForTest(member);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.switchGroup(team.getSlug(), "switch-full", full.getId()));

    assertTrue(exception.getMessage().contains("GROUP_FULL"));
    assertEquals(a.getId(), registeredGroupOf(member, ride));
  }

  @Test
  void switchGroup_toAGroupGone_shouldKeepTheRegistration() {
    Ride ride = tomorrowRide("switch-gone");
    RideGroup a = dataService.createRideGroup(admin, ride, "A", 0);
    RideGroup gone = dataService.createRideGroup(admin, ride, "Gone", 1);
    dataService.setRideGroupStart(gone, Instant.now().minus(1, ChronoUnit.HOURS));
    dataService.createParticipation(a, member);

    userService.setUserForTest(member);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.switchGroup(team.getSlug(), "switch-gone", gone.getId()));

    assertEquals("RIDE_PAST", exception.getMessage());
    assertEquals(a.getId(), registeredGroupOf(member, ride));
  }

  @Test
  void switchGroup_withoutARegistration_shouldBeRefused() {
    Ride ride = tomorrowRide("switch-none");
    RideGroup a = dataService.createRideGroup(admin, ride, "A", 0);

    userService.setUserForTest(member);
    PedalonsException exception =
        assertThrows(
            PedalonsException.class,
            () -> rideService.switchGroup(team.getSlug(), "switch-none", a.getId()));

    assertTrue(exception.getMessage().contains("NOT_REGISTERED"));
    assertNull(registeredGroupOf(member, ride));
  }

  @Test
  void switchGroup_toAGroupOfAnotherRide_shouldBeNotFound() {
    Ride ride = tomorrowRide("switch-here");
    Ride other = tomorrowRide("switch-there");
    RideGroup a = dataService.createRideGroup(admin, ride, "A", 0);
    RideGroup elsewhere = dataService.createRideGroup(admin, other, "Elsewhere", 0);
    dataService.createParticipation(a, member);

    userService.setUserForTest(member);
    assertThrows(
        NotFoundException.class,
        () -> rideService.switchGroup(team.getSlug(), "switch-here", elsewhere.getId()));

    assertEquals(a.getId(), registeredGroupOf(member, ride));
    assertNull(registeredGroupOf(member, other));
  }

  @Test
  void switchGroup_ofACancelledRide_shouldBeRefused() {
    Ride ride =
        dataService.createRide(
            team,
            admin,
            "Cancelled",
            "switch-cancelled",
            Instant.now().plus(1, ChronoUnit.DAYS),
            Status.PUBLISHED);
    RideGroup a = dataService.createRideGroup(admin, ride, "A", 0);
    RideGroup b = dataService.createRideGroup(admin, ride, "B", 1);
    dataService.createParticipation(a, member);
    QuarkusTransaction.requiringNew()
        .run(() -> dataService.getRide(ride.getId()).setStatus(Status.CANCELLED));

    userService.setUserForTest(member);
    assertThrows(
        PedalonsException.class,
        () -> rideService.switchGroup(team.getSlug(), "switch-cancelled", b.getId()));

    assertEquals(a.getId(), registeredGroupOf(member, ride));
  }
}
