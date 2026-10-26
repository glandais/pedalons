package fr.pedalons.api.common;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.specification.RequestSpecification;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The names of a team's members are never sent to someone who is not a member of that team
 * (docs/LEDGER_*.md API-144): an anonymous visitor, a person of no team, a member of another team
 * all get the counts only. A member and a platform administrator keep the names.
 *
 * <p>Everything is read from a PUBLIC ride, trip, post and route of a PUBLIC team, so that the
 * non-members <em>can</em> read the publication — the only thing that changes is the names.
 */
@QuarkusTest
class MemberNamesVisibilityResourceTest extends AbstractResourceTest {

  private static final String ROOT = "root";

  /** Readers who are not a member of team1: anonymous, no team at all, a member of another team. */
  private static final String[] OUTSIDERS = {null, USER5, USER4};

  /** Readers who may see the names: a member (user3) and a platform administrator. */
  private static final String[] INSIDERS = {USER3, ROOT};

  private String rideSlug;
  private String tripSlug;
  private String postSlug;
  private String routeSlug;
  private RideGroup group;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.createPlatformAdminUser("root@example.com", "Root");
    // user4 belongs to a team, but not to team1.
    dataService.createTeam(user4, "Other Team", "other-team", Visibility.PUBLIC);

    Ride ride =
        dataService.createRide(
            team1,
            user1,
            "Public Ride",
            "public-ride",
            Instant.now().plus(7, ChronoUnit.DAYS),
            Visibility.PUBLIC);
    rideSlug = ride.getSlug();
    group = dataService.createRideGroup(user1, ride, "Fast", 0);
    dataService.setRideGroupLeader(group, user2);
    dataService.createParticipation(group, user2);
    dataService.createParticipation(group, user3);

    Trip trip =
        dataService.createTrip(
            team1, user1, "Public Trip", Instant.now().plus(7, ChronoUnit.DAYS), Visibility.PUBLIC);
    dataService.createTripStage(user1, trip, "Public Trip Stage", 0);
    dataService.createTripParticipation(trip, user2);
    dataService.createTripParticipation(trip, user3);
    tripSlug = trip.getSlug();

    Post post = dataService.createPost(team1, user2, "Signed Post", Instant.now());
    dataService.setPostSignedAsTeam(post, false);
    postSlug = post.getSlug();

