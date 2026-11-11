package fr.pedalons.api.common;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.anyOf;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.nullValue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.specification.RequestSpecification;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * A private team the platform admin allowed may publish an entity by link (docs/LEDGER_*.md
 * API-176): its detail answers anyone, without a member's name, while the team itself, its
 * listings, its dashboard, the sitemap, the participants and the comments stay closed.
 *
 * <p>{@code team2} of the standard fixture is private: user1 admin, user2 organizer, user3 member.
 * user4 and user5 belong to no team of it.
 */
@QuarkusTest
class PrivateTeamPublicContentResourceTest extends AbstractResourceTest {

  /** Not members of team2: anonymous, no team at all, and user5 likewise. */
  private static final String[] OUTSIDERS = {null, USER4, USER5};

  /** Signed-in outsiders, for the endpoints that answer 401 to an anonymous caller. */
  private static final String[] SIGNED_OUTSIDERS = {USER4, USER5};

  private static final String PUBLIC_RIDE = "link-ride";
  private static final String UNLISTED_RIDE = "unlisted-ride";
  private static final String TEAM_RIDE = "team-ride";
  private static final String DRAFT_RIDE = "draft-ride";

  private String routeSlug;
  private String postSlug;
  private String tripSlug;
  private String publicTripSlug;
  private String stageSlug;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setTeamPublicContentAllowed(team2, true);
    Instant soon = Instant.now().plus(7, ChronoUnit.DAYS);

    for (String slug : new String[] {PUBLIC_RIDE, UNLISTED_RIDE}) {
      Ride ride =
          dataService.createRide(
              team2,
              user1,
              "Ride " + slug,
              slug,
              soon,
              slug.equals(PUBLIC_RIDE) ? Visibility.PUBLIC : Visibility.PUBLIC_UNLISTED);
      RideGroup group = dataService.createRideGroup(user1, ride, "Fast", 0);
      dataService.setRideGroupLeader(group, user2);
      dataService.createParticipation(group, user2);
      dataService.createParticipation(group, user3);
    }
    dataService.createRide(team2, user1, "Team Ride", TEAM_RIDE, soon, Visibility.TEAM);
    dataService.createRide(
        team2, user1, "Draft Ride", DRAFT_RIDE, soon, Visibility.PUBLIC, Status.DRAFT);

    routeSlug = dataService.createRoute(team2, user1, "Link Route", Visibility.PUBLIC).getSlug();

    Post post = dataService.createPost(team2, user2, "Link Post", Instant.now(), Visibility.PUBLIC);
    dataService.setPostSignedAsTeam(post, false);
    postSlug = post.getSlug();

