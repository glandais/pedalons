package fr.pedalons.service.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.ContentPermissionsDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.service.ride.RideService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.SecurityVerifier;
import fr.pedalons.service.trip.TripService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.UserTransaction;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The permissions block and the access checkers cannot diverge (docs/LEDGER_*.md API-176): for every
 * entity type, every caller and every kind of team, what the block says the caller may do is what
 * {@link SecurityVerifier} — the checker, platform admin bypass included — answers for the action
 * behind it. A rule changed in a checker and not in {@code ContentPermissions} (or the reverse)
 * fails here.
 *
 * <p>Only the entities the caller can read are compared: the block is never served to anyone else.
 *
 * <p>{@code canRegister} is compared with what the join itself answers — {@code
 * RideService.joinGroup} or {@code TripService.joinTrip}, run in a transaction rolled back after —
 * not with the access check alone: the joins also refuse an unpublished entity for everyone, a
 * ride whose groups have all left ({@code RIDE_PAST}) and a finished trip ({@code TRIP_FINISHED}),
 * which the block of a detail must say too. The fixture holds such a ride and such a trip in every
 * team.
 */
@QuarkusTest
class ContentPermissionsConsistencyTest extends AbstractResourceTest {

  @Inject SecurityVerifier securityVerifier;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject MemberNamesVisibility memberNamesVisibility;
  @Inject DomainResolver domainResolver;
  @Inject RideService rideService;
  @Inject TripService tripService;
  @Inject EntityManager entityManager;
  @Inject UserTransaction userTransaction;

  private Team unlistedTeam;
  private final List<TeamEntity> entities = new ArrayList<>();
  private final List<@Nullable User> callers = new ArrayList<>();

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    dataService.setTeamPublicContentAllowed(team2, true);
    unlistedTeam =
        dataService.createTeam(user1, "Unlisted", "unlisted", Visibility.PUBLIC_UNLISTED);
    dataService.addUserToTeam(user2, unlistedTeam, TeamRole.ORGANIZER);
    dataService.addUserToTeam(user3, unlistedTeam, TeamRole.MEMBER);

    // Modules off: the checkers refuse the writes early in hasRights, and also inside the static
    // canWrite the block calls. Only a team with them off tells the two apart.
    Team withoutTripsOrPosts = moduleTeam("No trips", "no-trips", true, false, false);
    Team withoutRoutes = moduleTeam("No routes", "no-routes", false, true, true);

    Instant soon = Instant.now().plus(7, ChronoUnit.DAYS);
    Instant past = Instant.now().minus(2, ChronoUnit.DAYS);
    for (Team team : List.of(team1, unlistedTeam, team2, withoutTripsOrPosts, withoutRoutes)) {
      String p = team.getSlug() + "-";
      // Every ride has a group to join: the join is asked for one.
      List<Ride> rides =
          List.of(
              dataService.createRide(team, user1, "Ride", p + "ride", soon, Visibility.PUBLIC),
              dataService.createRide(
                  team, user1, "Team Ride", p + "team-ride", soon, Visibility.TEAM),
              dataService.createRide(
                  team, user1, "Draft", p + "draft", soon, Visibility.PUBLIC, Status.DRAFT),
              // Its only group has left: RIDE_PAST.
              dataService.createRide(team, user1, "Past", p + "past", past, Visibility.PUBLIC));
      for (Ride ride : rides) {
        dataService.createRideGroup(user1, ride, "Group");
        entities.add(ride);
      }
      entities.add(dataService.createRoute(team, user1, p + "Route", Visibility.PUBLIC));
      entities.add(
          dataService.createPost(team, user2, p + "Post", Instant.now(), Visibility.PUBLIC));
      Trip trip = dataService.createTrip(team, user1, p + "Trip", soon, Visibility.PUBLIC);
      entities.add(trip);
      entities.add(dataService.createTripStage(user1, trip, p + "Stage", 0));
      // Over, its stage included: TRIP_FINISHED.
      Trip finished = dataService.createTrip(team, user1, p + "Finished", past, Visibility.PUBLIC);
      dataService.createTripStage(user1, finished, p + "Finished Stage", past);
      entities.add(finished);
      Trip draftTrip =
          dataService.createTrip(
              team, user1, p + "Draft Trip", soon, Visibility.PUBLIC, Status.DRAFT, null);
      entities.add(draftTrip);
      entities.add(dataService.createAdditionalPage(team, user1, p + "Page", 0, Visibility.PUBLIC));
      // Written by a plain member: the author's right is the ad's own.
      entities.add(dataService.createAd(team, user3, p + "Ad", AdType.SALE));
    }

