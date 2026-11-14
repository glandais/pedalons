package fr.pedalons.api.routes;

import static fr.pedalons.util.NetworkEdgesFixtures.lat;
import static fr.pedalons.util.NetworkEdgesFixtures.lon;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.notNullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.service.route.network.RouteGeneratorGuard;
import fr.pedalons.service.route.network.TeamNetworkCache;
import fr.pedalons.service.route.planner.PolylineCodec;
import fr.pedalons.util.NetworkEdgesFixtures;
import fr.pedalons.util.NetworkEdgesSeeder;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code POST /api/teams/{slug}/route-generator} (docs/LEDGER_*.md API-198, lot 3): routes made of
 * the roads the team rides, on a grid of 5 x 5 street nodes one kilometre apart (40 km of road),
 * ridden by five rows and five columns.
 */
@QuarkusTest
class RouteGeneratorResourceTest extends AbstractResourceTest {

  private static final int SIZE = 5;

  @Inject NetworkEdgesSeeder seeder;
  @Inject RouteGeneratorGuard guard;
  @Inject TeamNetworkCache cache;
  @Inject TeamRepository teamRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    guard.clear();
    cache.clearForTest();
    dataService.setTeamEnableRoutePlanner(team1, true);
    seeder.seedGrid(team1, user1, SIZE);
    setTeamLocation(team1, 2, 2);
  }

  private void setTeamLocation(Team team, double x, double y) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            teamRepository
                .findById(team.getId())
                .setGeometry(
                    org.geolatte.geom.builder.DSL.point(
                        org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84,
                        org.geolatte.geom.builder.DSL.g(lon(x), lat(y)))));
  }

  private static Map<String, Object> point(double x, double y) {
    return Map.of("lng", lon(x), "lat", lat(y));
  }

  private static Map<String, Object> loop(double distanceKm) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("start", point(2, 2));
    body.put("distanceKm", distanceKm);
    return body;
  }

  private ValidatableResponse post(String user, String slug, Map<String, Object> body) {
    var spec = given().contentType(ContentType.JSON).body(body);
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().post("/api/teams/" + slug + "/route-generator").then();
  }

  // ---------------------------------------------------------------- happy paths

  @Test
  void aLoopWithDefaults_returnsRoutesOnTheGrid() {
    Map<String, Object> body = loop(10);
    body.remove("start"); // the team's location
    var response = post(USER1, team1Slug, body).statusCode(200).extract();
    List<Map<String, Object>> candidates = response.path("candidates");
    assertTrue(!candidates.isEmpty() && candidates.size() <= 3, "candidates: " + candidates.size());
    for (Map<String, Object> c : candidates) {
      assertEquals(10_000, ((Number) c.get("distanceM")).doubleValue(), 1_000);
      double[][] points = PolylineCodec.decode2((String) c.get("polyline"), 200_000);
      @SuppressWarnings("unchecked")
      Map<String, Number> bounds = (Map<String, Number>) c.get("bounds");
      double minLon = Double.MAX_VALUE, minLat = Double.MAX_VALUE;
      double maxLon = -Double.MAX_VALUE, maxLat = -Double.MAX_VALUE;
      for (double[] p : points) {
        assertTrue(p[0] >= lon(0) - 1e-4 && p[0] <= lon(4) + 1e-4, "lon " + p[0]);
        assertTrue(p[1] >= lat(0) - 1e-4 && p[1] <= lat(4) + 1e-4, "lat " + p[1]);
        minLon = Math.min(minLon, p[0]);
        maxLon = Math.max(maxLon, p[0]);
        minLat = Math.min(minLat, p[1]);
        maxLat = Math.max(maxLat, p[1]);
      }
      assertEquals(minLon, bounds.get("minLon").doubleValue(), 1e-5);
      assertEquals(maxLon, bounds.get("maxLon").doubleValue(), 1e-5);
      assertEquals(minLat, bounds.get("minLat").doubleValue(), 1e-5);
      assertEquals(maxLat, bounds.get("maxLat").doubleValue(), 1e-5);
      // a loop ends where it started
      assertEquals(points[0][0], points[points.length - 1][0], 1e-3);
      assertEquals(points[0][1], points[points.length - 1][1], 1e-3);
      assertNotNull(c.get("familiarity"));
    }
    assertEquals(10, ((Number) response.path("network.routeCount")).intValue());
    assertEquals(0, ((Number) response.path("network.pendingRouteCount")).intValue());
    assertEquals(false, response.path("network.incomplete"));
    assertEquals(40_000, ((Number) response.path("network.totalLengthM")).doubleValue(), 2_000);
    assertTrue(((Number) response.path("network.lengthM")).doubleValue() > 0);
  }

  @Test
  void aOneWayTrip_andABearing_work() {
    Map<String, Object> trip = loop(10);
    trip.put("start", point(0, 0));
    trip.put("end", point(4, 4));
    trip.put("bearing", "NE");
    trip.put("type", "GRAVEL");
    trip.put("familiarity", 0.8);
    // far end: the bearing does not apply
    post(USER1, team1Slug, trip)
        .statusCode(200)
        .body("candidates.size()", greaterThan(0))
        .body("candidates[0].bearingDeviationDeg", org.hamcrest.Matchers.nullValue());
  }

  @Test
  void theSameSeed_givesTheSameAnswer() {
    Map<String, Object> body = loop(10);
    body.put("seed", 12345);
    List<String> first =
        post(USER1, team1Slug, body).statusCode(200).extract().path("candidates.polyline");
    List<String> second =
        post(USER1, team1Slug, body).statusCode(200).extract().path("candidates.polyline");
    assertEquals(first, second);
  }

  // ---------------------------------------------------------------- validation

  @Test
  void theDistanceAndFamiliarityAreBounded() {
    post(USER1, team1Slug, loop(9)).statusCode(400).body("code", equalTo("VALIDATION"));
    post(USER1, team1Slug, loop(301)).statusCode(400).body("code", equalTo("VALIDATION"));
    Map<String, Object> body = loop(10);
    body.put("familiarity", 1.5);
    post(USER1, team1Slug, body).statusCode(400).body("code", equalTo("VALIDATION"));
  }

  @Test
  void noStart_andNoTeamLocation_isAValidationError() {
    QuarkusTransaction.requiringNew()
        .run(() -> teamRepository.findById(team1.getId()).setGeometry(null));
    Map<String, Object> body = loop(10);
    body.remove("start");
    post(USER1, team1Slug, body)
        .statusCode(400)
        .body("code", equalTo("VALIDATION"))
        .body("errorDetails.fieldErrors.field", hasItem("start"));
  }

  // ---------------------------------------------------------------- failures

  @Test
  void aStartFarFromTheNetwork_isRefused() {
    Map<String, Object> body = loop(10);
    body.put("start", point(2, 8));
    post(USER1, team1Slug, body).statusCode(400).body("code", equalTo("GENERATOR_START_TOO_FAR"));
  }

  @Test
  void anEndFarFromTheNetwork_isRefused() {
    Map<String, Object> body = loop(10);
    body.put("end", point(2, 8));
    post(USER1, team1Slug, body).statusCode(400).body("code", equalTo("GENERATOR_END_TOO_FAR"));
  }

  @Test
  void aDistanceShorterThanTheWayToTheEnd_isRefused() {
    // a team that rides one straight 11 km road only: 10 km cannot reach its far end
    Team team = dataService.createTeam(user1, "Line", "line", Visibility.PUBLIC);
    dataService.setTeamEnableRoutePlanner(team, true);
    int[][] line = new int[12][];
    for (int x = 0; x < 12; x++) {
      line[x] = new int[] {x, 0};
    }
    seeder.seedWalk(team, user1, "Long road", line);
    Map<String, Object> body = loop(10);
    body.put("start", point(0, 0));
    body.put("end", point(11, 0));
    post(USER1, "line", body).statusCode(400).body("code", equalTo("GENERATOR_DISTANCE_TOO_SHORT"));
  }

  @Test
  void aNetworkTooSmallForTheDistance_carriesItsSummary() {
    post(USER1, team1Slug, loop(300))
        .statusCode(400)
        .body("code", equalTo("GENERATOR_NETWORK_TOO_SMALL"))
        .body("errorDetails.type", equalTo("GENERATOR_NETWORK_TOO_SMALL"))
        .body("errorDetails.routeCount", equalTo(10))
        .body("errorDetails.pendingRouteCount", equalTo(0))
        .body("errorDetails.incomplete", equalTo(false))
        .body("errorDetails.totalLengthM", greaterThan(30_000f));
  }

  @Test
  void aTeamWhoseRoutesAreStillBeingAnalysed_isToldSo() {
    Team team = dataService.createTeam(user1, "Fresh", "fresh", Visibility.PUBLIC);
    dataService.setTeamEnableRoutePlanner(team, true);
    seeder.seedPending(team, user1, "Not analysed 1");
    seeder.seedPending(team, user1, "Not analysed 2");
    post(USER1, "fresh", loop(20))
        .statusCode(400)
        .body("code", equalTo("GENERATOR_NETWORK_TOO_SMALL"))
        .body("errorDetails.routeCount", equalTo(0))
        .body("errorDetails.pendingRouteCount", equalTo(2))
        .body("errorDetails.incomplete", equalTo(true));
  }

  @Test
  void aStaleRevision_andAnUnknownVersion_leaveTheTrackPending() {
    var stale = seeder.seedPending(team1, user1, "Stale");
    seeder.write(
        stale.trackId(),
        NetworkEdgesFixtures.withRev(
            NetworkEdgesFixtures.walk(stale.rev(), new int[] {0, 0}, new int[] {1, 0}),
            stale.rev() + 1));
    var future = seeder.seedPending(team1, user1, "From the future");
    seeder.write(
        future.trackId(),
        NetworkEdgesFixtures.withVersion(
            NetworkEdgesFixtures.walk(future.rev(), new int[] {0, 0}, new int[] {1, 0}), 99));
    post(USER1, team1Slug, loop(10))
        .statusCode(200)
        .body("network.routeCount", equalTo(10))
        .body("network.pendingRouteCount", equalTo(2))
        .body("network.incomplete", equalTo(true));
  }

  @Test
  void excludedRoutes_doNotFeedTheNetwork() {
    // tick every route but one row
    seeder.sql(
        "update team_entities set excluded_from_generator = true, version = version + 1"
            + " where team_id = ?1 and entity_type = 2 and name <> 'Row 0'",
        team1.getId());
    post(USER1, team1Slug, loop(10))
        .statusCode(400)
        .body("code", equalTo("GENERATOR_NETWORK_TOO_SMALL"))
        .body("errorDetails.routeCount", equalTo(1))
        .body("errorDetails.excludedRouteCount", equalTo(9));
  }

  // ---------------------------------------------------------------- rights

  @Test
  void rights() {
    // unauthenticated
    post(null, team1Slug, loop(10)).statusCode(401);
    // unknown slug
    post(USER1, "nope", loop(10)).statusCode(404);
    // another domain's team
    Domain other = dataService.createDomain("other.test", "Other", "http://other.test");
    User otherUser = dataService.createUser(other, "someone@other.test", "Someone");
    dataService.createTeam(other, otherUser, "Elsewhere", "elsewhere", Visibility.PUBLIC);
    post(USER1, "elsewhere", loop(10)).statusCode(404);
    // not a member
    post(USER4, team1Slug, loop(10)).statusCode(403);
    // a plain member may not create routes
    post(USER3, team1Slug, loop(10)).statusCode(403);
    // organizer, admin
    post(USER2, team1Slug, loop(10)).statusCode(200);
    post(USER1, team1Slug, loop(10)).statusCode(200);
    // a platform admin
    dataService.createPlatformAdminUser("platform@example.com", "Platform Admin");
    post("platform", team1Slug, loop(10)).statusCode(200);
  }

  @Test
  void aTeamWithoutThePlanner_isRefused() {
    dataService.setTeamEnableRoutePlanner(team1, false);
    post(USER1, team1Slug, loop(10))
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void aUserIsLimitedTo30RequestsIn15Minutes() {
    for (int i = 0; i < 30; i++) {
      post(USER1, team1Slug, loop(10)).statusCode(200);
    }
    post(USER1, team1Slug, loop(10))
        .statusCode(429)
        .header("Retry-After", notNullValue())
        .body("code", equalTo("ROUTE_GENERATOR_RATE_LIMITED"));
    // another user is not
    post(USER2, team1Slug, loop(10)).statusCode(200);
  }
}
