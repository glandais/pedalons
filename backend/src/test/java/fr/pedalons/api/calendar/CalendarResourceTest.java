package fr.pedalons.api.calendar;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.calendar.CalendarToken;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.repository.calendar.CalendarTokenRepository;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class CalendarResourceTest extends AbstractResourceTest {

  private Ride ride;
  private CalendarToken token;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    ride = dataService.createRide(team1, user1, "Test Ride", "test-ride", Instant.now());
    token = dataService.createCalendarToken(user1, "test-calendar-token-123");
  }

  // ==================== Get Events Tests ====================

  /** A malformed bound is the caller's error, not a 500 (API-91). */
  @Test
  void getEvents_withMalformedBound_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("from", "2026-10-11")
        .when()
        .get("/api/calendar/events")
        .then()
        .statusCode(400);
  }

  /** The same reading for the publication list, whose bounds go through the same parser. */
  @Test
  void listPublications_withMalformedBound_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("to", "not-a-date")
        .when()
        .get("/api/publications")
        .then()
        .statusCode(400);
  }

  @Test
  void getEvents_withAuth_shouldReturnEvents() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/calendar/events")
        .then()
        .statusCode(200)
        .body("events", notNullValue())
        .body("events.size()", greaterThanOrEqualTo(1))
        .body("events[0].title", equalTo("Test Ride"));
  }

  @Test
  void getEvents_withoutAuth_shouldReturn401() {
    given().when().get("/api/calendar/events").then().statusCode(401);
  }

  @Test
  void getEvents_forUserWithoutTeam_shouldReturnNoEvents() {
    // user4 belongs to no team: the personal calendar must not leak team1's public ride
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/calendar/events")
        .then()
        .statusCode(200)
        .body("events.size()", equalTo(0));
  }

  @Test
  void getEvents_forPlatformAdminWithoutTeam_shouldReturnNoEvents() {
    // God mode must not turn the personal calendar into a domain-wide one
    dataService.createPlatformAdminUser("godmode@example.com", "God Mode");

    given()
        .auth()
        .oauth2(getAccessToken("godmode"))
        .when()
        .get("/api/calendar/events")
        .then()
        .statusCode(200)
        .body("events.size()", equalTo(0));
  }

  @Test
  void getEvents_shouldFilterByDateRange() {
    Instant from = Instant.now().minusSeconds(3600);
    Instant to = Instant.now().plusSeconds(3600);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("from", from.toString())
        .queryParam("to", to.toString())
        .when()
        .get("/api/calendar/events")
        .then()
        .statusCode(200)
        .body("events", notNullValue());
  }

  /**
   * The window keeps what is under way in it, not only what starts in it (docs/LEDGER_*.md API-88):
   * a trip begun before {@code from} and still running is there, with its stages that end after
   * {@code from} — one begun the day before included — and without the ones already over or
   * removed.
   */
  @Test
  void getEvents_keepsATripStartedBeforeTheWindow_withItsStagesStillUnderWay() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    Trip trip =
        dataService.createTrip(team1, user1, "Tour en cours", now.minus(5, ChronoUnit.DAYS));
    TripStage over =
        dataService.createTripStage(user1, trip, "Étape finie", 1, now.minus(5, ChronoUnit.DAYS));
    TripStage overnight =
        dataService.createTripStage(
            user1, trip, "Étape de nuit", 2, now.minus(26, ChronoUnit.HOURS));
    TripStage today =
        dataService.createTripStage(
            user1, trip, "Étape du jour", 3, now.minus(1, ChronoUnit.HOURS));
    TripStage removed =
        dataService.createTripStage(
            user1, trip, "Étape retirée", 4, now.minus(2, ChronoUnit.HOURS));
    dataService.deleteTripStage(removed);
    dataService.setEndDateTime(
        over.getId(), now.minus(5, ChronoUnit.DAYS).plus(4, ChronoUnit.HOURS));
    dataService.setEndDateTime(overnight.getId(), now.minus(1, ChronoUnit.HOURS));
    dataService.setEndDateTime(today.getId(), now.plus(2, ChronoUnit.HOURS));
    dataService.setEndDateTime(trip.getId(), now.plus(2, ChronoUnit.HOURS));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("from", now.minus(1, ChronoUnit.DAYS).toString())
        .queryParam("to", now.plus(1, ChronoUnit.DAYS).toString())
        .when()
        .get("/api/calendar/events")
        .then()
        .statusCode(200)
        .body(
            "events.findAll { it.type == 'TRIP_STAGE' }.title",
            containsInAnyOrder("Étape de nuit", "Étape du jour"));
  }

  /** A trip over before the window stays out of it. */
  @Test
  void getEvents_leavesOutATripOverBeforeTheWindow() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    Trip trip = dataService.createTrip(team1, user1, "Tour fini", now.minus(5, ChronoUnit.DAYS));
    TripStage stage =
        dataService.createTripStage(user1, trip, "Étape", 1, now.minus(5, ChronoUnit.DAYS));
    dataService.setEndDateTime(stage.getId(), now.minus(2, ChronoUnit.DAYS));
    dataService.setEndDateTime(trip.getId(), now.minus(2, ChronoUnit.DAYS));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("from", now.minus(1, ChronoUnit.DAYS).toString())
        .queryParam("to", now.plus(1, ChronoUnit.DAYS).toString())
        .when()
        .get("/api/calendar/events")
        .then()
        .statusCode(200)
        .body("events.findAll { it.type == 'TRIP_STAGE' }", empty());
  }

  @Test
  void getEvents_shouldReturnEventsFromAllUserTeams() {
    // user1 is already admin of team1, let's verify they get events
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/calendar/events")
        .then()
        .statusCode(200)
        .body("events.size()", greaterThanOrEqualTo(1));
  }

  // ==================== Get Token Tests ====================

  @Test
  void getToken_withAuth_shouldReturnToken() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/calendar/token")
        .then()
        .statusCode(200)
        .body("token", notNullValue())
        .body("globalFeedUrl", containsString("/api/calendar/ics"))
        .body("teamFeedUrlTemplate", containsString("/calendar/ics"));
  }

  @Test
  void getToken_withoutAuth_shouldReturn401() {
    given().when().get("/api/calendar/token").then().statusCode(401);
  }

  @Test
  void getToken_shouldCreateTokenIfNotExists() {
    // user2 doesn't have a token yet
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/calendar/token")
        .then()
        .statusCode(200)
        .body("token", notNullValue())
        .body("token.length()", equalTo(64)); // 32 bytes = 64 hex chars
  }

  @Test
  void getToken_shouldReturnExistingToken() {
    // user1 already has a token created in setUp
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/calendar/token")
        .then()
        .statusCode(200)
        .body("token", equalTo(token.getToken()));
  }

  // ==================== Regenerate Token Tests ====================

  @Test
  void regenerateToken_withAuth_shouldReturnNewToken() {
    String oldToken = token.getToken();

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .contentType(ContentType.JSON)
        .post("/api/calendar/token/regenerate")
        .then()
        .statusCode(200)
        .body("token", notNullValue())
        .body("token", not(equalTo(oldToken)));
  }

  @Test
  void regenerateToken_withoutAuth_shouldReturn401() {
    given()
        .when()
        .contentType(ContentType.JSON)
        .post("/api/calendar/token/regenerate")
        .then()
        .statusCode(401);
  }

  @Test
  void regenerateToken_shouldInvalidateOldToken() {
    String oldToken = token.getToken();

    // First regenerate
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .contentType(ContentType.JSON)
        .post("/api/calendar/token/regenerate")
        .then()
        .statusCode(200);

    // Old token should no longer work for ICS feed
    given().queryParam("token", oldToken).when().get("/api/calendar/ics").then().statusCode(403);
  }

  // ==================== ICS Feed Tests ====================

  @Test
  void getGlobalIcsFeed_withValidToken_shouldReturnIcs() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/calendar/ics")
        .then()
        .statusCode(200)
        .contentType("text/calendar")
        .body(containsString("BEGIN:VCALENDAR"))
        .body(containsString("Test Ride"))
        .body(containsString("END:VCALENDAR"));
  }

  @Test
  void getGlobalIcsFeed_withInvalidToken_shouldReturn403() {
    given()
        .queryParam("token", "invalid-token")
        .when()
        .get("/api/calendar/ics")
        .then()
        .statusCode(403);
  }

  @Test
  void getGlobalIcsFeed_withoutToken_shouldReturn403() {
    given().when().get("/api/calendar/ics").then().statusCode(403);
  }

  @Test
  void getGlobalIcsFeed_shouldHaveCacheControlHeaders() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/calendar/ics")
        .then()
        .statusCode(200)
        .header("Cache-Control", containsString("no-cache"))
        .header("Content-Disposition", containsString("pedalons-calendar.ics"));
  }

  @Test
  void getGlobalIcsFeed_shouldReturnValidIcsFormat() {
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/calendar/ics")
        .then()
        .statusCode(200)
        .body(containsString("VERSION:2.0"))
        .body(containsString("PRODID:-//Pedalons//Calendar//EN"))
        .body(containsString("BEGIN:VEVENT"))
        .body(containsString("END:VEVENT"));
  }

  // ==================== Token inactivity (docs/LEDGER_*.md SEC-17) ====================

  @Inject EntityManager entityManager;
  @Inject CalendarTokenRepository calendarTokenRepository;

  /** Ages the token: {@code lastUsedDaysAgo} null leaves the column null (never fetched). */
  @Transactional
  void age(CalendarToken calendarToken, int createdDaysAgo, @Nullable Integer lastUsedDaysAgo) {
    Instant now = Instant.now();
    entityManager
        .createNativeQuery(
            "update calendar_tokens set created_at = ?1, last_used_at = ?2 where id = ?3")
        .setParameter(1, now.minus(createdDaysAgo, ChronoUnit.DAYS))
        .setParameter(
            2, lastUsedDaysAgo == null ? null : now.minus(lastUsedDaysAgo, ChronoUnit.DAYS))
        .setParameter(3, calendarToken.getId())
        .executeUpdate();
  }

  @Transactional
  @Nullable Instant lastUsedAt(CalendarToken calendarToken) {
    return calendarTokenRepository
        .findByIdOptional(calendarToken.getId())
        .map(CalendarToken::getLastUsedAt)
        .orElse(null);
  }

  private io.restassured.response.ValidatableResponse fetchFeed() {
    return given().queryParam("token", token.getToken()).when().get("/api/calendar/ics").then();
  }

  @Test
  void icsFeed_tokenSilentFor91Days_isRefused() {
    age(token, 200, 91);

    fetchFeed().statusCode(403);
    given()
        .queryParam("token", token.getToken())
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/ics")
        .then()
        .statusCode(403);
  }

  @Test
  void icsFeed_tokenNeverFetched_livesFromItsCreation() {
    age(token, 91, null);
    fetchFeed().statusCode(403);
  }

  @Test
  void icsFeed_oldTokenStillPolled_staysAlive() {
    // Created long ago, fetched 89 days ago: a subscription is never cut for its age.
    age(token, 400, 89);

    fetchFeed().statusCode(200);
    Instant lastUsed = lastUsedAt(token);
    assertNotNull(lastUsed);
    assertTrue(lastUsed.isAfter(Instant.now().minus(1, ChronoUnit.HOURS)), lastUsed.toString());
  }

  @Test
  void icsFeed_fetchIsRecordedAtMostOnceADay() {
    age(token, 10, 0);
    Instant before = lastUsedAt(token);

    fetchFeed().statusCode(200);

    assertEquals(before, lastUsedAt(token));
  }

  @Test
  void getToken_deadToken_isReplacedByALiveOne() {
    age(token, 200, 91);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/calendar/token")
        .then()
        .statusCode(200)
        .body("token", not(equalTo(token.getToken())));
  }

  @Test
  void purge_deletesOnlyDeadTokens() {
    CalendarToken alive = dataService.createCalendarToken(user2, "alive-calendar-token-456");
    age(token, 200, 91);
    age(alive, 200, 3);

    long deleted =
        io.quarkus.narayana.jta.QuarkusTransaction.requiringNew()
            .call(
                () ->
                    calendarTokenRepository.deleteInactiveSince(
                        Instant.now().minus(90, ChronoUnit.DAYS)));

    assertEquals(1, deleted);
    given()
        .queryParam("token", "alive-calendar-token-456")
        .when()
        .get("/api/calendar/ics")
        .then()
        .statusCode(200);
  }
}