    User root = dataService.createPlatformAdminUser("root@example.com", "Root");
    callers.addAll(Arrays.asList(null, user1, user2, user3, user4, user5, root));
  }

  /**
   * A public team with the same members as {@code unlistedTeam}, rides off and the given modules.
   * The flags are set on the instance in hand too, which the entities created below keep as their
   * team; the block itself is computed on the entity reloaded from the database, as the checkers
   * read it.
   */
  private Team moduleTeam(String name, String slug, boolean routes, boolean trips, boolean posts) {
    Team team = dataService.createTeam(user1, name, slug, Visibility.PUBLIC);
    dataService.addUserToTeam(user2, team, TeamRole.ORGANIZER);
    dataService.addUserToTeam(user3, team, TeamRole.MEMBER);
    dataService.setTeamFeatureFlags(team, false, routes, trips, posts, true);
    team.setEnableRides(false);
    team.setEnableRoutes(routes);
    team.setEnableTrips(trips);
    team.setEnablePosts(posts);
    team.setEnableAds(true);
    return team;
  }

  /**
   * The block of a detail, computed on the entity reloaded in a transaction, as a detail endpoint
   * does: its groups and stages are the database's, loaded on demand.
   */
  private ContentPermissionsDto detailBlock(ContentPermissions permissions, TeamEntity entity)
      throws Exception {
    userTransaction.begin();
    try {
      TeamEntity loaded = entityManager.find(TeamEntity.class, entity.getId());
      return permissions.of(loaded);
    } finally {
      userTransaction.rollback();
    }
  }

  /**
   * What the join endpoint answers the current caller — the access check, the platform admin's
   * bypass and the join's own tests together — in a transaction rolled back after, so the fixture
   * stays as it is. Any refusal ({@code ForbiddenException}, {@code RIDE_PAST}, {@code
   * TRIP_FINISHED}…) is a no; the code is in the message for a failure to read.
   */
  private boolean joinAnswer(TeamEntity entity, StringBuilder refusal) throws Exception {
    String teamSlug = entity.getTeam().getSlug();
    userTransaction.begin();
    try {
      if (entity instanceof Ride) {
        Ride ride = entityManager.find(Ride.class, entity.getId());
        Long groupId = ride.getGroups().getFirst().getId();
        rideService.joinGroup(teamSlug, entity.getSlug(), groupId);
      } else {
        tripService.joinTrip(teamSlug, entity.getSlug());
      }
      return true;
    } catch (PedalonsException e) {
      refusal.append(e.getClass().getSimpleName()).append(' ').append(e.getErrorCode());
      return false;
    } finally {
      userTransaction.rollback();
    }
  }

  /** True, false, or null when the entity is not even readable (a 404). */
  private @Nullable Boolean verdict(EntityType type, ActionType action, List<Object> params) {
    try {
      securityVerifier.verifyAccess(type, action, params);
      return true;
    } catch (ForbiddenException e) {
      return false;
    } catch (NotFoundException e) {
      return null;
    }
  }

  @Test
  void theBlock_isWhatTheCheckersDecide() throws Exception {
    int compared = 0;
    int pastCompared = 0;
    for (User caller : callers) {
      for (TeamEntity entity : entities) {
        pedalonsContext.setUserForTest(caller);
        Team team = entity.getTeam();
        EntityType type = entity.getEntityType();
        List<Object> params = List.of(team.getSlug(), entity.getSlug());
        if (!Boolean.TRUE.equals(verdict(type, ActionType.READ, params))) {
          continue;
        }
        compared++;
        String where =
            type
                + " "
                + entity.getSlug()
                + " for "
                + (caller == null ? "anonymous" : caller.getEmail());
        CallerRoles roles = memberNamesVisibility.callerRoles(team.getId());
        ContentPermissions permissions = ContentPermissions.forDetail(roles);
        ContentPermissionsDto block = detailBlock(permissions, entity);

        // A stage is written through its trip.
        EntityType writtenAs = type == EntityType.TRIP_STAGE ? EntityType.TRIP : type;
        List<Object> writtenParams =
            entity instanceof TripStage stage
                ? List.of(team.getSlug(), stage.getTrip().getSlug())
                : params;
        assertEquals(
            verdict(writtenAs, ActionType.UPDATE, writtenParams), block.canEdit(), "edit " + where);
        assertEquals(
            verdict(writtenAs, ActionType.DELETE, writtenParams),
            block.canDelete(),
            "delete " + where);

        if (type == EntityType.RIDE || type == EntityType.TRIP) {
          // Strictly what the server answers, the platform admin included: both joins refuse an
          // unpublished entity for everyone, and the detail block reads their timing tests.
          StringBuilder refusal = new StringBuilder();
          boolean joined = joinAnswer(entity, refusal);
          assertEquals(joined, block.canRegister(), "register " + where + " (" + refusal + ")");
          if (entity.getSlug().endsWith("past") || entity.getSlug().contains("finished")) {
            pastCompared++;
          }
          assertEquals(
              memberNamesVisibility.canSeeNames(team.getId()),
              block.canSeeParticipants(),
              "participants " + where);
        }
        if (block.canComment() != null) {
          assertEquals(
              verdict(EntityType.COMMENT, ActionType.LIST, List.of(team.getSlug())),
              block.canComment(),
              "comment " + where);
        }
        assertEquals(
            verdict(EntityType.TEAM, ActionType.READ, List.of(team.getSlug())),
            permissions.teamAccessible(team),
            "accessible " + where);
      }
    }
    // The fixture must keep exercising every type for readers and outsiders alike.
    assertTrue(compared > entities.size() * 3, "only " + compared + " comparisons");
    // And the timing refusals, for the members who would otherwise be let in.
    assertTrue(pastCompared > 10, "only " + pastCompared + " past or finished comparisons");
  }
}