    Route route = dataService.createRoute(team1, user1, "Public Route");
    routeSlug = route.getSlug();
  }

  private RequestSpecification as(@Nullable String user) {
    RequestSpecification spec = given();
    return user == null ? spec : spec.auth().oauth2(getAccessToken(user));
  }

  private String teamPath() {
    return "/api/teams/" + team1Slug;
  }

  // ---- ride ----

  @Test
  void rideDetail_nonMembersGetTheCountsOnly() {
    for (String reader : OUTSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/rides/" + rideSlug)
          .then()
          .statusCode(200)
          .body("participantCount", equalTo(2))
          .body("topParticipants", empty())
          .body("groups[0].countParticipants", equalTo(2))
          .body("groups[0].participants", empty())
          .body("groups[0].leader", nullValue());
    }
  }

  @Test
  void rideDetail_membersAndPlatformAdminsKeepTheNames() {
    for (String reader : INSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/rides/" + rideSlug)
          .then()
          .statusCode(200)
          .body("topParticipants", hasSize(2))
          .body("groups[0].participants", hasSize(2))
          .body("groups[0].leader.id", equalTo(TsidUtils.toString(user2.getId())));
    }
  }

  @Test
  void rideListings_nonMembersGetTheCountsOnly() {
    for (String reader : OUTSIDERS) {
      for (String url :
          new String[] {teamPath() + "/publications?type=RIDE", "/api/publications?type=RIDE"}) {
        as(reader)
            .when()
            .get(url)
            .then()
            .statusCode(200)
            .body("publications.find { it.slug == 'public-ride' }.participantCount", equalTo(2))
            .body("publications.find { it.slug == 'public-ride' }.topParticipants", empty());
      }
    }
  }

  @Test
  void rideListings_membersAndPlatformAdminsKeepTheNames() {
    for (String reader : INSIDERS) {
      for (String url :
          new String[] {teamPath() + "/publications?type=RIDE", "/api/publications?type=RIDE"}) {
        as(reader)
            .when()
            .get(url)
            .then()
            .statusCode(200)
            .body("publications.find { it.slug == 'public-ride' }.topParticipants", hasSize(2));
      }
    }
  }

  @Test
  void formerMember_ownRegisteredGroupOnAListRow_carriesNeitherLeaderNorParticipants() {
    User former = dataService.createUser("former@example.com", "Former Member");
    dataService.addUserToTeam(former, team1, TeamRole.MEMBER);
    dataService.createParticipation(group, former);
    dataService.removeMember(former, team1);

    as("former")
        .when()
        .get("/api/users/me/participations?view=COMPACT")
        .then()
        .statusCode(200)
        .body(
            "publications.find { it.slug == '" + rideSlug + "' }.registeredGroup.countParticipants",
            equalTo(3))
        .body(
            "publications.find { it.slug == '" + rideSlug + "' }.registeredGroup.leader",
            nullValue())
        .body(
            "publications.find { it.slug == '" + rideSlug + "' }.registeredGroup.participants",
            empty());
  }

  // ---- participants endpoints ----

  @Test
  void rideParticipants_areRefusedToNonMembers_likeTheComments() {
    String path = teamPath() + "/rides/" + rideSlug + "/participants";
    // Anonymous: 401, a signed-in outsider: 403 — the same statuses as the comment thread.
    as(null).when().get(path).then().statusCode(401);
    for (String reader : new String[] {USER5, USER4}) {
      as(reader).when().get(path).then().statusCode(403);
    }
    // The search matches names: it is refused too, it must not leak through a probe.
    as(USER4).when().get(path + "?search=user").then().statusCode(403);
  }

  @Test
  void rideParticipants_areAllowedToMembersAndPlatformAdmins() {
    for (String reader : INSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/rides/" + rideSlug + "/participants")
          .then()
          .statusCode(200)
          .body("total", equalTo(2))
          .body(
              "participants.displayName", contains(user2.getDisplayName(), user3.getDisplayName()));
    }
  }

  @Test
  void tripParticipants_areRefusedToNonMembers_andAllowedToMembersAndPlatformAdmins() {
    String path = teamPath() + "/trips/" + tripSlug + "/participants";
    as(null).when().get(path).then().statusCode(401);
    for (String reader : new String[] {USER5, USER4}) {
      as(reader).when().get(path).then().statusCode(403);
    }
    for (String reader : INSIDERS) {
      as(reader).when().get(path).then().statusCode(200).body("total", equalTo(2));
    }
  }

  // ---- trip ----

  @Test
  void tripDetail_nonMembersGetTheCountOnly() {
    for (String reader : OUTSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/trips/" + tripSlug)
          .then()
          .statusCode(200)
          .body("participantCount", equalTo(2))
          .body("participants", empty());
    }
    for (String reader : INSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/trips/" + tripSlug)
          .then()
          .statusCode(200)
          .body("participants", hasSize(2));
    }
  }

  // ---- post ----

  @Test
  void authorSignedPost_namesItsAuthorToTheMembersOnly() {
    String authorId = TsidUtils.toString(user2.getId());
    for (String reader : OUTSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/posts/" + postSlug)
          .then()
          .statusCode(200)
          .body("signedAsTeam", equalTo(false))
          .body("createdBy", nullValue());
      as(reader)
          .when()
          .get(teamPath() + "/publications?type=POST")
          .then()
          .statusCode(200)
          .body("publications[0].createdBy", nullValue());
    }
    for (String reader : INSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/posts/" + postSlug)
          .then()
          .statusCode(200)
          .body("createdBy.id", equalTo(authorId));
      as(reader)
          .when()
          .get("/api/publications?type=POST")
          .then()
          .statusCode(200)
          .body("publications.createdBy.id", hasItem(authorId));
    }
  }

  // ---- route ----

  @Test
  void routeDetail_createdByIsNullForNonMembers() {
    String creatorId = TsidUtils.toString(user1.getId());
    for (String reader : OUTSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/routes/" + routeSlug)
          .then()
          .statusCode(200)
          .body("createdBy", nullValue());
      as(reader)
          .queryParam("slug", routeSlug)
          .when()
          .get(teamPath() + "/routes/bulk")
          .then()
          .statusCode(200)
          .body("routes[0].createdBy", nullValue());
    }
    for (String reader : INSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/routes/" + routeSlug)
          .then()
          .statusCode(200)
          .body("createdBy.id", equalTo(creatorId));
      as(reader)
          .queryParam("slug", routeSlug)
          .when()
          .get(teamPath() + "/routes/bulk")
          .then()
          .statusCode(200)
          .body("routes[0].createdBy.id", equalTo(creatorId));
    }
  }
}
