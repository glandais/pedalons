package fr.pedalons.api.gps;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.service.gps.sync.GpsRouteSyncPlanner;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import io.restassured.specification.RequestSpecification;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code gpsSyncStatuses} in the responses (docs/LEDGER_*.md API-120): on a route's detail, on the
 * groups and the ride of a ride's detail, on {@code stages[].route} of a trip's detail and on the
 * joined group of a list row — where the route stands at the <b>caller's</b> services in automatic
 * sync. Another member, and a visitor, are told nothing: the field is absent.
 *
 * <p>user3 (member of team1) joined group A of a ride, which rides the ride's route, and a trip
 * whose stage has a route of its own; group B has its own route, which nobody's sync holds. user3's
 * Hammerhead connection is in automatic sync, and the planner has run: every held route is PENDING.
 */
@QuarkusTest
class RouteGpsSyncStatusesResourceTest extends AbstractResourceTest {

  /** Checked as a key, not a null value: Jackson leaves the field out when there is none. */
  private static final String FIELD = "gpsSyncStatuses";

  @Inject DomainResolver domainResolver;
  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsSyncTestData sync;

  private Ride ride;
  private Route rideRoute;
  private Route groupBRoute;
  private Trip trip;
  private Route stageRoute;
  private GpsServiceConnection connection;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    ride = dataService.createRide(team1, user1, "Sortie", "sortie", now.plus(2, ChronoUnit.DAYS));
    rideRoute = sync.routeWithGpx(ride, user1, "Boucle des étangs");
    dataService.setRideRoute(ride, rideRoute);
    RideGroup groupA = dataService.createRideGroup(user1, ride, "Groupe A", 0);
    RideGroup groupB = dataService.createRideGroup(user1, ride, "Groupe B", 1);
    groupBRoute = sync.routeWithGpx(ride, user1, "Grande boucle");
    sync.setGroupRoute(groupB, groupBRoute);
    dataService.createParticipation(groupA, user3);

    trip = dataService.createTrip(team1, user1, "Voyage", now.plus(1, ChronoUnit.DAYS));
    TripStage stage =
        dataService.createTripStage(user1, trip, "Étape 1", 0, now.plus(1, ChronoUnit.DAYS));
    stageRoute = sync.routeWithGpx(team1, user1, "Col du Galibier");
    sync.setStageRoute(stage, stageRoute);
    dataService.createTripParticipation(trip, user3);

    connection = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    planner.plan(now);
  }

  private ValidatableResponse get(@Nullable String user, String path) {
    RequestSpecification request = given();
    if (user != null) {
      request = request.auth().oauth2(getAccessToken(user));
    }
    return request.when().get(path).then().statusCode(200);
  }

  private String routePath(Route route) {
    return "/api/teams/" + team1Slug + "/routes/" + route.getSlug();
  }

  private String ridePath() {
    return "/api/teams/" + team1Slug + "/rides/" + ride.getSlug();
  }

  private String tripPath() {
    return "/api/teams/" + team1Slug + "/trips/" + trip.getSlug();
  }

  // ------------------------------------------------------------------ route detail

  @Test
  void routeDetail_carriesTheCallersState() {
    get(USER3, routePath(rideRoute))
        .body("gpsSyncStatuses", hasSize(1))
        .body("gpsSyncStatuses[0].serviceType", equalTo("HAMMERHEAD"))
        .body("gpsSyncStatuses[0].state", equalTo("PENDING"))
        .body("gpsSyncStatuses[0].syncedAt", nullValue());
  }

  @Test
  void routeDetail_onceSent_isSentWithItsDate() {
    sync.markSynced(sync.row(connection.getId(), ride.getId()).orElseThrow().getId(), "ext-1");

    get(USER3, routePath(rideRoute))
        .body("gpsSyncStatuses", hasSize(1))
        .body("gpsSyncStatuses[0].state", equalTo("SENT"))
        .body("gpsSyncStatuses[0].syncedAt", notNullValue());
  }

  @Test
  void routeDetail_heldByNobody_hasNoField() {
    get(USER3, routePath(groupBRoute)).body("$", not(hasKey(FIELD)));
  }

  @Test
  void routeDetail_anotherMemberAndAVisitor_getNothing() {
    // user1 created the route and the ride: still nothing of user3's sync.
    get(USER1, routePath(rideRoute)).body("$", not(hasKey(FIELD)));
    get(USER2, routePath(rideRoute)).body("$", not(hasKey(FIELD)));
    get(null, routePath(rideRoute)).body("$", not(hasKey(FIELD)));
  }

  // ------------------------------------------------------------------ ride detail

  @Test
  void rideDetail_groupOnTheRidesRoute_andTheRide_carryTheState() {
    get(USER3, ridePath())
        .body("gpsSyncStatuses", hasSize(1))
        .body("gpsSyncStatuses[0].state", equalTo("PENDING"))
        .body("groups.find { it.name == 'Groupe A' }.gpsSyncStatuses", hasSize(1))
        .body(
            "groups.find { it.name == 'Groupe A' }.gpsSyncStatuses[0].serviceType",
            equalTo("HAMMERHEAD"))
        .body("groups.find { it.name == 'Groupe A' }.gpsSyncStatuses[0].state", equalTo("PENDING"))
        // Group B rides a route of its own, which user3's sync does not hold.
        .body("groups.find { it.name == 'Groupe B' }.gpsSyncStatuses", nullValue())
        .body("registeredGroup.gpsSyncStatuses", hasSize(1));
  }

  @Test
  void rideDetail_anotherMemberAndAVisitor_getNothing() {
    for (String user : new String[] {USER2, null}) {
      get(user, ridePath())
          .body("gpsSyncStatuses", nullValue())
          .body("groups.find { it.name == 'Groupe A' }.gpsSyncStatuses", nullValue())
          .body("groups.find { it.name == 'Groupe B' }.gpsSyncStatuses", nullValue());
    }
  }

  // ------------------------------------------------------------------ trip detail

  @Test
  void tripDetail_stageRoute_carriesTheState() {
    get(USER3, tripPath())
        .body("stages[0].route.gpsSyncStatuses", hasSize(1))
        .body("stages[0].route.gpsSyncStatuses[0].serviceType", equalTo("HAMMERHEAD"))
        .body("stages[0].route.gpsSyncStatuses[0].state", equalTo("PENDING"));
  }

  @Test
  void tripDetail_anotherMemberAndAVisitor_getNothing() {
    get(USER2, tripPath()).body("stages[0].route.gpsSyncStatuses", nullValue());
    get(null, tripPath()).body("stages[0].route.gpsSyncStatuses", nullValue());
  }

  // ------------------------------------------------------------------ list row

  @Test
  void participationsList_joinedGroup_andRide_carryTheState() {
    get(USER3, "/api/users/me/participations")
        .body("publications.find { it.slug == 'sortie' }.gpsSyncStatuses", hasSize(1))
        .body(
            "publications.find { it.slug == 'sortie' }.registeredGroup.gpsSyncStatuses[0].state",
            equalTo("PENDING"));
  }

  @Test
  void publicationsList_anotherMember_getsNothing() {
    get(USER2, "/api/teams/" + team1Slug + "/publications?type=RIDE")
        .body("publications.find { it.slug == 'sortie' }.gpsSyncStatuses", nullValue());
  }
}
