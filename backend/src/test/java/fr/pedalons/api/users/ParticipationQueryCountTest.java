package fr.pedalons.api.users;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Budget for the "me" fields. {@code registered} / {@code registeredGroupId} are per-user, which is
 * exactly the kind of field that gets resolved row by row: one {@code findByUserAndRide} per line
 * turns a 20-row feed into 20 extra round-trips and nobody notices until production.
 *
 * <p>These tests seed a page where <em>every</em> row has a participation for the caller — a fixture
 * where nobody is registered would never exercise the lookup at all.
 */
@QuarkusTest
class ParticipationQueryCountTest extends AbstractQueryCountTest {

  @Inject GpsSyncTestData sync;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private void seedJoinedRides(int count) {
    seedJoinedRides(count, false);
  }

  /**
   * Same page, the joined groups' routes tracked at two of user1's services in automatic sync
   * (docs/LEDGER_*.md API-120), so every row's joined group carries {@code gpsSyncStatuses}.
   */
  private void seedJoinedRidesOnTrackedRoutes(int count) {
    List<Route> routes = seedJoinedRides(count, true);
    GpsServiceConnection hammerhead = sync.connect(user1, GpsServiceType.HAMMERHEAD, true);
    GpsServiceConnection garmin = sync.connect(user1, GpsServiceType.GARMIN, true);
    for (Route route : routes) {
      sync.recordManualUpload(domain.getId(), hammerhead, route, "hh-" + route.getId());
      sync.recordManualUpload(domain.getId(), garmin, route, "gc-" + route.getId());
    }
  }

  /**
   * @param joinedGroupHasRouteAndLeader give the group user1 joins its own route and a leader, so
   *     that rendering it on the row (docs/LEDGER_*.md API-4) has everything to resolve
   * @return the joined groups' routes, empty without them
   */
  private List<Route> seedJoinedRides(int count, boolean joinedGroupHasRouteAndLeader) {
    List<Route> routes = new ArrayList<>();
    Instant base = Instant.now().plus(7, ChronoUnit.DAYS);
    List<User> participants = List.of(user1, user2, user3, user4, user5);
    for (int i = 0; i < count; i++) {
      Ride ride =
          dataService.createRide(
              team1,
              user1,
              "Joined Ride " + i,
              "joined-ride-" + i,
              base.plusSeconds(i),
              Visibility.PUBLIC,
              Status.PUBLISHED);
      for (int g = 0; g < 2; g++) {
        RideGroup group = dataService.createRideGroup(user1, ride, "Group " + g, g);
        if (g == 0 && joinedGroupHasRouteAndLeader) {
          // Before any participation: merging the detached group would orphan them.
          Route route = dataService.createRoute(team1, user1, "Joined Route " + i);
          routes.add(route);
          group.setRoute(route);
          group.setLeader(user2);
          dataService.updateRideGroup(group);
        }
        // user1 only joins one of the two groups: joining both is forbidden by joinGroup.
        for (User participant :
            g == 0 ? participants : participants.subList(1, participants.size())) {
          dataService.createParticipation(group, participant);
        }
      }
    }
    return routes;
  }

  /**
   * docs/LEDGER_*.md API-178: two groups per ride on routes of their own, 40 km and 90 km, user1 in
   * the second — every row's display figures come from the groups' routes.
   */
  private void seedJoinedRidesOnSplitRoutes(int count) {
    Instant base = Instant.now().plus(7, ChronoUnit.DAYS);
    for (int i = 0; i < count; i++) {
      Ride ride =
          dataService.createRide(
              team1,
              user1,
              "Split Ride " + i,
              "split-ride-" + i,
              base.plusSeconds(i),
              Visibility.PUBLIC,
              Status.PUBLISHED);
      Route shortRoute = dataService.createRoute(team1, user1, "Short " + i);
      dataService.setRouteMetrics(shortRoute, 40000f, 300f);
      Route longRoute = dataService.createRoute(team1, user1, "Long " + i);
      dataService.setRouteMetrics(longRoute, 90000f, 1500f);
      RideGroup a = dataService.createRideGroup(user1, ride, "A", 0);
      dataService.setRideGroupRoute(a, shortRoute);
      RideGroup b = dataService.createRideGroup(user1, ride, "B", 1);
      // Route before the participation: merging the detached group afterwards would orphan it.
      dataService.setRideGroupRoute(b, longRoute);
      dataService.createParticipation(b, user1);
      dataService.createParticipation(a, user2);
    }
  }

