package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway.Problem;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.service.route.network.RouteGeneratorGuard;
import fr.pedalons.service.route.planner.PolylineCodec;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code POST /api/teams/{slug}/route-generator} (docs/LEDGER_*.md API-198, lot 3b): the engine of
 * osm-route-details is faked at the level of the HTTP message ({@link FakeRouteGeneratorGateway}),
 * so the request it receives, the problems it answers and what the backend makes of them are all
 * real. Synthetic coordinates only.
 */
@QuarkusTest
class RouteGeneratorResourceTest extends AbstractResourceTest {

  private static final double LAT = 47.2;
  private static final double LON = -1.5;

  @Inject RouteGeneratorGuard guard;
  @Inject TeamRepository teamRepository;

  private String teamRef;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    guard.clear();
    FakeRouteGeneratorGateway.reset();
    FakeRouteDetailsClient.reset();
    dataService.setTeamEnableRoutePlanner(team1, true);
    setTeamLocation(team1, LAT, LON);
    teamRef = TsidUtils.toString(team1.getId());
    FakeRouteGeneratorGateway.markReady(teamRef, "digest");
  }

  @AfterEach
  void restore() {
    FakeRouteGeneratorGateway.reset();
    FakeRouteDetailsClient.reset();
  }

  private void setTeamLocation(Team team, double lat, double lon) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            teamRepository
                .findById(team.getId())
                .setGeometry(
                    org.geolatte.geom.builder.DSL.point(
                        org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84,
                        org.geolatte.geom.builder.DSL.g(lon, lat))));
  }

  private static Map<String, Object> point(double lat, double lon) {
    return Map.of("lng", lon, "lat", lat);
  }

  private static Map<String, Object> loop(double distanceKm) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("start", point(LAT, LON));
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

  // ---------------------------------------------------------------- what the engine receives

  @Test
  void theEngineReceivesTheDefaultsTheKeyAndTheTeamReference() {
    Map<String, Object> body = loop(40);
    body.remove("start"); // the team's location
    post(USER1, team1Slug, body).statusCode(200);

    var seen = FakeRouteGeneratorGateway.lastGenerate();
    assertNotNull(seen);
    assertEquals(FakeRouteGeneratorGateway.TEST_KEY, seen.headers().get("Ord-Namespace-Key"));
    assertEquals(teamRef, seen.headers().get("Ord-Team"));
    assertEquals(0.25, seen.body().get("cursor").asDouble(), 1e-9);
    assertEquals("road", seen.body().get("ride_type").asText());
    assertEquals(0, seen.body().get("seed").asLong());
    assertEquals(40_000, seen.body().get("distance_m").asDouble(), 1e-6);
    assertEquals(LAT, seen.body().get("start").get("lat").asDouble(), 1e-6);
    assertEquals(LON, seen.body().get("start").get("lon").asDouble(), 1e-6);
    assertTrue(seen.body().path("end").isMissingNode() || seen.body().get("end").isNull());
  }

  @Test
  void everyFieldOfTheRequestIsForwarded() {
    Map<String, Object> body = loop(60);
    body.put("end", point(LAT + 0.2, LON));
    body.put("bearing", "NE");
    body.put("type", "GRAVEL");
    body.put("discovery", 0.5);
    body.put("seed", 12345);
    post(USER1, team1Slug, body).statusCode(200);
    var seen = FakeRouteGeneratorGateway.lastGenerate();
    assertEquals("gravel", seen.body().get("ride_type").asText());
    assertEquals("NE", seen.body().get("bearing").asText());
    assertEquals(0.5, seen.body().get("cursor").asDouble(), 1e-9);
    assertEquals(12345, seen.body().get("seed").asLong());
    assertEquals(LAT + 0.2, seen.body().get("end").get("lat").asDouble(), 1e-6);
  }

  // ---------------------------------------------------------------- the share of unpaved asked for

  private static Map<String, Object> ride(String type, String unpaved) {
    Map<String, Object> body = loop(40);
    body.put("type", type);
    if (unpaved != null) {
      body.put("unpaved", unpaved);
    }
    return body;
  }

  private static JsonNode lastBody() {
    return FakeRouteGeneratorGateway.lastGenerate().body();
  }

  @Test
  void aGravelRideWithoutALevelAsksForTheUsualShare() {
    post(USER1, team1Slug, ride("GRAVEL", null)).statusCode(200);
    assertEquals(0.47, lastBody().get("offroad_target").asDouble(), 1e-9);
  }

  @Test
  void theThreeLevelsAreTranslatedToTheirShare() {
    post(USER1, team1Slug, ride("GRAVEL", "LOW")).statusCode(200);
    assertEquals(0.25, lastBody().get("offroad_target").asDouble(), 1e-9);
    post(USER1, team1Slug, ride("GRAVEL", "USUAL")).statusCode(200);
    assertEquals(0.47, lastBody().get("offroad_target").asDouble(), 1e-9);
    post(USER1, team1Slug, ride("GRAVEL", "HIGH")).statusCode(200);
    assertEquals(0.60, lastBody().get("offroad_target").asDouble(), 1e-9);
    post(USER1, team1Slug, ride("MTB", "HIGH")).statusCode(200);
    assertEquals("mtb", lastBody().get("ride_type").asText());
    assertEquals(0.60, lastBody().get("offroad_target").asDouble(), 1e-9);
  }

  @Test
  void aRoadRideSendsNoTargetWhateverTheLevel() {
    post(USER1, team1Slug, ride("ROAD", "HIGH")).statusCode(200);
    assertTrue(lastBody().path("offroad_target").isMissingNode());
    // no type at all is a road ride
    Map<String, Object> body = loop(40);
    body.put("unpaved", "HIGH");
    post(USER1, team1Slug, body)
        .statusCode(200)
        .body("candidates[0].unpavedTarget", nullValue())
        .body("candidates[0].unpavedTargetReached", nullValue());
    assertTrue(lastBody().path("offroad_target").isMissingNode());
  }

  @Test
  void nothingIsSentToAnEngineThatDoesNotAnnounceTheRideType() {
    FakeRouteGeneratorGateway.offroadRideTypes = List.of();
    post(USER1, team1Slug, ride("GRAVEL", "HIGH"))
        .statusCode(200)
        .body("candidates[0].unpavedTarget", nullValue())
        .body("candidates[0].unpavedTargetReached", nullValue());
    assertTrue(lastBody().path("offroad_target").isMissingNode());

    FakeRouteGeneratorGateway.offroadRideTypes = List.of("mtb");
    post(USER1, team1Slug, ride("GRAVEL", "HIGH")).statusCode(200);
    assertTrue(lastBody().path("offroad_target").isMissingNode());
    post(USER1, team1Slug, ride("MTB", "HIGH")).statusCode(200);
    assertEquals(0.60, lastBody().get("offroad_target").asDouble(), 1e-9);
  }

  @Test
  void anEngineRolledBackWithinTheHourIsAskedAgainWithoutTheTarget() {
    // the cached capabilities still announce the steering, the engine (api 1.13) refuses the key
    FakeRouteGeneratorGateway.cachedOffroadRideTypes = List.of("gravel", "mtb");
    FakeRouteGeneratorGateway.offroadRideTypes = List.of();
    post(USER1, team1Slug, ride("GRAVEL", "HIGH"))
        .statusCode(200)
        .body("candidates[0].unpavedTarget", nullValue())
        .body("candidates[0].unpavedTargetReached", nullValue());
    assertEquals(2, FakeRouteGeneratorGateway.calls("POST", "/v1/generator/routes"));
    assertTrue(lastBody().path("offroad_target").isMissingNode());
  }

  @Test
  void aRefusedTargetTheEngineStillAnnouncesIsNotRetried() {
    engineAnswers(new Problem(400, "invalid_input", null, null, null));
    post(USER1, team1Slug, ride("GRAVEL", "HIGH"))
        .statusCode(503)
        .body("code", equalTo("GENERATOR_UNAVAILABLE"));
    assertEquals(1, FakeRouteGeneratorGateway.calls("POST", "/v1/generator/routes"));
  }

  @Test
  void anUnknownLevelIsRefused_andTheEngineNeverCalled() {
    post(USER1, team1Slug, ride("GRAVEL", "SOME")).statusCode(400);
    assertEquals(0, FakeRouteGeneratorGateway.calls("POST", "/v1/generator/routes"));
  }

  @Test
  void theShareIsReadOnOffroadShareAndTheTargetIsJudgedPerRoute() {
    FakeRouteGeneratorGateway.offroadShare = 0.58;
    post(USER1, team1Slug, ride("GRAVEL", "HIGH"))
        .statusCode(200)
        .body("candidates[0].unpavedShare", equalTo(0.58f))
        .body("candidates[0].unpavedTarget", equalTo(0.6f))
        .body("candidates[0].unpavedTargetReached", equalTo(true))
        .body("candidates[1].unpavedTargetReached", equalTo(true));

    // 0.58 is 0.11 away from 0.47, beyond the tolerance of 0.05: the engine did not reach it
    post(USER1, team1Slug, ride("GRAVEL", "USUAL"))
        .statusCode(200)
        .body("candidates[0].unpavedTarget", equalTo(0.47f))
        .body("candidates[0].unpavedTargetReached", equalTo(false))
        .body("candidates[1].unpavedTargetReached", equalTo(false));

    // the tolerance is the engine's
    FakeRouteGeneratorGateway.offroadTolerance = 0.15;
    post(USER1, team1Slug, ride("GRAVEL", "USUAL"))
        .statusCode(200)
        .body("candidates[0].unpavedTargetReached", equalTo(true));
  }

  @Test
  void withoutOffroadShareTheSurfaceTagShareIsRead() {
    // an engine of api 1.13 after a rollback: no offroad_share, no offroad object
    FakeRouteGeneratorGateway.offroadRideTypes = List.of();
    post(USER1, team1Slug, ride("GRAVEL", "HIGH"))
        .statusCode(200)
        .body("candidates[0].unpavedShare", equalTo(0.1f));
  }

  @Test
  void aTargetWithoutTheEnginesOutcomeIsNotReported() {
    // the engine announced the ride type but answered no `offroad` object: its tolerance is
    // unknown, so nothing is claimed
    FakeRouteGeneratorGateway.omitOffroadResult = true;
    post(USER1, team1Slug, ride("GRAVEL", "HIGH"))
        .statusCode(200)
        .body("candidates[0].unpavedTarget", nullValue())
        .body("candidates[0].unpavedTargetReached", nullValue());
  }

  @Test
  void theCursorAtOneIsSentWithTheTeamHeadersToo() {
    FakeRouteGeneratorGateway.OVERLAYS.clear();
    Map<String, Object> body = loop(40);
    body.put("discovery", 1.0);
    post(USER1, team1Slug, body).statusCode(200);
    assertEquals(teamRef, FakeRouteGeneratorGateway.lastGenerate().headers().get("Ord-Team"));
  }

  // ---------------------------------------------------------------- what comes back

  @Test
  void aLoopReturnsTheRoutesWithTheirShareAndTheFastAscent() {
    var response = post(USER1, team1Slug, loop(40)).statusCode(200).extract();
    List<Map<String, Object>> candidates = response.path("candidates");
    assertEquals(2, candidates.size());
    for (Map<String, Object> c : candidates) {
      assertEquals(40_000, ((Number) c.get("distanceM")).doubleValue(), 4_000);
      assertEquals(0.8, ((Number) c.get("teamShare")).doubleValue(), 1e-6);
      assertEquals(0.1, ((Number) c.get("unpavedShare")).doubleValue(), 1e-6);
      assertNotNull(c.get("sharedM"));
      assertEquals(0, ((Number) c.get("crossings")).intValue());
      // the fast profile of the fake is flat: a gain of zero, but present
      assertEquals(0, ((Number) c.get("ascentM")).doubleValue(), 1e-9);
      assertEquals(0, ((Number) c.get("descentM")).doubleValue(), 1e-9);
      double[][] points = PolylineCodec.decode2((String) c.get("polyline"), 200_000);
      @SuppressWarnings("unchecked")
      Map<String, Number> bounds = (Map<String, Number>) c.get("bounds");
      double minLat = Double.MAX_VALUE;
      for (double[] p : points) {
        minLat = Math.min(minLat, p[1]);
      }
      assertEquals(minLat, bounds.get("minLat").doubleValue(), 1e-5);
      assertTrue(c.get("familiarity") == null, "familiarity is gone");
    }
    assertNotNull(response.path("networkPreparedAt"));
    assertEquals(false, response.path("partialCoverage"));
    assertTrue(response.path("network") == null, "network is gone");
  }

  @Test
  void aPartialCoverageIsReported() {
    FakeRouteGeneratorGateway.partial = true;
    post(USER1, team1Slug, loop(40)).statusCode(200).body("partialCoverage", equalTo(true));
  }

  @Test
  void discoveryNeedsNoPreparedNetwork_andReportsNone() {
    FakeRouteGeneratorGateway.OVERLAYS.clear();
    Map<String, Object> body = loop(40);
    body.put("discovery", 1);
    post(USER1, team1Slug, body)
        .statusCode(200)
        .body("networkPreparedAt", nullValue())
        .body("candidates.size()", equalTo(2));
  }

  @Test
  void whenTheFastProfileFailsTheAscentIsAbsentButTheRoutesStay() {
    FakeRouteDetailsClient.failFast = true;
    post(USER1, team1Slug, loop(40))
        .statusCode(200)
        .body("candidates.size()", equalTo(2))
        .body("candidates[0].ascentM", nullValue())
        .body("candidates[0].descentM", nullValue());
  }

  @Test
  void aRouteThatFailsTheSanityCheckIsDropped() {
    FakeRouteGeneratorGateway.routeCount = 3;
    int[] n = {0};
    FakeRouteGeneratorGateway.tamper =
        route -> {
          if (n[0]++ == 1) {
            route.put("team_share", 1.5);
          }
        };
    post(USER1, team1Slug, loop(40)).statusCode(200).body("candidates.size()", equalTo(2));
  }

  @Test
  void whenEveryRouteIsDroppedTheAnswerIsNoRoute() {
    FakeRouteGeneratorGateway.tamper = route -> route.put("distance_m", 1.0);
    post(USER1, team1Slug, loop(40)).statusCode(400).body("code", equalTo("GENERATOR_NO_ROUTE"));
  }

  // ---------------------------------------------------------------- validation

  @Test
  void theDistanceTheCursorAndTheSeedAreBounded() {
    post(USER1, team1Slug, loop(9)).statusCode(400).body("code", equalTo("VALIDATION"));
    post(USER1, team1Slug, loop(201)).statusCode(400).body("code", equalTo("VALIDATION"));
    post(USER1, team1Slug, loop(200)).statusCode(200);
    post(USER1, team1Slug, loop(10)).statusCode(200);
    for (double discovery : new double[] {-0.1, 1.1}) {
      Map<String, Object> body = loop(40);
      body.put("discovery", discovery);
      post(USER1, team1Slug, body).statusCode(400).body("code", equalTo("VALIDATION"));
    }
    Map<String, Object> negativeSeed = loop(40);
    negativeSeed.put("seed", -1);
    post(USER1, team1Slug, negativeSeed).statusCode(400).body("code", equalTo("VALIDATION"));
  }

  @Test
  void theOldFamiliarityIsIgnored() {
    Map<String, Object> body = loop(40);
    body.put("familiarity", 0.9);
    post(USER1, team1Slug, body).statusCode(200);
    assertEquals(
        0.25, FakeRouteGeneratorGateway.lastGenerate().body().get("cursor").asDouble(), 1e-9);
  }

  @Test
  void noStart_andNoTeamLocation_isAValidationError() {
    QuarkusTransaction.requiringNew()
        .run(() -> teamRepository.findById(team1.getId()).setGeometry(null));
    Map<String, Object> body = loop(40);
    body.remove("start");
    post(USER1, team1Slug, body)
        .statusCode(400)
        .body("code", equalTo("VALIDATION"))
        .body("errorDetails.fieldErrors.field", hasItem("start"));
    assertEquals(0, FakeRouteGeneratorGateway.calls("POST", "/v1/generator/routes"));
  }

  // ---------------------------------------------------------------- the engine's answers

  private void engineAnswers(Problem problem) {
    FakeRouteGeneratorGateway.GENERATE_PROBLEMS.add(problem);
  }

  @Test
  void theKeptRefusalsKeepTheirCodes() {
    String[][] cases = {
      {"start_too_far", "GENERATOR_START_TOO_FAR"},
      {"end_too_far", "GENERATOR_END_TOO_FAR"},
      {"distance_too_short", "GENERATOR_DISTANCE_TOO_SHORT"},
      {"network_too_small", "GENERATOR_NETWORK_TOO_SMALL"},
      {"no_candidate", "GENERATOR_NO_ROUTE"},
      {"budget", "GENERATOR_NO_ROUTE"},
    };
    for (String[] c : cases) {
      engineAnswers(new Problem(422, "generation_failed", c[0], null, null));
      post(USER1, team1Slug, loop(40)).statusCode(400).body("code", equalTo(c[1]));
    }
  }

  @Test
  void outsideTheRegionIsItsOwnCode() {
    engineAnswers(new Problem(422, "out_of_coverage", null, null, null));
    post(USER1, team1Slug, loop(40))
        .statusCode(400)
        .body("code", equalTo("GENERATOR_OUT_OF_COVERAGE"));
  }

  @Test
  void aTeamWhoseRoadsAreNotPreparedIsToldSo_andDiscoveryStillWorks() {
    FakeRouteGeneratorGateway.OVERLAYS.clear();
    post(USER1, team1Slug, loop(40))
        .statusCode(400)
        .body("code", equalTo("GENERATOR_NETWORK_NOT_READY"));
    Map<String, Object> discovery = loop(40);
    discovery.put("discovery", 1);
    post(USER1, team1Slug, discovery).statusCode(200);
  }

  @Test
  void aBusyEngineIs503Busy() {
    engineAnswers(new Problem(503, "overloaded", null, null, 2));
    post(USER1, team1Slug, loop(40)).statusCode(503).body("code", equalTo("ROUTE_GENERATOR_BUSY"));
    engineAnswers(new Problem(504, "timeout", null, null, null));
    post(USER1, team1Slug, loop(40)).statusCode(503).body("code", equalTo("ROUTE_GENERATOR_BUSY"));
  }

  @Test
  void anEngineWithoutItsDataOrOutsideTheContractIsUnavailable() {
    engineAnswers(new Problem(503, "data_unavailable", null, null, null));
    post(USER1, team1Slug, loop(40)).statusCode(503).body("code", equalTo("GENERATOR_UNAVAILABLE"));
    engineAnswers(new Problem(400, "invalid_input", null, null, null));
    post(USER1, team1Slug, loop(40)).statusCode(503).body("code", equalTo("GENERATOR_UNAVAILABLE"));
  }

  @Test
  void anEngineBelowApi19IsUnavailable_andNeverCalled() {
    FakeRouteGeneratorGateway.apiVersion = "1.8";
    post(USER1, team1Slug, loop(40)).statusCode(503).body("code", equalTo("GENERATOR_UNAVAILABLE"));
    assertEquals(0, FakeRouteGeneratorGateway.CALLS.size());
  }

  @Test
  void aSwitchedOffGeneratorIsUnavailable() {
    FakeRouteGeneratorGateway.generatorEnabled = false;
    post(USER1, team1Slug, loop(40)).statusCode(503).body("code", equalTo("GENERATOR_UNAVAILABLE"));
    assertEquals(0, FakeRouteGeneratorGateway.CALLS.size());
  }

  // ---------------------------------------------------------------- rights

  @Test
  void rights() {
    post(null, team1Slug, loop(40)).statusCode(401);
    post(USER1, "nope", loop(40)).statusCode(404);
    Domain other = dataService.createDomain("other.test", "Other", "http://other.test");
    User otherUser = dataService.createUser(other, "someone@other.test", "Someone");
    dataService.createTeam(other, otherUser, "Elsewhere", "elsewhere", Visibility.PUBLIC);
    post(USER1, "elsewhere", loop(40)).statusCode(404);
    post(USER4, team1Slug, loop(40)).statusCode(403);
    post(USER3, team1Slug, loop(40)).statusCode(403);
    post(USER2, team1Slug, loop(40)).statusCode(200);
    post(USER1, team1Slug, loop(40)).statusCode(200);
    dataService.createPlatformAdminUser("platform@example.com", "Platform Admin");
    post("platform", team1Slug, loop(40)).statusCode(200);
    // a refused caller reached the engine for none of them
    assertEquals(3, FakeRouteGeneratorGateway.calls("POST", "/v1/generator/routes"));
  }

  @Test
  void aTeamWithoutThePlanner_isRefused() {
    dataService.setTeamEnableRoutePlanner(team1, false);
    post(USER1, team1Slug, loop(40))
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void aUserIsLimitedTo30RequestsIn15Minutes() {
    for (int i = 0; i < 30; i++) {
      post(USER1, team1Slug, loop(40)).statusCode(200);
    }
    post(USER1, team1Slug, loop(40))
        .statusCode(429)
        .header("Retry-After", notNullValue())
        .body("code", equalTo("ROUTE_GENERATOR_RATE_LIMITED"));
    post(USER2, team1Slug, loop(40)).statusCode(200);
  }
}