    Trip trip = dataService.createTrip(team2, user1, "Link Trip", soon, Visibility.PUBLIC_UNLISTED);
    stageSlug = dataService.createTripStage(user1, trip, "Link Stage", 0).getSlug();
    dataService.createTripParticipation(trip, user2);
    dataService.createTripParticipation(trip, user3);
    tripSlug = trip.getSlug();
    // PUBLIC, unlike the unlisted one above: only a PUBLIC entity puts the listings' team clause to
    // the test, since their own te.visibility = 'PUBLIC' clause already leaves an unlisted one out.
    publicTripSlug =
        dataService.createTrip(team2, user1, "Public Link Trip", soon, Visibility.PUBLIC).getSlug();
  }

  private RequestSpecification as(@Nullable String user) {
    RequestSpecification spec = given();
    return user == null ? spec : spec.auth().oauth2(getAccessToken(user));
  }

  private String teamPath() {
    return "/api/teams/" + team2Slug;
  }

  // ---- read by link ----

  @Test
  void rideDetail_publicOrUnlisted_isReadableByLink_withoutAName() {
    for (String reader : OUTSIDERS) {
      for (String slug : new String[] {PUBLIC_RIDE, UNLISTED_RIDE}) {
        as(reader)
            .when()
            .get(teamPath() + "/rides/" + slug)
            .then()
            .statusCode(200)
            .body("team.slug", equalTo(team2Slug))
            .body("participantCount", equalTo(2))
            .body("topParticipants", empty())
            .body("groups[0].countParticipants", equalTo(2))
            .body("groups[0].participants", empty())
            .body("groups[0].leader", nullValue());
      }
    }
  }

  @Test
  void rideDetail_teamOnlyOrDraft_staysClosedToOutsiders() {
    for (String reader : OUTSIDERS) {
      for (String slug : new String[] {TEAM_RIDE, DRAFT_RIDE}) {
        as(reader).when().get(teamPath() + "/rides/" + slug).then().statusCode(404);
      }
    }
  }

  @Test
  void rideDetail_membersKeepTheNames() {
    as(USER3)
        .when()
        .get(teamPath() + "/rides/" + PUBLIC_RIDE)
        .then()
        .statusCode(200)
        .body("topParticipants", hasSize(2))
        .body("groups[0].participants", hasSize(2));
  }

  @Test
  void routeDetail_isReadableByLink_withoutItsCreator() {
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
          .body("routes", hasSize(1))
          .body("routes[0].createdBy", nullValue());
    }
  }

  @Test
  void postDetail_isReadableByLink_withoutItsAuthor() {
    for (String reader : OUTSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/posts/" + postSlug)
          .then()
          .statusCode(200)
          .body("signedAsTeam", equalTo(false))
          .body("createdBy", nullValue());
    }
  }

  @Test
  void tripDetail_andItsStages_areReadableByLink_withoutAName() {
    for (String reader : OUTSIDERS) {
      as(reader)
          .when()
          .get(teamPath() + "/trips/" + tripSlug)
          .then()
          .statusCode(200)
          .body("participantCount", equalTo(2))
          .body("participants", empty())
          .body("stages.slug", hasItem(stageSlug));
    }
  }

  @Test
  void publicTripDetail_isReadableByLink() {
    for (String reader : OUTSIDERS) {
      as(reader).when().get(teamPath() + "/trips/" + publicTripSlug).then().statusCode(200);
    }
  }

  /**
   * Withdrawing the flag stops new non-TEAM content, never what is already published: it stays
   * readable by link (plan 2026-11-11 §4.2). Closing it all is the switch of the team to private.
   */
  @Test
  void flagWithdrawn_publishedContent_staysReadableByLink() {
    dataService.setTeamPublicContentAllowed(team2, false);
    for (String reader : OUTSIDERS) {
      for (String slug : new String[] {PUBLIC_RIDE, UNLISTED_RIDE}) {
        as(reader).when().get(teamPath() + "/rides/" + slug).then().statusCode(200);
      }
      as(reader).when().get(teamPath() + "/routes/" + routeSlug).then().statusCode(200);
      as(reader).when().get(teamPath() + "/posts/" + postSlug).then().statusCode(200);
      as(reader).when().get(teamPath() + "/trips/" + tripSlug).then().statusCode(200);
    }
  }

  // ---- what stays closed ----

  @Test
  void participants_stayRefusedToOutsiders() {
    String[] paths = {
      teamPath() + "/rides/" + PUBLIC_RIDE + "/participants",
      teamPath() + "/trips/" + tripSlug + "/participants"
    };
    for (String path : paths) {
      as(null).when().get(path).then().statusCode(401);
      for (String reader : SIGNED_OUTSIDERS) {
        as(reader).when().get(path).then().statusCode(403);
      }
    }
  }

  @Test
  void comments_stayRefusedToOutsiders() {
    String[] paths = {
      teamPath() + "/rides/" + PUBLIC_RIDE + "/comments",
      teamPath() + "/routes/" + routeSlug + "/comments",
      teamPath() + "/posts/" + postSlug + "/comments",
      teamPath() + "/trips/" + tripSlug + "/comments",
      teamPath() + "/stages/" + stageSlug + "/comments"
    };
    for (String path : paths) {
      as(null).when().get(path).then().statusCode(401);
      for (String reader : SIGNED_OUTSIDERS) {
        as(reader).when().get(path).then().statusCode(403);
      }
    }
  }

  @Test
  void theTeamItself_andItsDashboard_stayClosedToOutsiders() {
    for (String reader : OUTSIDERS) {
      as(reader).when().get(teamPath()).then().statusCode(anyOf(equalTo(401), equalTo(403)));
      as(reader)
          .when()
          .get(teamPath() + "/dashboard")
          .then()
          .statusCode(anyOf(equalTo(401), equalTo(403)));
      as(reader)
          .when()
          .get(teamPath() + "/publications")
          .then()
          .statusCode(anyOf(equalTo(401), equalTo(403)));
    }
  }

  @Test
  void theContent_isInNoListing() {
    for (String reader : OUTSIDERS) {
      as(reader)
          .queryParam("size", 100)
          .when()
          .get("/api/routes")
          .then()
          .statusCode(200)
          .body("routes.slug", not(hasItem(routeSlug)));
      as(reader)
          .queryParam("size", 100)
          .when()
          .get(teamPath() + "/routes")
          .then()
          .statusCode(200)
          .body("routes.slug", not(hasItem(routeSlug)));
      as(reader)
          .queryParam("size", 100)
          .when()
          .get("/api/publications")
          .then()
          .statusCode(200)
          .body("publications.slug", not(hasItem(PUBLIC_RIDE)))
          .body("publications.slug", not(hasItem(postSlug)))
          .body("publications.slug", not(hasItem(tripSlug)))
          .body("publications.slug", not(hasItem(publicTripSlug)));
    }
  }

  @Test
  void theContent_isNotInTheSitemap() {
    given()
        .when()
        .get("/api/sitemap")
        .then()
        .statusCode(200)
        .body("entries.teamSlug", not(hasItem(team2Slug)));
  }

  /** The members still list it, as before: only the outsiders' listings leave it out. */
  @Test
  void theContent_staysListedForMembers() {
    as(USER3)
        .queryParam("size", 100)
        .when()
        .get(teamPath() + "/publications")
        .then()
        .statusCode(200)
        .body("publications.slug", hasItem(PUBLIC_RIDE));
  }
}
