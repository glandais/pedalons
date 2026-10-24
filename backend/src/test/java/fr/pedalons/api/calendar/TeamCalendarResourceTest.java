package fr.pedalons.api.calendar;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.calendar.CalendarToken;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import io.quarkus.test.junit.QuarkusTest;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamCalendarResourceTest extends AbstractResourceTest {

  private Ride ride;
  private Trip trip;
  private TripStage stage;
  private CalendarToken token;
  private Instant now;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    now = Instant.now();
    ride = dataService.createRide(team1, user1, "Team Ride", "team-ride", now);
    trip = dataService.createTrip(team1, user1, "Team Trip", now);
    stage = dataService.createTripStage(user1, trip, "Stage 1", now);
    token = dataService.createCalendarToken(user1, "team-calendar-token-123");
  }

  // ==================== Get Team Events Tests ====================

  @Test
  void getTeamEvents_withoutAuth_shouldReturn403() {
    // Public team events should be accessible without auth
    given().when().get("/api/teams/" + team1Slug + "/calendar/events").then().statusCode(403);
  }

  @Test
  void getTeamEvents_withAuth_shouldReturnEvents() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .body("events", notNullValue())
        .body("events.size()", greaterThanOrEqualTo(1));
  }

  @Test
  void getTeamEvents_shouldReturnRides() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .body("events.find { it.type == 'RIDE' }.title", equalTo("Team Ride"));
  }

  @Test
  void getTeamEvents_shouldReturnTripStages() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .body("events.find { it.type == 'TRIP_STAGE' }.title", equalTo("Stage 1"));
  }

  @Test
  void getTeamEvents_shouldFilterByDateRange() {
    Instant from = now.minusSeconds(3600);
    Instant to = now.plusSeconds(3600);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("from", from.toString())
        .queryParam("to", to.toString())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .body("events", notNullValue());
  }

  @Test
  void getTeamEvents_forNonexistentTeam_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/nonexistent-team/calendar/events")
        .then()
        .statusCode(404);
  }

  @Test
  void getTeamEvents_shouldIncludeEventMetadata() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .body("events[0].id", notNullValue())
        .body("events[0].title", notNullValue())
        .body("events[0].start", notNullValue())
        .body("events[0].type", notNullValue())
        .body("events[0].teamSlug", equalTo(team1Slug))
        .body("events[0].teamName", equalTo("Team 1"));
  }

  // ==================== Get Team ICS Feed Tests ====================

  @Test
  void getTeamIcsFeed_withValidToken_shouldReturnIcs() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(200)
        .contentType("text/calendar")
        .body(containsString("BEGIN:VCALENDAR"))
        .body(containsString("Team Ride"))
        .body(containsString("END:VCALENDAR"));
  }

  @Test
  void getTeamIcsFeed_shouldIncludeTeamNameInCalendar() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(200)
        .body(containsString("X-WR-CALNAME:Pedalons - Team 1"));
  }

  @Test
  void getTeamIcsFeed_withInvalidToken_shouldReturn403() {
    given()
        .queryParam("token", "invalid-token")
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(403);
  }

  @Test
  void getTeamIcsFeed_withoutToken_shouldReturn403() {
    given().when().get("/api/teams/" + team1Slug + "/calendar/ics").then().statusCode(403);
  }

  @Test
  void getTeamIcsFeed_forNonexistentTeam_shouldReturn404() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/teams/nonexistent-team/calendar/ics")
        .then()
        .statusCode(404);
  }

  @Test
  void getTeamIcsFeed_shouldHaveCacheControlHeaders() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(200)
        .header("Cache-Control", containsString("no-cache"))
        .header("Content-Disposition", containsString(team1Slug + "-calendar.ics"));
  }

  @Test
  void getTeamIcsFeed_shouldReturnValidIcsFormat() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(200)
        .body(containsString("VERSION:2.0"))
        .body(containsString("PRODID:-//Pedalons//Calendar//EN"))
        .body(containsString("BEGIN:VEVENT"))
        .body(containsString("END:VEVENT"));
  }

  @Test
  void getTeamIcsFeed_shouldIncludeRideUrls() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(200)
        .body(containsString("URL:"))
        .body(containsString("/teams/" + team1Slug + "/rides/team-ride"));
  }

  @Test
  void getTeamIcsFeed_shouldIncludeTripStageUrls() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(200)
        .body(containsString("/teams/" + team1Slug + "/trips/"));
  }

  // ==================== Private Team Access Tests ====================

  @Test
  void getTeamEvents_forPrivateTeam_asMember_shouldSucceed() {
    // Create a ride in the private team
    dataService.createRide(team2, user1, "Private Ride", "private-ride", now);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team2Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .body("events", notNullValue());
  }

  @Test
  void getTeamEvents_forPrivateTeam_asNonMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team2Slug + "/calendar/events")
        .then()
        .statusCode(403);
  }

  @Test
  void getTeamEvents_forPrivateTeam_asPlatformAdminNonMember_shouldReturnEvents() {
    dataService.createRide(team2, user1, "Private Ride", "private-ride", now);
    dataService.createPlatformAdminUser("godmode@example.com", "God Mode");

    given()
        .auth()
        .oauth2(getAccessToken("godmode"))
        .when()
        .get("/api/teams/" + team2Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .body("events.title", hasItem("Private Ride"));
  }

  /**
   * Ledger API-137: an exported feed lands in someone's agenda, so it follows the real role; the
   * in-app team calendar keeps the drafts for the platform admin who opens it.
   */
  @Test
  void teamIcs_asPlatformAdmin_shouldNotExportDrafts() {
    User godmode = dataService.createPlatformAdminUser("godmode@example.com", "God Mode");
    // The team feed is members-only (403 otherwise): as a plain member, the platform admin must
    // not get the drafts their bypass would show.
    dataService.addUserToTeam(godmode, team1, TeamRole.MEMBER);
    CalendarToken godToken = dataService.createCalendarToken(godmode, "godmode-calendar-token");
    dataService.createRide(team1, user1, "Draft Ride", "draft-ride", now, Status.DRAFT);

    given()
        .queryParam("token", godToken.getToken())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(200)
        .body(containsString("Team Ride"))
        .body(not(containsString("Draft Ride")));

    given()
        .auth()
        .oauth2(getAccessToken("godmode"))
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .body("events.title", hasItem("Draft Ride"));
  }
}
