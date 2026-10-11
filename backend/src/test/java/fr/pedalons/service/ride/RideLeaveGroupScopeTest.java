package fr.pedalons.service.ride;

/*
 * Bug: RideService.leaveGroup authorises against the ride slug in the URL (RideAccessChecker
 * LEAVE: that ride is PUBLISHED and the caller has a role in its team) but then deletes by
 * groupId alone (RideParticipationRepository.findByUserAndGroup has no rideGroup.ride.id
 * predicate). A caller can therefore unregister from a group of a CANCELLED/DRAFT ride, or of a
 * ride of a team they are no longer a member of, by going through the URL of any published ride
 * they can access. joinGroup scopes the group with rideGroupRepository.findByIdAndRide; leaveGroup
 * must do the same.
 *
 * Found by the formal model of the ride join/leave authorisation (TLA+/TLC, rides subsystem): the
 * invariant "a participation is only deleted through the ride that owns its group" is violated.
 *
 * These tests fail on the current code (the call returns normally and the row is deleted) and
 * pass once leaveGroup scopes the group to the ride resolved from rideSlug.
 */

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ride.RideParticipation;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.ride.RideParticipationRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class RideLeaveGroupScopeTest extends AbstractBaseTest {

  @Inject RideService rideService;
  @Inject RideParticipationRepository participationRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext userService;
  @Inject DomainResolver domainResolver;

  private Team teamA;
  private User admin;
  private User member;
  private Ride publishedRide;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    teamA = dataService.createTeam(admin, "Team A", "team-a", Visibility.PUBLIC);
    member = dataService.createUser("member@example.com", "Member");
    dataService.addUserToTeam(member, teamA, TeamRole.MEMBER);
    publishedRide =
        dataService.createRide(
            teamA, admin, "Published", "published", Instant.now().plus(1, ChronoUnit.DAYS));
    dataService.createRideGroup(admin, publishedRide, "Published group");
  }

  @Test
  void leaveGroup_viaPublishedRideUrl_mustNotDeleteParticipationInCancelledRideOfSameTeam() {
    Ride cancelled =
        dataService.createRide(
            teamA,
            admin,
            "Cancelled",
            "cancelled",
            Instant.now().plus(2, ChronoUnit.DAYS),
            Status.CANCELLED);
    RideGroup cancelledGroup = dataService.createRideGroup(admin, cancelled, "Cancelled group");
    RideParticipation participation = dataService.createParticipation(cancelledGroup, member);

    userService.setUserForTest(member);
    assertThrows(
        PedalonsException.class,
        () ->
            rideService.leaveGroup(
                teamA.getSlug(), publishedRide.getSlug(), cancelledGroup.getId()),
        "a group of another ride must not be reachable through the published ride's URL");

    assertNotNull(
        participationRepository.findById(participation.getId()),
        "the participation in the cancelled ride must still exist");
  }

  @Test
  void leaveGroup_viaPublishedRideUrl_mustNotDeleteParticipationInRideOfAnotherTeam() {
    // member is not (or no longer) a member of team B
    Team teamB = dataService.createTeam(admin, "Team B", "team-b", Visibility.PUBLIC);
    Ride rideB =
        dataService.createRide(
            teamB, admin, "Ride B", "ride-b", Instant.now().plus(2, ChronoUnit.DAYS));
    RideGroup groupB = dataService.createRideGroup(admin, rideB, "Group B");
    RideParticipation participation = dataService.createParticipation(groupB, member);

    userService.setUserForTest(member);
    assertThrows(
        PedalonsException.class,
        () -> rideService.leaveGroup(teamA.getSlug(), publishedRide.getSlug(), groupB.getId()),
        "a group of another team's ride must not be reachable through team A's ride URL");

    assertNotNull(
        participationRepository.findById(participation.getId()),
        "the participation in team B's ride must still exist");
  }
}