  private void seedJoinedTrips(int count) {
    Instant base = Instant.now().plus(7, ChronoUnit.DAYS);
    for (int i = 0; i < count; i++) {
      Trip trip =
          dataService.createTrip(
              team1, user1, "Joined Trip " + i, base.plusSeconds(i), Visibility.PUBLIC);
      dataService.createTripStage(user1, trip, "Trip " + i + " Stage", 0);
      dataService.createTripParticipation(trip, user1);
    }
  }

  @Test
  void listAllPublicationsWithMeFields_costDoesNotScaleWithRowCount() {
    seedJoinedRides(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/publications (registered fields)", asUser1(), "/api/publications");
  }

  @Test
  void listParticipatingFilter_costDoesNotScaleWithRowCount() {
    seedJoinedRides(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/publications?participating=true",
        asUser1(),
        "/api/publications?participating=true");
  }

  @Test
  void listMyParticipations_costDoesNotScaleWithRowCount() {
    seedJoinedRides(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/users/me/participations", asUser1(), "/api/users/me/participations");
  }

  /**
   * The joined group rendered on every row (docs/LEDGER_*.md API-4): each joined group has its own
   * route and a leader, so the projection, the participant previews and the route thumbnails all
   * run — and must cost the same for 3 rows as for 30.
   */
  @Test
  void listMyParticipations_registeredGroups_costAPageNotARow() {
    seedJoinedRides(LARGE_PAGE, true);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/users/me/participations?size=" + SMALL_PAGE)
        .then()
        .statusCode(200)
        .body("publications.registeredGroup.name", everyItem(equalTo("Group 0")))
        .body("publications.registeredGroup.leader.id", everyItem(notNullValue()))
        .body("publications.registeredGroup.routeSlug", everyItem(notNullValue()));

    assertFlatQueryCount(
        "GET /api/users/me/participations (registered groups)",
        asUser1(),
        "/api/users/me/participations");
  }

  /**
   * docs/LEDGER_*.md API-120: the joined group of every row carries where its route stands at
   * user1's synced services — one lookup for the page, whatever its size.
   */
  @Test
  void listMyParticipations_gpsSyncStatuses_costAPageNotARow() {
    seedJoinedRidesOnTrackedRoutes(LARGE_PAGE);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/users/me/participations?size=" + SMALL_PAGE)
        .then()
        .statusCode(200)
        .body(
            "publications.collect { it.registeredGroup.gpsSyncStatuses.size() }",
            everyItem(equalTo(2)));

    assertFlatQueryCount(
        "GET /api/users/me/participations (gps sync statuses)",
        asUser1(),
        "/api/users/me/participations");
  }

  @Test
  void listAllPublications_gpsSyncStatuses_costDoesNotScaleWithRowCount() {
    seedJoinedRidesOnTrackedRoutes(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/publications (gps sync statuses)", asUser1(), "/api/publications");
  }

  /**
   * docs/LEDGER_*.md API-178: the display figures are read from the group rows the page already
   * loads — the joined group's route for user1, nothing for a member who joined none (the groups
   * ride different routes) — and cost no statement per row.
   */
  @Test
  void listPublications_displayFigures_costAPageNotARow() {
    seedJoinedRidesOnSplitRoutes(LARGE_PAGE);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/users/me/participations?size=" + SMALL_PAGE)
        .then()
        .statusCode(200)
        .body("publications.displayDistance", everyItem(equalTo(90000f)))
        .body("publications.displayElevationGain", everyItem(equalTo(1500f)));
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/publications?size=" + SMALL_PAGE)
        .then()
        .statusCode(200)
        .body("publications.displayDistance", everyItem(nullValue()));

    assertFlatQueryCount(
        "GET /api/users/me/participations (display figures)",
        asUser1(),
        "/api/users/me/participations");
    assertFlatQueryCount("GET /api/publications (display figures)", asUser1(), "/api/publications");
  }

  @Test
  void listMyParticipationsWithTrips_costDoesNotScaleWithRowCount() {
    seedJoinedTrips(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/users/me/participations (trips)", asUser1(), "/api/users/me/participations");
  }
}
