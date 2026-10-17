package fr.pedalons.api.calendar;

import static io.restassured.RestAssured.given;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The agenda payload: what a calendar cell and an agenda card need in order to render without
 * fetching the ride behind every event.
 *
 * <p>Each field is asserted through HTTP rather than on the service, because the point of the change
 * is the shape of the JSON the mobile app reads. The "me" fields are asserted from two different
 * callers on the same fixture — a field that is right for the user who registered and also right for
 * the one who did not is a field that is actually resolved per caller, not one that happens to
 * echo the fixture.
 */
@QuarkusTest
class CalendarEventFieldsTest extends AbstractResourceTest {

  private static final String EVENTS = "/api/calendar/events";

  private Instant soon;
  private Ride ride;
  private Route route;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    soon = Instant.now().plus(3, ChronoUnit.DAYS);
    ride = dataService.createRide(team1, user1, "Sortie du dimanche", "sortie-dimanche", soon);
    route = dataService.createRoute(team1, user1, "Boucle des collines");
    dataService.setRouteMetrics(route, 42000f, 850f);
    dataService.setRideRoute(ride, route);
  }

  private String rideEvent(String field) {
    return "events.find { it.entitySlug == 'sortie-dimanche' }." + field;
  }

  /**
   * The whole ride event as a map. Needed where an assertion is about a key being <em>absent</em>
   * (Jackson is NON_NULL, so an absent value is an absent key) or where two of its fields are
   * compared to each other — neither of which a single GPath can express.
   */
  private Map<String, Object> rideEventFields(JsonPath response) {
    return response.getMap("events.find { it.entitySlug == 'sortie-dimanche' }");
  }

  private JsonPath getEvents() {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .extract()
        .jsonPath();
  }

  // ==================== End (API-85) ====================

  @Test
  void getEvents_rideEnd_isItsStoredEnd_orItsDeparturePlusThreeHours() {
    Instant start = Instant.now().plus(2, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    dataService.createRide(team1, user1, "Sans fin", "sans-fin", start);
    Instant end = soon.truncatedTo(ChronoUnit.SECONDS).plus(4, ChronoUnit.HOURS);
    dataService.setEndDateTime(ride.getId(), end);

    JsonPath events = getEvents();

    org.junit.jupiter.api.Assertions.assertEquals(
        end.toString(), events.getString(rideEvent("end")));
    org.junit.jupiter.api.Assertions.assertEquals(
        start.plus(3, ChronoUnit.HOURS).toString(),
        events.getString("events.find { it.entitySlug == 'sans-fin' }.end"));
  }

  @Test
  void rideIcs_carriesTheEnd_asDtend() {
    Instant end = Instant.parse("2031-05-04T12:30:00Z");
    dataService.setEndDateTime(ride.getId(), end);

    String ics =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get("/api/teams/" + team1Slug + "/rides/sortie-dimanche/ics")
            .then()
            .statusCode(200)
            .extract()
            .asString();

    org.junit.jupiter.api.Assertions.assertTrue(ics.contains("DTEND:20310504T123000Z"), ics);
  }

  /** One ride's calendar announces the ride's own zone (docs/LEDGER_*.md API-60). */
  @Test
  void rideIcs_announcesTheRidesZone() {
    dataService.setTimezone(ride.getId(), "Asia/Tokyo");

    String ics =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get("/api/teams/" + team1Slug + "/rides/sortie-dimanche/ics")
            .then()
            .statusCode(200)
            .extract()
            .asString();

    org.junit.jupiter.api.Assertions.assertTrue(ics.contains("X-WR-TIMEZONE:Asia/Tokyo\r\n"), ics);
  }

  // ==================== Render payload ====================

  @Test
  void getEvents_shouldExposeStartPlaceDistanceElevationAndStatus() {
    Place start = dataService.createPlace(team1, user1, "Place de la Mairie");
    dataService.setRidePlaces(ride, start, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(rideEvent("startPlaceName"), equalTo("Place de la Mairie"))
        .body(rideEvent("distance"), equalTo(42000f))
        .body(rideEvent("elevationGain"), equalTo(850f))
        .body(rideEvent("status"), equalTo(Status.PUBLISHED.name()));
  }

  @Test
  void getEvents_withoutRouteOrPlace_shouldOmitTheOptionalFields() {
    // Jackson is configured NON_NULL: an absent value is an absent key, not a null one.
    dataService.createRide(team1, user1, "Sortie nue", "sortie-nue", soon);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body("events.find { it.entitySlug == 'sortie-nue' }", not(hasKey("distance")))
        .body("events.find { it.entitySlug == 'sortie-nue' }", not(hasKey("elevationGain")))
        .body("events.find { it.entitySlug == 'sortie-nue' }", not(hasKey("startPlaceName")))
        .body("events.find { it.entitySlug == 'sortie-nue' }", not(hasKey("thumbnailUrl")))
        .body("events.find { it.entitySlug == 'sortie-nue' }.registered", equalTo(false));
  }

  @Test
  void getEvents_shouldExposeTheRidesOwnThumbnail() {
    dataService.attachAsset(ride, user1, AssetType.RIDE_THUMBNAIL_LIGHT, "ride-light.png");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(rideEvent("thumbnailUrl"), startsWith("/api/download/public/images/" + team1Slug))
        .body(rideEvent("thumbnailUrl"), containsString("/{size}?v="));
  }

  @Test
  void getEvents_withoutOwnThumbnail_shouldFallBackToTheRouteThumbnail() {
    dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "route-light.png");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(rideEvent("thumbnailUrl"), containsString("/images/" + team1Slug + "/"));
  }

  @Test
  void getEvents_shouldPreferTheRidesThumbnailOverTheRoutes() {
    var routeThumb =
        dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "route-light.png");
    dataService.attachAsset(ride, user1, AssetType.RIDE_THUMBNAIL_LIGHT, "ride-light.png");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(
            rideEvent("thumbnailUrl"), not(containsString(TsidUtils.toString(routeThumb.getId()))));
  }

  @Test
  void getEvents_shouldExposeBothThemedThumbnailVariants() {
    dataService.attachAsset(ride, user1, AssetType.RIDE_THUMBNAIL_LIGHT, "ride-light.png");
    var dark = dataService.attachAsset(ride, user1, AssetType.RIDE_THUMBNAIL_DARK, "ride-dark.png");

    JsonPath response = getEvents();
    String lightUrl = response.getString(rideEvent("thumbnailLightUrl"));
    String darkUrl = response.getString(rideEvent("thumbnailDarkUrl"));

    assertThat(lightUrl, containsString("/{size}?v="));
    assertThat(darkUrl, containsString(TsidUtils.toString(dark.getId())));
    // Two genuinely different assets — the whole reason for exposing both.
    assertThat(darkUrl, not(equalTo(lightUrl)));
    // The collapsed field keeps its old meaning: light preferred.
    assertThat(response.getString(rideEvent("thumbnailUrl")), equalTo(lightUrl));
  }

  @Test
  void getEvents_withOnlyADarkThumbnail_shouldOmitTheLightVariantAndCollapseToDark() {
    dataService.attachAsset(ride, user1, AssetType.RIDE_THUMBNAIL_DARK, "ride-dark.png");

    JsonPath response = getEvents();
    String darkUrl = response.getString(rideEvent("thumbnailDarkUrl"));

    assertThat(rideEventFields(response), not(hasKey("thumbnailLightUrl")));
    assertThat(darkUrl, containsString("/{size}?v="));
    assertThat(response.getString(rideEvent("thumbnailUrl")), equalTo(darkUrl));
  }

  /**
   * The fallback is per entity, not per variant: a ride carrying only a light picture of its own
   * must not borrow the route's dark one, or the same event would show two different images
   * depending on the visitor's theme.
   */
  @Test
  void getEvents_withOwnLightThumbnail_shouldNotBorrowTheRoutesDarkVariant() {
    dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_DARK, "route-dark.png");
    dataService.attachAsset(ride, user1, AssetType.RIDE_THUMBNAIL_LIGHT, "ride-light.png");

    JsonPath response = getEvents();

    assertThat(response.getString(rideEvent("thumbnailLightUrl")), containsString("/{size}?v="));
    assertThat(rideEventFields(response), not(hasKey("thumbnailDarkUrl")));
  }

  // ==================== "Me" fields ====================

  @Test
  void getEvents_whenRegistered_shouldReportTheGroupJoined() {
    dataService.createRideGroup(user1, ride, "Groupe 1", 0);
    RideGroup fast = dataService.createRideGroup(user1, ride, "Groupe rapide", 1);
    dataService.createParticipation(fast, user1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(rideEvent("registered"), equalTo(true))
        .body(rideEvent("groupName"), equalTo("Groupe rapide"));
  }

  @Test
  void getEvents_forSomeoneElsesRegistration_shouldNotReportItAsMine() {
    RideGroup fast = dataService.createRideGroup(user1, ride, "Groupe rapide", 0);
    dataService.createParticipation(fast, user2);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(rideEvent("registered"), equalTo(false))
        .body("events.find { it.entitySlug == 'sortie-dimanche' }", not(hasKey("groupName")));

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(rideEvent("registered"), equalTo(true))
        .body(rideEvent("groupName"), equalTo("Groupe rapide"));
  }

  @Test
  void getEvents_forATripStage_shouldReportTheRegistrationOfTheParentTrip() {
    Trip trip = dataService.createTrip(team1, user1, "Semaine dans les Alpes", soon);
    TripStage stage = dataService.createTripStage(user1, trip, "Etape 1", soon);
    Route stageRoute = dataService.createRoute(team1, user1, "Col du Galibier");
    dataService.setRouteMetrics(stageRoute, 31000f, 1200f);
    dataService.setTripStageRoute(stage, stageRoute);
    dataService.setTripStagePlaces(stage, dataService.createPlace(team1, user1, "Valloire"), null);
    dataService.createTripParticipation(trip, user1);

    String stageEvent = "events.find { it.type == 'TRIP_STAGE' }.";

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(stageEvent + "registered", equalTo(true))
        .body(stageEvent + "startPlaceName", equalTo("Valloire"))
        .body(stageEvent + "distance", equalTo(31000f))
        .body(stageEvent + "elevationGain", equalTo(1200f))
        // Trips have no groups, so a registered stage still names none.
        .body("events.find { it.type == 'TRIP_STAGE' }", not(hasKey("groupName")));

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body(stageEvent + "registered", equalTo(false));
  }

  // ==================== Caching ====================

  @Test
  void getEvents_shouldForbidSharedCaching() {
    // "registered"/"groupName" make the body caller-specific; a shared cache must not keep it.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .header("Cache-Control", equalTo("private, no-store"));
  }

  @Test
  void getTeamEvents_shouldForbidSharedCaching() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/calendar/events")
        .then()
        .statusCode(200)
        .header("Cache-Control", equalTo("private, no-store"));
  }

  // ==================== Access ====================

  @Test
  void getEvents_anonymously_shouldReturn401() {
    given().when().get(EVENTS).then().statusCode(401);
  }

  @Test
  void getTeamEvents_forAPrivateTeam_asNonMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team2Slug + "/calendar/events")
        .then()
        .statusCode(403);
  }

  @Test
  void getEvents_forAUserOfAnotherDomain_shouldNotSeeThisDomainsEvents() {
    // Same email on two domains is legal; the two accounts must share nothing.
    Domain other = dataService.createDomain("other.localhost", "Other", "http://other.localhost");
    User otherUser = dataService.createUser(other, EMAIL1, "Other User 1");
    Team otherTeam =
        dataService.createTeam(other, otherUser, "Foreign Team", "foreign-team", Visibility.PUBLIC);
    Ride foreignRide =
        dataService.createRide(otherTeam, otherUser, "Foreign Ride", "foreign-ride", soon);
    dataService.attachAsset(
        foreignRide, otherUser, AssetType.RIDE_THUMBNAIL_LIGHT, "foreign-light.png");

    // The default-domain caller sees their own ride and nothing of the other domain — including no
    // thumbnail resolved from it.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(EVENTS)
        .then()
        .statusCode(200)
        .body("events.entitySlug", hasItem("sortie-dimanche"))
        .body("events.entitySlug", not(hasItem("foreign-ride")));
  }
}
