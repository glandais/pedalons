package fr.pedalons.api.router;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.infrastructure.routedetails.FakeRouterEngineGateway;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException.Kind;
import fr.pedalons.infrastructure.valhalla.StadiaMapsClient;
import fr.pedalons.infrastructure.valhalla.ValhallaRequest;
import fr.pedalons.infrastructure.valhalla.ValhallaResponse;
import fr.pedalons.service.route.planner.PolylineCodec;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.ws.rs.core.MediaType;
import java.util.List;
import java.util.stream.Stream;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mockito;

/**
 * The planner's second engine (plan docs/plans/2026-11-23-itineraire-velo-osm.md, lot 3): {@code
 * engine = PEDALONS} on {@code POST /api/router}, the silent fallback on Stadia Maps and {@code
 * GET /api/router/engines}. Neither Stadia Maps nor osm-route-details is reached: both are fakes.
 */
@QuarkusTest
class RouterEngineResourceTest extends AbstractResourceTest {

  /** Where the engine's line lies; Stadia's lies at latitude 45.76. */
  private static final double ENGINE_LAT = 45.80;

  private static final double STADIA_LAT = 45.76;

  @InjectMock @RestClient StadiaMapsClient stadiaMapsClient;

  @Inject EntityManager em;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    Mockito.reset(stadiaMapsClient);
    FakeRouterEngineGateway.reset();
    dataService.setDomainEnableGpxPlanner(domain, true);
    when(stadiaMapsClient.route(any(ValhallaRequest.class))).thenReturn(stadiaTrip());
  }

  // ==================== Helpers ====================

  /** A zigzag of 21 points about 235 m apart, which survives the pipeline, at {@code lat}. */
  private static String zigzag(double lat) {
    double[][] points = new double[21][];
    for (int i = 0; i < points.length; i++) {
      points[i] = new double[] {4.83 + 0.001 * i, lat + (i % 2) * 0.002};
    }
    return PolylineCodec.encode2(points);
  }

  private static ValhallaResponse stadiaTrip() {
    return new ValhallaResponse(
        new ValhallaResponse.ValhallaTrip(
            List.of(new ValhallaResponse.ValhallaLeg(zigzag(STADIA_LAT), null))));
  }

  private void engineAnswers(String unpavedJson) {
    FakeRouterEngineGateway.offered = true;
    FakeRouterEngineGateway.responder =
        () ->
            FakeRouterEngineGateway.answer(
                200,
                "application/json",
                FakeRouterEngineGateway.okBody(zigzag(ENGINE_LAT), unpavedJson));
  }

  private static String body(String profile, String engine, String teamSlug) {
    return "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640},"
        + " \"to\": {\"lng\": 4.8500, \"lat\": 45.7700}, \"profile\": \""
        + profile
        + "\""
        + (engine == null ? "" : ", \"engine\": \"" + engine + "\"")
        + (teamSlug == null ? "" : ", \"teamSlug\": \"" + teamSlug + "\"")
        + "}";
  }

  private ValidatableResponse route(String user, String profile, String engine, String teamSlug) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(body(profile, engine, teamSlug))
        .when()
        .post("/api/router")
        .then();
  }

  private JsonNode routeJson(String profile, String engine, String teamSlug) throws Exception {
    String json = route(USER1, profile, engine, teamSlug).statusCode(200).extract().asString();
    return new ObjectMapper().readTree(json);
  }

  private static double firstLat(JsonNode body) {
    return body.path("route").path("coordinates").get(0).get(1).asDouble();
  }

  private long dailyCalls() {
    Object calls =
        QuarkusTransaction.requiringNew()
            .call(() ->
                em.createNativeQuery(
                        "select coalesce(sum(calls), 0) from router_daily_calls"
                            + " where user_id = :userId")
                    .setParameter("userId", user1.getId())
                    .getSingleResult());
    return ((Number) calls).longValue();
  }

  private ValidatableResponse engines(String user, String teamSlug) {
    var request = given().auth().oauth2(getAccessToken(user));
    if (teamSlug != null) {
      request = request.queryParam("teamSlug", teamSlug);
    }
    return request.when().get("/api/router/engines").then();
  }

  // ==================== The engine answers ====================

  @Test
  void pedalons_whenTheEngineAnswers_shouldRenderItsGeometryAndNotCallStadia() throws Exception {
    engineAnswers("[]");

    JsonNode body = routeJson("FASTBIKE", "PEDALONS", null);

    assertEquals(ENGINE_LAT, firstLat(body), 0.01);
    assertTrue(body.path("route").path("coordinates").size() > 2);
    assertEquals(ENGINE_LAT, PolylineCodec.decode2(body.path("shape").asText(), 1000)[0][1], 0.01);
    verify(stadiaMapsClient, never()).route(any());
    assertEquals(1, FakeRouterEngineGateway.CALLS.size());
    assertEquals(1, dailyCalls());
  }

  @Test
  void pedalons_shouldProjectTheEnginesUnpavedRangesOnTheOutput() throws Exception {
    // Inclusive indices 6 to 12 of the 21 points: 30 % to 60 % of the line
    engineAnswers("[[6,12]]");

    JsonNode body = routeJson("GRAVEL", "PEDALONS", null);

    int edges = body.path("route").path("coordinates").size() - 1;
    JsonNode unpaved = body.path("unpaved");
    assertEquals(1, unpaved.size());
    assertEquals(0.3, unpaved.get(0).path("from").asInt() / (double) edges, 0.1);
    assertEquals(0.6, unpaved.get(0).path("to").asInt() / (double) edges, 0.1);
  }

  @Test
  void pedalons_withoutUnpavedRanges_shouldReportAnEmptyList() throws Exception {
    engineAnswers("[]");

    JsonNode body = routeJson("MTB", "PEDALONS", null);

    assertTrue(body.has("unpaved"));
    assertEquals(0, body.path("unpaved").size());
  }

  @Test
  void pedalons_shouldMapTheProfilesToTheEnginesRideTypes() throws Exception {
    engineAnswers("[]");
    for (String profile : List.of("BIKE", "FASTBIKE", "GRAVEL", "MTB")) {
      routeJson(profile, "PEDALONS", null);
    }

    List<String> rideTypes =
        FakeRouterEngineGateway.CALLS.stream()
            .map(c -> {
              try {
                return new ObjectMapper().readTree(c.body()).path("ride_type").asText();
              } catch (Exception e) {
                throw new IllegalStateException(e);
              }
            })
            .toList();
    assertEquals(List.of("road", "road", "gravel", "mtb"), rideTypes);
  }

  private JsonNode routeWithUseRoads(String profile, @Nullable Double useRoads) throws Exception {
    String request =
        "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640},"
            + " \"to\": {\"lng\": 4.8500, \"lat\": 45.7700}, \"profile\": \""
            + profile
            + "\", \"engine\": \"PEDALONS\""
            + (useRoads == null ? "" : ", \"useRoads\": " + useRoads)
            + "}";
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(request)
        .when()
        .post("/api/router")
        .then()
        .statusCode(200);
    return new ObjectMapper()
        .readTree(
            FakeRouterEngineGateway.CALLS.get(FakeRouterEngineGateway.CALLS.size() - 1).body());
  }

  @Test
  void pedalons_whenTheEngineAcceptsUseRoads_shouldSendTheRequestsSettingAndTheProfilesNeutral()
      throws Exception {
    engineAnswers("[]");
    FakeRouterEngineGateway.acceptsUseRoads = true;
    double[] neutrals = {0.25, 1.0, 0.25, 0.25};
    String[] profiles = {"BIKE", "FASTBIKE", "GRAVEL", "MTB"};
    for (int i = 0; i < profiles.length; i++) {
      JsonNode sent = routeWithUseRoads(profiles[i], 0.6);
      assertEquals(0.6, sent.path("use_roads").asDouble(), 1e-9, profiles[i]);
      assertEquals(neutrals[i], sent.path("use_roads_neutral").asDouble(), 1e-9, profiles[i]);
    }
  }

  @Test
  void pedalons_withoutUseRoads_shouldSendTheNeutralForBothFields() throws Exception {
    engineAnswers("[]");
    FakeRouterEngineGateway.acceptsUseRoads = true;
    double[] neutrals = {0.25, 1.0, 0.25, 0.25};
    String[] profiles = {"BIKE", "FASTBIKE", "GRAVEL", "MTB"};
    for (int i = 0; i < profiles.length; i++) {
      JsonNode sent = routeWithUseRoads(profiles[i], null);
      assertEquals(neutrals[i], sent.path("use_roads").asDouble(), 1e-9, profiles[i]);
      assertEquals(neutrals[i], sent.path("use_roads_neutral").asDouble(), 1e-9, profiles[i]);
    }
  }

  @Test
  void pedalons_whenTheEngineDoesNotAnnounceUseRoads_shouldSendNeitherField() throws Exception {
    engineAnswers("[]");
    FakeRouterEngineGateway.acceptsUseRoads = false;
    for (String profile : List.of("BIKE", "FASTBIKE", "GRAVEL", "MTB")) {
      JsonNode sent = routeWithUseRoads(profile, 0.6);
      assertTrue(!sent.has("use_roads") && !sent.has("use_roads_neutral"), profile);
    }
  }

  private JsonNode routeWithAvoid(@Nullable Boolean avoid, @Nullable Double useRoads)
      throws Exception {
    String request =
        "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640},"
            + " \"to\": {\"lng\": 4.8500, \"lat\": 45.7700}, \"profile\": \"BIKE\","
            + " \"engine\": \"PEDALONS\""
            + (avoid == null ? "" : ", \"avoidMainRoads\": " + avoid)
            + (useRoads == null ? "" : ", \"useRoads\": " + useRoads)
            + "}";
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(request)
        .when()
        .post("/api/router")
        .then()
        .statusCode(200);
    return new ObjectMapper()
        .readTree(
            FakeRouterEngineGateway.CALLS.get(FakeRouterEngineGateway.CALLS.size() - 1).body());
  }

  @Test
  void pedalons_avoidMainRoads_shouldBeSentWhenAskedAndAccepted() throws Exception {
    engineAnswers("[]");
    FakeRouterEngineGateway.acceptsAvoidMainRoads = true;

    JsonNode sent = routeWithAvoid(true, null);

    assertTrue(sent.path("avoid_main_roads").asBoolean());
  }

  @Test
  void pedalons_avoidMainRoads_shouldNotBeSentWhenNotAccepted() throws Exception {
    engineAnswers("[]");
    FakeRouterEngineGateway.acceptsAvoidMainRoads = false;

    assertTrue(!routeWithAvoid(true, null).has("avoid_main_roads"));
  }

  @Test
  void pedalons_avoidMainRoads_shouldNeverBeSentAsFalseNorWhenAbsent() throws Exception {
    engineAnswers("[]");
    FakeRouterEngineGateway.acceptsAvoidMainRoads = true;

    assertTrue(!routeWithAvoid(false, null).has("avoid_main_roads"));
    assertTrue(!routeWithAvoid(null, null).has("avoid_main_roads"));
  }

  @Test
  void pedalons_avoidMainRoads_shouldAccumulateWithUseRoads() throws Exception {
    engineAnswers("[]");
    FakeRouterEngineGateway.acceptsAvoidMainRoads = true;
    FakeRouterEngineGateway.acceptsUseRoads = true;

    JsonNode sent = routeWithAvoid(true, 0.6);

    assertTrue(sent.path("avoid_main_roads").asBoolean());
    assertEquals(0.6, sent.path("use_roads").asDouble(), 1e-9);
    assertEquals(0.25, sent.path("use_roads_neutral").asDouble(), 1e-9);
  }

  @Test
  void engines_shouldListTheOptionsTheEngineAccepts_andNoneForStadia() {
    FakeRouterEngineGateway.offered = true;

    engines(USER1, null)
        .statusCode(200)
        .body("engines[0].options.size()", equalTo(0))
        .body("engines[1].options.size()", equalTo(0));

    FakeRouterEngineGateway.acceptsUseRoads = true;
    engines(USER1, null)
        .statusCode(200)
        .body("engines[0].options.size()", equalTo(0))
        .body("engines[1].options", contains("USE_ROADS"));

    FakeRouterEngineGateway.acceptsUseRoads = false;
    FakeRouterEngineGateway.acceptsAvoidMainRoads = true;
    engines(USER1, null).statusCode(200).body("engines[1].options", contains("AVOID_MAIN_ROADS"));

    FakeRouterEngineGateway.acceptsUseRoads = true;
    engines(USER1, null)
        .statusCode(200)
        .body("engines[0].options.size()", equalTo(0))
        .body("engines[1].options", contains("USE_ROADS", "AVOID_MAIN_ROADS"));
  }

  @Test
  void pedalons_withATeam_shouldSendTheTeamsHeaders_andWithoutOneNone() throws Exception {
    dataService.setTeamEnableRoutePlanner(team1, true);
    engineAnswers("[]");

    routeJson("BIKE", "PEDALONS", team1Slug);
    routeJson("BIKE", "PEDALONS", null);

    var withTeam = FakeRouterEngineGateway.CALLS.get(0).headers();
    assertEquals(TsidUtils.toString(team1.getId()), withTeam.get("Ord-Team"));
    assertTrue(withTeam.containsKey("Ord-Namespace-Key"));
    var withoutTeam = FakeRouterEngineGateway.CALLS.get(1).headers();
    assertTrue(
        !withoutTeam.containsKey("Ord-Team") && !withoutTeam.containsKey("Ord-Namespace-Key"));
    JsonNode sent = new ObjectMapper().readTree(FakeRouterEngineGateway.CALLS.get(0).body());
    assertEquals(0.25, sent.path("cursor").asDouble(), 1e-9);
  }

  // ==================== The engine fails: Stadia answers, one point of the quota ===============

  @ParameterizedTest
  @ValueSource(
      strings = {
        "too_long",
        "out_of_coverage",
        "no_route",
        "too_far",
        "overloaded",
        "timeout_problem",
        "data_unavailable",
        "server_error",
        "bad_request",
        "unreadable",
        "empty_polyline",
        "no_answer",
        "read_timeout",
        "not_configured"
      })
  void pedalons_whenTheEngineFails_shouldFallBackOnStadiaWithOneQuotaPoint(String failure)
      throws Exception {
    FakeRouterEngineGateway.offered = true;
    FakeRouterEngineGateway.responder =
        () ->
            switch (failure) {
              case "too_long" -> FakeRouterEngineGateway.problem(422, "too_long", null);
              case "out_of_coverage" ->
                  FakeRouterEngineGateway.problem(422, "out_of_coverage", null);
              case "no_route" ->
                  FakeRouterEngineGateway.problem(422, "generation_failed", "no_route");
              case "too_far" ->
                  FakeRouterEngineGateway.problem(422, "generation_failed", "start_too_far");
              case "overloaded" -> FakeRouterEngineGateway.problem(503, "overloaded", null);
              case "timeout_problem" -> FakeRouterEngineGateway.problem(504, "timeout", null);
              case "data_unavailable" ->
                  FakeRouterEngineGateway.problem(503, "data_unavailable", null);
              case "server_error" -> FakeRouterEngineGateway.problem(500, "internal", null);
              case "bad_request" -> FakeRouterEngineGateway.problem(400, "invalid_input", null);
              case "unreadable" ->
                  FakeRouterEngineGateway.answer(200, "application/json", "not json at all");
              case "empty_polyline" ->
                  FakeRouterEngineGateway.answer(
                      200, "application/json", FakeRouterEngineGateway.okBody("", "[]"));
              case "no_answer" -> throw RouteGeneratorException.of(Kind.NO_ANSWER, null);
              case "read_timeout" -> throw RouteGeneratorException.of(Kind.READ_TIMEOUT, null);
              case "not_configured" -> throw RouteGeneratorException.of(Kind.NOT_CONFIGURED, null);
              default -> throw new IllegalStateException(failure);
            };

    JsonNode body = routeJson("FASTBIKE", "PEDALONS", null);

    assertEquals(STADIA_LAT, firstLat(body), 0.01);
    verify(stadiaMapsClient, times(1)).route(any());
    assertEquals(1, FakeRouterEngineGateway.CALLS.size());
    assertEquals(1, dailyCalls());
  }

  @Test
  void pedalons_whenNotOffered_shouldGoToStadiaWithoutCallingTheEngine() throws Exception {
    FakeRouterEngineGateway.offered = false;

    JsonNode body = routeJson("FASTBIKE", "PEDALONS", null);

    assertEquals(STADIA_LAT, firstLat(body), 0.01);
    assertEquals(0, FakeRouterEngineGateway.CALLS.size());
    verify(stadiaMapsClient, times(1)).route(any());
    assertEquals(1, dailyCalls());
  }

  @Test
  void pedalons_fallbackShouldCarryTheRequestsHillsAndRoadsToStadia() throws Exception {
    FakeRouterEngineGateway.offered = true;
    FakeRouterEngineGateway.responder =
        () -> FakeRouterEngineGateway.problem(422, "out_of_coverage", null);
    String request =
        "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640}, \"to\": {\"lng\": 4.85, \"lat\": 45.77},"
            + " \"profile\": \"BIKE\", \"engine\": \"PEDALONS\", \"useHills\": 0.2,"
            + " \"useRoads\": 0.7}";

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(request)
        .when()
        .post("/api/router")
        .then()
        .statusCode(200);

    var captor = org.mockito.ArgumentCaptor.forClass(ValhallaRequest.class);
    verify(stadiaMapsClient).route(captor.capture());
    var options = captor.getValue().costingOptions().get("bicycle");
    assertEquals(0.2, ((Number) options.get("use_hills")).doubleValue(), 1e-9);
    assertEquals(0.7, ((Number) options.get("use_roads")).doubleValue(), 1e-9);
  }

  // ==================== Stadia stays the default ====================

  @Test
  void withoutEngine_shouldUseStadiaAndNeverCallTheEngine() throws Exception {
    engineAnswers("[]");

    JsonNode body = routeJson("FASTBIKE", null, null);

    assertEquals(STADIA_LAT, firstLat(body), 0.01);
    assertEquals(0, FakeRouterEngineGateway.CALLS.size());
    verify(stadiaMapsClient, times(1)).route(any());
  }

  @Test
  void explicitStadia_shouldNeverCallTheEngine() throws Exception {
    engineAnswers("[]");

    JsonNode body = routeJson("GRAVEL", "STADIA", null);

    assertEquals(STADIA_LAT, firstLat(body), 0.01);
    assertEquals(0, FakeRouterEngineGateway.CALLS.size());
  }

  @ParameterizedTest
  @MethodSource("profilesTheEngineDoesNotServe")
  void pedalonsOnAnotherProfile_shouldGoToStadia(String profile) throws Exception {
    engineAnswers("[]");

    JsonNode body = routeJson(profile, "PEDALONS", null);

    assertEquals(STADIA_LAT, firstLat(body), 0.01);
    assertEquals(0, FakeRouterEngineGateway.CALLS.size());
    verify(stadiaMapsClient, times(1)).route(any());
  }

  static Stream<String> profilesTheEngineDoesNotServe() {
    return Stream.of("RUN_HIKE", "MOTORCYCLE");
  }

  // ==================== Rights and quota come first ====================

  @Test
  void pedalons_asNonMember_shouldReturn403BeforeAnyEngine() {
    dataService.setTeamEnableRoutePlanner(team1, true);
    engineAnswers("[]");

    route(USER4, "BIKE", "PEDALONS", team1Slug).statusCode(403);

    assertEquals(0, FakeRouterEngineGateway.CALLS.size());
    verify(stadiaMapsClient, never()).route(any());
  }

  // ==================== GET /api/router/engines ====================

  @Test
  void engines_withoutTheEngine_shouldOfferStadiaWithItsSixProfiles() {
    FakeRouterEngineGateway.offered = false;

    engines(USER1, null)
        .statusCode(200)
        .body("engines.size()", equalTo(1))
        .body("engines[0].engine", equalTo("STADIA"))
        .body(
            "engines[0].profiles",
            contains("BIKE", "FASTBIKE", "GRAVEL", "MTB", "RUN_HIKE", "MOTORCYCLE"));
  }

  @Test
  void engines_withTheEngine_shouldAddPedalonsWithTheFourBicycleProfiles() {
    FakeRouterEngineGateway.offered = true;

    engines(USER1, null)
        .statusCode(200)
        .body("engines.size()", equalTo(2))
        .body("engines[0].engine", equalTo("STADIA"))
        .body("engines[1].engine", equalTo("PEDALONS"))
        .body("engines[1].profiles", contains("BIKE", "FASTBIKE", "GRAVEL", "MTB"));
    assertEquals(0, FakeRouterEngineGateway.CALLS.size());
    assertEquals(0, dailyCalls());
  }

  @Test
  void engines_withATeam_shouldAnswerTheSameForAMember() {
    dataService.setTeamEnableRoutePlanner(team1, true);
    FakeRouterEngineGateway.offered = true;

    engines(USER1, team1Slug).statusCode(200).body("engines.size()", equalTo(2));
  }

  @Test
  void engines_asNonMember_shouldReturn403() {
    dataService.setTeamEnableRoutePlanner(team1, true);
    FakeRouterEngineGateway.offered = true;

    engines(USER4, team1Slug).statusCode(403);
  }

  @Test
  void engines_withATeamWhoseePlannerIsOff_shouldReturn400() {
    engines(USER1, team1Slug).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void engines_withoutTeamAndDomainPlannerOff_shouldReturn400() {
    dataService.setDomainEnableGpxPlanner(domain, false);

    engines(USER1, null).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void engines_withoutAuth_shouldReturn401() {
    given().when().get("/api/router/engines").then().statusCode(401);
  }
}
