package fr.pedalons.api.rides;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The participants of a ride or a trip: a bounded preview in the detail, the whole list paginated
 * and searched by {@code …/participants} (docs/LEDGER_*.md API-12).
 */
@QuarkusTest
class ParticipantListResourceTest extends AbstractResourceTest {

  private static final int PREVIEW_SIZE = 8;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  /** Riders named "Rider 00" … in registration order, so the order is readable in assertions. */
  private List<User> seedUsers(String prefix, int count) {
    List<User> users = new ArrayList<>();
    for (int i = 0; i < count; i++) {
      users.add(
          dataService.createUser(
              prefix + i + "@example.com", "%s Rider %02d".formatted(prefix, i)));
    }
    return users;
  }

  private Ride createRide(String slug, Visibility visibility) {
    return dataService.createRide(
        team1,
        user1,
        "Ride " + slug,
        slug,
        Instant.now().plus(7, ChronoUnit.DAYS),
        visibility,
        Status.PUBLISHED);
  }

  @Test
  void rideDetail_embedsABoundedPreview_andTheRealCounts() {
    Ride ride = createRide("big-ride", Visibility.PUBLIC);
    RideGroup group = dataService.createRideGroupWithMaxParticipants(user1, ride, "Fast", 12);
    List<User> riders = seedUsers("big", 12);
    for (User rider : riders) {
      dataService.createParticipation(group, rider);
    }

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/big-ride")
        .then()
        .statusCode(200)
        .body("participantCount", equalTo(12))
        .body("full", equalTo(true))
        .body("topParticipants", hasSize(5))
        .body("topParticipants[0].displayName", equalTo("big Rider 00"))
        .body("groups[0].countParticipants", equalTo(12))
        .body("groups[0].full", equalTo(true))
        .body("groups[0].participants", hasSize(PREVIEW_SIZE))
        .body("groups[0].participants[0].displayName", equalTo("big Rider 00"))
        .body("groups[0].participants[7].displayName", equalTo("big Rider 07"));
  }

  @Test
  void rideParticipants_arePaginatedInRegistrationOrder() {
    Ride ride = createRide("paged-ride", Visibility.PUBLIC);
    RideGroup group = dataService.createRideGroup(user1, ride, "Only", 0);
    for (User rider : seedUsers("paged", 5)) {
      dataService.createParticipation(group, rider);
    }

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/paged-ride/participants?page=1&size=2")
        .then()
        .statusCode(200)
        .body("total", equalTo(5))
        .body("page", equalTo(1))
        .body("size", equalTo(2))
        .body("participants.displayName", contains("paged Rider 02", "paged Rider 03"));
  }

  @Test
  void rideParticipants_filterByGroup_andSearchByName() {
    Ride ride = createRide("split-ride", Visibility.PUBLIC);
    RideGroup fast = dataService.createRideGroup(user1, ride, "Fast", 0);
    RideGroup slow = dataService.createRideGroup(user1, ride, "Slow", 1);
    List<User> riders = seedUsers("split", 4);
    dataService.createParticipation(fast, riders.get(0));
    dataService.createParticipation(slow, riders.get(1));
    dataService.createParticipation(fast, riders.get(2));
    dataService.createParticipation(slow, riders.get(3));
    String base = "/api/teams/" + team1Slug + "/rides/split-ride/participants";

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(base + "?groupId=" + TsidUtils.toString(slow.getId()))
        .then()
        .statusCode(200)
        .body("total", equalTo(2))
        .body("participants.displayName", contains("split Rider 01", "split Rider 03"));

    // Case-insensitive, over every group of the ride.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(base + "?search=RIDER 02")
        .then()
        .statusCode(200)
        .body("total", equalTo(1))
        .body("participants.displayName", contains("split Rider 02"));

    // A LIKE wildcard is a literal character, not "anything".
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(base + "?search=%25")
        .then()
        .statusCode(200)
        .body("total", equalTo(0));
  }

  @Test
  void rideParticipants_groupOfAnotherRide_is404() {
    createRide("first-ride", Visibility.PUBLIC);
    Ride other = createRide("other-ride", Visibility.PUBLIC);
    RideGroup foreign = dataService.createRideGroup(user1, other, "Elsewhere", 0);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(
            "/api/teams/"
                + team1Slug
                + "/rides/first-ride/participants?groupId="
                + TsidUtils.toString(foreign.getId()))
        .then()
        .statusCode(404);
  }

  @Test
  void rideParticipants_areReadLikeTheRide() {
    Ride ride = createRide("team-ride", Visibility.TEAM);
    RideGroup group = dataService.createRideGroup(user1, ride, "Members", 0);
    dataService.createParticipation(group, user1);
    String path = "/api/teams/" + team1Slug + "/rides/team-ride/participants";

    // Anonymous is turned away before the ride is looked up (docs/LEDGER_*.md API-144); an
    // outsider who cannot read the ride still gets the 404 it would get on the ride itself.
    given().when().get(path).then().statusCode(401);
    given().auth().oauth2(getAccessToken(USER5)).when().get(path).then().statusCode(404);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(path)
        .then()
        .statusCode(200)
        .body("total", equalTo(1));
  }

  @Test
  void tripDetail_embedsABoundedPreview_andTheTripParticipants_arePaginated() {
    Trip trip =
        dataService.createTrip(
            team1, user1, "Long Trip", Instant.now().plus(7, ChronoUnit.DAYS), Visibility.PUBLIC);
    dataService.createTripStage(user1, trip, "Long Trip Stage", 0);
    for (User rider : seedUsers("trip", 10)) {
      dataService.createTripParticipation(trip, rider);
    }
    String base = "/api/teams/" + team1Slug + "/trips/" + trip.getSlug();

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(base)
        .then()
        .statusCode(200)
        .body("participantCount", equalTo(10))
        .body("participants", hasSize(PREVIEW_SIZE))
        .body("participants[0].displayName", equalTo("trip Rider 00"));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(base + "/participants?size=4&page=2")
        .then()
        .statusCode(200)
        .body("total", equalTo(10))
        .body("participants.displayName", contains("trip Rider 08", "trip Rider 09"));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(base + "/participants?search=rider 05")
        .then()
        .statusCode(200)
        .body("total", equalTo(1))
        .body("participants.displayName", contains("trip Rider 05"));
  }
}
