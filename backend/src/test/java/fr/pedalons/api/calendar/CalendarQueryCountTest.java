package fr.pedalons.api.calendar;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Query budget for the agenda.
 *
 * <p>The calendar is the endpoint with the worst exposure to a per-row lookup in the whole API: its
 * default window is 210 days wide and it has no pagination, so anything resolved per event is
 * resolved as many times as the window has events. The three things this change added — the
 * registration, the joined group's name, the thumbnail — are all naturally per-row, and all three
 * are exactly the kind of field that gets written as a lookup inside the mapping loop.
 *
 * <p>{@link AbstractQueryCountTest#assertFlatQueryCount} cannot be reused as is: it varies {@code
 * size}, and the calendar has no page size. The window is varied instead — same fixture, same
 * endpoint, three days against thirty — which is the same question asked the way this endpoint
 * scales.
 *
 * <p>Only the statement count is asserted flat. Entity hydration <em>must</em> grow here: an event
 * <em>is</em> an entity, so thirty events legitimately hydrate ten times what three do. What must
 * not grow is the number of round trips.
 */
@QuarkusTest
class CalendarQueryCountTest extends AbstractQueryCountTest {

  private Instant base;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    base = Instant.now();
  }

  /** One ride per day, each with a route, a start place, a thumbnail and a joined group. */
  private void seedRides(int count) {
    Place start = dataService.createPlace(team1, user1, "Depart");
    for (int i = 0; i < count; i++) {
      Ride ride =
          dataService.createRide(
              team1,
              user1,
              "Ride " + i,
              "ride-" + i,
              base.plus(i, ChronoUnit.DAYS).plusSeconds(3600));
      Route route = dataService.createRoute(team1, user1, "Route " + i);
      dataService.setRouteMetrics(route, 40000f, 600f);
      dataService.setRideRoute(ride, route);
      dataService.setRidePlaces(ride, start, null);
      dataService.attachAsset(ride, user1, AssetType.RIDE_THUMBNAIL_LIGHT, "ride-" + i + ".png");
      RideGroup group = dataService.createRideGroup(user1, ride, "Groupe " + i, 0);
      dataService.createParticipation(group, user1);
    }
  }

  /** One single-stage trip per day, each joined by the caller. */
  private void seedTrips(int count) {
    for (int i = 0; i < count; i++) {
      Trip trip =
          dataService.createTrip(
              team1, user1, "Trip " + i, base.plus(i, ChronoUnit.DAYS).plusSeconds(3600));
      TripStage stage =
          dataService.createTripStage(
              user1, trip, "Stage " + i, base.plus(i, ChronoUnit.DAYS).plusSeconds(3600));
      Route route = dataService.createRoute(team1, user1, "Trip route " + i);
      dataService.setRouteMetrics(route, 30000f, 900f);
      dataService.setTripStageRoute(stage, route);
      dataService.attachAsset(stage, user1, AssetType.TRIP_THUMBNAIL_LIGHT, "stage-" + i + ".png");
      dataService.createTripParticipation(trip, user1);
    }
  }

  private QueryStats.Counters measureWindow(
      String label, String user, String path, int days, int expected) {
    String url =
        path
            + "?from="
            + base.minusSeconds(60)
            + "&to="
            + base.plus(days, ChronoUnit.DAYS).plusSeconds(60);
    return queryStats.measureAll(
        label,
        () ->
            given()
                .auth()
                .oauth2(getAccessToken(user))
                .when()
                .get(url)
                .then()
                .statusCode(200)
                .body("events.size()", equalTo(expected)));
  }

  private void assertFlatOverWindow(String name, String path) {
    assertFlatOverWindow(name, USER1, path);
  }

  private void assertFlatOverWindow(String name, String user, String path) {
    QueryStats.Counters small =
        measureWindow(name + " [" + SMALL_PAGE + " days]", user, path, SMALL_PAGE, SMALL_PAGE);
    QueryStats.Counters large =
        measureWindow(name + " [" + LARGE_PAGE + " days]", user, path, LARGE_PAGE, LARGE_PAGE);

    long growth = large.statements() - small.statements();
    assertTrue(
        growth <= MAX_STATEMENT_GROWTH,
        () ->
            "N+1 on "
                + name
                + ": a "
                + SMALL_PAGE
                + "-event window cost "
                + small.statements()
                + " SQL statements, a "
                + LARGE_PAGE
                + "-event one cost "
                + large.statements()
                + " (+"
                + growth
                + ", budget +"
                + MAX_STATEMENT_GROWTH
                + "). The calendar has no pagination: whatever is resolved per event here is"
                + " resolved a few hundred times on a real window. Load it in bulk before the"
                + " mapping loop.\n"
                + queryStats.queryBreakdown(15));
  }

  @Test
  void getEvents_rides_costDoesNotScaleWithTheWindow() {
    seedRides(LARGE_PAGE);
    assertFlatOverWindow("GET /api/calendar/events (rides)", "/api/calendar/events");
  }

  @Test
  void getEvents_tripStages_costDoesNotScaleWithTheWindow() {
    seedTrips(LARGE_PAGE);
    assertFlatOverWindow("GET /api/calendar/events (trip stages)", "/api/calendar/events");
  }

  @Test
  void getTeamEvents_costDoesNotScaleWithTheWindow() {
    seedRides(LARGE_PAGE);
    assertFlatOverWindow(
        "GET /api/teams/{slug}/calendar/events", "/api/teams/" + team1Slug + "/calendar/events");
  }

  /** Ledger API-137: a platform admin's personal agenda takes the member's query shape. */
  @Test
  void getEvents_asPlatformAdminMember_costDoesNotScaleWithTheWindow() {
    seedRides(LARGE_PAGE);
    User root = dataService.createPlatformAdminUser("root@example.com", "Root");
    dataService.addUserToTeam(root, team1, TeamRole.MEMBER);
    assertFlatOverWindow(
        "GET /api/calendar/events (platform admin)", "root", "/api/calendar/events");
  }

  /** The in-app team calendar keeps the platform admin's full view, at the same cost. */
  @Test
  void getTeamEvents_asPlatformAdmin_costDoesNotScaleWithTheWindow() {
    seedRides(LARGE_PAGE);
    dataService.createPlatformAdminUser("root@example.com", "Root");
    assertFlatOverWindow(
        "GET /api/teams/{slug}/calendar/events (platform admin)",
        "root",
        "/api/teams/" + team1Slug + "/calendar/events");
  }
}
