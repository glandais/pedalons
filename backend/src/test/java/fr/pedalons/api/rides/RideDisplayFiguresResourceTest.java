package fr.pedalons.api.rides;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.nullValue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import io.restassured.specification.RequestSpecification;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code displayDistance} / {@code displayElevationGain}: the one distance a ride card shows its
 * reader, computed by the API (docs/LEDGER_*.md API-178, rule R3). Their group's route when they are
 * registered; else the route the whole ride shares; else nothing.
 *
 * <p>Four rides of team1, one per case:
 *
 * <ul>
 *   <li>{@code split} — no route of its own, group A on 50 km, group B on 90 km; user3 rides in B.
 *   <li>{@code shared-ride} — its own route (70 km), two groups without one; user3 rides in A.
 *   <li>{@code shared-groups} — no route of its own, both groups on the same 40 km route; nobody
 *       registered.
 *   <li>{@code bare} — no route anywhere; user3 rides in its only group.
 * </ul>
 *
 * <p>user3 is the registered reader, user2 a member who joined nothing, user4 someone outside the
 * team, and the anonymous caller — the last three get the not-registered answer.
 */
@QuarkusTest
class RideDisplayFiguresResourceTest extends AbstractResourceTest {

  private static final String SPLIT = "split";
  private static final String SHARED_RIDE = "shared-ride";
  private static final String SHARED_GROUPS = "shared-groups";
  private static final String BARE = "bare";

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    Instant soon = Instant.now().plus(2, ChronoUnit.DAYS);

    Route fifty = route("Cinquante", 50000f, 500f);
    Route ninety = route("Quatre-vingt-dix", 90000f, 1500f);
    Ride split = dataService.createRide(team1, user1, "Split", SPLIT, soon);
    RideGroup a = dataService.createRideGroup(user1, split, "A", 0);
    // Routes before any participation: merging the detached group afterwards would orphan them.
    dataService.setRideGroupRoute(a, fifty);
    RideGroup b = dataService.createRideGroup(user1, split, "B", 1);
    dataService.setRideGroupRoute(b, ninety);
    dataService.createParticipation(b, user3);

    Route seventy = route("Soixante-dix", 70000f, 800f);
    Ride sharedRide =
        dataService.createRide(
            team1, user1, "Shared ride", SHARED_RIDE, soon.plus(1, ChronoUnit.DAYS));
    dataService.setRideRoute(sharedRide, seventy);
    RideGroup sharedA = dataService.createRideGroup(user1, sharedRide, "A", 0);
    dataService.createRideGroup(user1, sharedRide, "B", 1);
    dataService.createParticipation(sharedA, user3);

    Route forty = route("Quarante", 40000f, 300f);
    Ride sharedGroups =
        dataService.createRide(
            team1, user1, "Shared groups", SHARED_GROUPS, soon.plus(2, ChronoUnit.DAYS));
    RideGroup first = dataService.createRideGroup(user1, sharedGroups, "A", 0);
    dataService.setRideGroupRoute(first, forty);
    RideGroup second = dataService.createRideGroup(user1, sharedGroups, "B", 1);
    dataService.setRideGroupRoute(second, forty);

    Ride bare = dataService.createRide(team1, user1, "Bare", BARE, soon.plus(3, ChronoUnit.DAYS));
    RideGroup only = dataService.createRideGroup(user1, bare, "Seul", 0);
    dataService.createParticipation(only, user3);
  }

  private Route route(String name, float distance, float elevationGain) {
    Route route = dataService.createRoute(team1, user1, name);
    dataService.setRouteMetrics(route, distance, elevationGain);
    return route;
  }

  private RequestSpecification as(@Nullable String user) {
    return user == null ? given() : given().auth().oauth2(getAccessToken(user));
  }

  private ValidatableResponse get(@Nullable String user, String path) {
    return as(user).when().get(path).then().statusCode(200);
  }

  private static String row(String list, String key, String slug) {
    return list + ".find { it." + key + " == '" + slug + "' }";
  }

  /** Asserts the figures of the row of {@code slug} in {@code list}; null distance means none. */
  private static void assertFigures(
      ValidatableResponse response,
      String list,
      String key,
      String slug,
      @Nullable Float distance,
      @Nullable Float elevationGain) {
    String row = row(list, key, slug);
    response
        .body(row + ".displayDistance", distance == null ? nullValue() : equalTo(distance))
        .body(
            row + ".displayElevationGain",
            elevationGain == null ? nullValue() : equalTo(elevationGain));
  }

  /** The four cases for the registered reader (user3) — what they see in {@code list}. */
  private static void assertRegisteredReader(
      ValidatableResponse response, String list, String key) {
    assertFigures(response, list, key, SPLIT, 90000f, 1500f);
    assertFigures(response, list, key, SHARED_RIDE, 70000f, 800f);
    assertFigures(response, list, key, SHARED_GROUPS, 40000f, 300f);
    assertFigures(response, list, key, BARE, null, null);
  }

  /** The four cases for a reader registered nowhere. */
  private static void assertUnregisteredReader(
      ValidatableResponse response, String list, String key) {
    assertFigures(response, list, key, SPLIT, null, null);
    assertFigures(response, list, key, SHARED_RIDE, 70000f, 800f);
    assertFigures(response, list, key, SHARED_GROUPS, 40000f, 300f);
    assertFigures(response, list, key, BARE, null, null);
  }

  private String teamRides() {
    return "/api/teams/" + team1Slug + "/publications?type=RIDE";
  }

  // ==================== Team list ====================

  @Test
  void teamList_registeredReader_getsTheirGroupsRoute() {
    assertRegisteredReader(get(USER3, teamRides()), "publications", "slug");
  }

  @Test
  void teamList_memberNotRegistered_getsTheSharedRouteOrNothing() {
    assertUnregisteredReader(get(USER2, teamRides()), "publications", "slug");
  }

  @Test
  void teamList_anonymous_getsTheSharedRouteOrNothing() {
    assertUnregisteredReader(get(null, teamRides()), "publications", "slug");
  }

  @Test
  void teamList_outsider_getsTheSharedRouteOrNothing() {
    assertUnregisteredReader(get(USER4, teamRides()), "publications", "slug");
  }

  /** The existing figures are left as they were: the ride's route, else the first routed group. */
  @Test
  void teamList_keepsTheExistingDistance() {
    ValidatableResponse response = get(USER3, teamRides());
    response
        .body(row("publications", "slug", SPLIT) + ".distance", equalTo(50000f))
        .body(row("publications", "slug", SPLIT) + ".registeredGroup.distance", equalTo(90000f));
  }

  // ==================== Feed ====================

  @Test
  void feed_registeredReader_getsTheirGroupsRoute() {
    assertRegisteredReader(get(USER3, "/api/publications?type=RIDE"), "publications", "slug");
  }

  @Test
  void feed_anonymous_getsTheSharedRouteOrNothing() {
    assertUnregisteredReader(get(null, "/api/publications?type=RIDE"), "publications", "slug");
  }

  // ==================== My participations ====================

  /** « Ma prochaine sortie »: only the rides user3 joined, with their group's figures. */
  @Test
  void myParticipations_getTheGroupsRoute() {
    ValidatableResponse response = get(USER3, "/api/users/me/participations");
    assertFigures(response, "publications", "slug", SPLIT, 90000f, 1500f);
    assertFigures(response, "publications", "slug", SHARED_RIDE, 70000f, 800f);
    assertFigures(response, "publications", "slug", BARE, null, null);
  }

  // ==================== Dashboard ====================

  /** « Sorties à venir » holds the three soonest: split, shared-ride, shared-groups. */
  @Test
  void dashboard_upcomingRides_followTheRule() {
    String path = "/api/teams/" + team1Slug + "/dashboard";
    String list = "upcomingRides.publications";

    ValidatableResponse registered = get(USER3, path);
    assertFigures(registered, list, "slug", SPLIT, 90000f, 1500f);
    assertFigures(registered, list, "slug", SHARED_RIDE, 70000f, 800f);
    assertFigures(registered, list, "slug", SHARED_GROUPS, 40000f, 300f);

    ValidatableResponse member = get(USER2, path);
    assertFigures(member, list, "slug", SPLIT, null, null);
    assertFigures(member, list, "slug", SHARED_RIDE, 70000f, 800f);
    assertFigures(member, list, "slug", SHARED_GROUPS, 40000f, 300f);

    ValidatableResponse visitor = get(null, path);
    assertFigures(visitor, list, "slug", SPLIT, null, null);
    assertFigures(visitor, list, "slug", SHARED_GROUPS, 40000f, 300f);
  }

  /** « Vos prochaines sorties »: split, shared-ride and bare, as joined by user3. */
  @Test
  void dashboard_myUpcoming_getTheGroupsRoute() {
    ValidatableResponse response = get(USER3, "/api/teams/" + team1Slug + "/dashboard");
    String list = "myUpcoming.publications";
    assertFigures(response, list, "slug", SPLIT, 90000f, 1500f);
    assertFigures(response, list, "slug", SHARED_RIDE, 70000f, 800f);
    assertFigures(response, list, "slug", BARE, null, null);
  }

  // ==================== Detail ====================

  private void assertDetail(
      @Nullable String user, String slug, @Nullable Float distance, @Nullable Float elevation) {
    get(user, "/api/teams/" + team1Slug + "/rides/" + slug)
        .body("displayDistance", distance == null ? nullValue() : equalTo(distance))
        .body("displayElevationGain", elevation == null ? nullValue() : equalTo(elevation));
  }

  @Test
  void detail_registeredReader_getsTheirGroupsRoute() {
    assertDetail(USER3, SPLIT, 90000f, 1500f);
    assertDetail(USER3, SHARED_RIDE, 70000f, 800f);
    assertDetail(USER3, SHARED_GROUPS, 40000f, 300f);
    assertDetail(USER3, BARE, null, null);
  }

  @Test
  void detail_notRegistered_getsTheSharedRouteOrNothing() {
    for (String user : new String[] {USER2, USER4, null}) {
      assertDetail(user, SPLIT, null, null);
      assertDetail(user, SHARED_RIDE, 70000f, 800f);
      assertDetail(user, SHARED_GROUPS, 40000f, 300f);
      assertDetail(user, BARE, null, null);
    }
  }

  /** A deleted route counts as none, as for the estimated end. */
  @Test
  void detail_deletedSharedRoute_showsNothing() {
    Route gone = route("Supprimé", 20000f, 100f);
    Ride ride =
        dataService.createRide(
            team1, user1, "Gone", "gone", Instant.now().plus(9, ChronoUnit.DAYS));
    dataService.setRideRoute(ride, gone);
    dataService.deleteManagedRoute(gone);
    assertDetail(USER2, "gone", null, null);
  }

  // ==================== Calendar ====================

  @Test
  void calendar_registeredReader_getsTheirGroupsRoute() {
    assertRegisteredReader(get(USER3, "/api/calendar/events"), "events", "entitySlug");
  }

  @Test
  void calendar_memberNotRegistered_getsTheSharedRouteOrNothing() {
    assertUnregisteredReader(get(USER2, "/api/calendar/events"), "events", "entitySlug");
  }

  @Test
  void teamCalendar_followsTheRule() {
    String path = "/api/teams/" + team1Slug + "/calendar/events";
    assertRegisteredReader(get(USER3, path), "events", "entitySlug");
    assertUnregisteredReader(get(USER2, path), "events", "entitySlug");
  }

  /** The existing calendar distance stays the ride's own route — null on split. */
  @Test
  void calendar_keepsTheExistingDistance() {
    get(USER3, "/api/calendar/events")
        .body(row("events", "entitySlug", SPLIT) + ".distance", nullValue())
        .body(row("events", "entitySlug", SHARED_RIDE) + ".distance", equalTo(70000f));
  }

  /** A stage has no groups: its own route is everybody's. */
  @Test
  void calendar_tripStage_getsItsRoute() {
    Instant start = Instant.now().plus(5, ChronoUnit.DAYS);
    Trip trip = dataService.createTrip(team1, user1, "Traversée", start);
    TripStage stage = dataService.createTripStage(user1, trip, "Étape 1", start);
    dataService.setTripStageRoute(stage, route("Étape", 30000f, 900f));

    ValidatableResponse response = get(USER2, "/api/calendar/events");
    assertFigures(response, "events", "entitySlug", stage.getSlug(), 30000f, 900f);
  }
}
