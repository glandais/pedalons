package fr.pedalons.api.router;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.valhalla.StadiaMapsClient;
import fr.pedalons.infrastructure.valhalla.ValhallaRequest;
import fr.pedalons.infrastructure.valhalla.ValhallaResponse;
import fr.pedalons.service.route.planner.PolylineCodec;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.List;
import java.util.Map;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

/**
 * {@code POST /api/router}: who may draw (domain flag, or team flag plus the right to create
 * routes) and the distinct routing errors (docs/plans/2026-10-17-editeur-parcours-web.md, A10).
 * Stadia Maps is mocked: no test calls the billed API.
 */
@QuarkusTest
class RouterResourceTest extends AbstractResourceTest {

  @InjectMock @RestClient StadiaMapsClient stadiaMapsClient;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    Mockito.reset(stadiaMapsClient);
  }

  private static String body(String teamSlug) {
    String team = teamSlug == null ? "" : ", \"teamSlug\": \"" + teamSlug + "\"";
    return "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640},"
        + " \"to\": {\"lng\": 4.8500, \"lat\": 45.7700}, \"profile\": \"BIKE\""
        + team
        + "}";
  }

  private ValidatableResponse route(String user, String teamSlug) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(body(teamSlug))
        .when()
        .post("/api/router")
        .then();
  }

  private void emptyRouteFromStadia() {
    // No trip: the service answers an empty route without running the GPX pipeline.
    when(stadiaMapsClient.route(any(ValhallaRequest.class))).thenReturn(new ValhallaResponse(null));
  }

  private static WebApplicationException stadiaError(int status, String body) {
    Response.ResponseBuilder builder = Response.status(status);
    if (body != null) {
      builder.entity(body).type(MediaType.APPLICATION_JSON);
    }
    return new WebApplicationException(builder.build());
  }

  // ==================== Without a team: the domain flag ====================

  @Test
  void route_withoutTeam_whenDomainPlannerDisabled_shouldReturn400BeforeCallingStadia() {
    route(USER1, null).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void route_withoutTeam_whenDomainPlannerEnabled_shouldCallStadia() {
    dataService.setDomainEnableGpxPlanner(domain, true);
    emptyRouteFromStadia();

    route(USER1, null).statusCode(200);

    verify(stadiaMapsClient).route(any());
  }

  @Test
  void route_withoutAuth_shouldReturn401() {
    given()
        .contentType(MediaType.APPLICATION_JSON)
        .body(body(null))
        .when()
        .post("/api/router")
        .then()
        .statusCode(401);
  }

  // ==================== With a team: the team flag and the right to create routes
  // ====================

  @Test
  void route_withTeam_whenTeamPlannerDisabled_shouldReturn400BeforeCallingStadia() {
    // The domain flag is irrelevant once a team is named.
    dataService.setDomainEnableGpxPlanner(domain, true);

    route(USER1, team1Slug).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void route_withTeam_whenTeamPlannerEnabled_shouldCallStadiaEvenIfDomainPlannerDisabled() {
    dataService.setTeamEnableRoutePlanner(team1, true);
    emptyRouteFromStadia();

    route(USER1, team1Slug).statusCode(200);

    verify(stadiaMapsClient).route(any());
  }

  @Test
  void route_withTeam_asNonMember_shouldReturn403BeforeCallingStadia() {
    dataService.setTeamEnableRoutePlanner(team1, true);

    route(USER4, team1Slug).statusCode(403);

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void route_withTeam_asPlainMember_shouldReturn403BeforeCallingStadia() {
    dataService.setTeamEnableRoutePlanner(team1, true);

    route(USER3, team1Slug).statusCode(403);

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void route_withTeam_asNonMember_whenTeamPlannerDisabled_shouldNotRevealTheFlag() {
    route(USER4, team1Slug).statusCode(403);

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void route_withUnknownTeam_shouldReturn404BeforeCallingStadia() {
    route(USER1, "no-such-team").statusCode(404);

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void route_withTeamOfAnotherDomain_shouldReturn404BeforeCallingStadia() {
    var other = dataService.createDomain("other.example.com", "Other", "https://other.example.com");
    var owner = dataService.createUser(other, "owner@other.example.com", "Owner");
    var otherTeam =
        dataService.createTeam(other, owner, "Other team", "other-team", Visibility.PUBLIC);
    dataService.setTeamEnableRoutePlanner(otherTeam, true);

    route(USER1, "other-team").statusCode(404);

    verify(stadiaMapsClient, never()).route(any());
  }

  // ==================== Routing errors ====================

  private void teamPlannerOn() {
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  @Test
  void route_whenQuotaSpent_shouldReturn503RoutingQuotaExceeded() {
    teamPlannerOn();
    when(stadiaMapsClient.route(any())).thenThrow(stadiaError(429, null));

    route(USER1, team1Slug).statusCode(503).body("code", equalTo("ROUTING_QUOTA_EXCEEDED"));
  }

  @Test
  void route_whenSegmentTooLong_shouldReturn400RoutingSegmentTooLong() {
    teamPlannerOn();
    when(stadiaMapsClient.route(any()))
        .thenThrow(
            stadiaError(
                400,
                "{\"error_code\":154,\"error\":\"Path distance exceeds the max distance limit\","
                    + "\"status_code\":400,\"status\":\"Bad Request\"}"));

    route(USER1, team1Slug).statusCode(400).body("code", equalTo("ROUTING_SEGMENT_TOO_LONG"));
  }

  @Test
  void route_whenNoPathOrNoEdge_shouldReturn400RoutingNoRoute() {
    teamPlannerOn();
    for (int valhallaCode : new int[] {170, 171, 441, 442}) {
      // doThrow: re-stubbing with when(...) would call the mock, which still throws.
      Mockito.doThrow(stadiaError(400, "{\"error_code\":" + valhallaCode + "}"))
          .when(stadiaMapsClient)
          .route(any());

      route(USER1, team1Slug).statusCode(400).body("code", equalTo("ROUTING_NO_ROUTE"));
    }
  }

  @Test
  void route_whenOtherBadRequest_shouldStayUnknown() {
    teamPlannerOn();
    when(stadiaMapsClient.route(any())).thenThrow(stadiaError(400, "{\"error_code\":999}"));

    route(USER1, team1Slug).statusCode(400).body("code", equalTo("UNKNOWN"));
  }

  @Test
  void route_whenErrorBodyIsEmptyOrNotJson_shouldStillMapTheStatus() {
    teamPlannerOn();
    when(stadiaMapsClient.route(any()))
        .thenThrow(stadiaError(400, null))
        .thenThrow(stadiaError(400, "<html>Bad Request</html>"));

    route(USER1, team1Slug).statusCode(400).body("code", equalTo("UNKNOWN"));
    route(USER1, team1Slug).statusCode(400).body("code", equalTo("UNKNOWN"));
  }

  @Test
  void route_whenStadiaFails_shouldReturn503RoutingUnavailable() {
    teamPlannerOn();
    when(stadiaMapsClient.route(any())).thenThrow(stadiaError(500, null));

    route(USER1, team1Slug).statusCode(503).body("code", equalTo("ROUTING_UNAVAILABLE"));
  }

  @Test
  void route_whenStadiaTimesOut_shouldReturn503RoutingUnavailable() {
    teamPlannerOn();
    when(stadiaMapsClient.route(any())).thenThrow(new ProcessingException("read timed out"));

    route(USER1, team1Slug).statusCode(503).body("code", equalTo("ROUTING_UNAVAILABLE"));
  }

  // ==================== Tuning: useHills / useRoads (C2) ====================

  private ValhallaRequest routeWith(String profile, String extra) {
    dataService.setDomainEnableGpxPlanner(domain, true);
    emptyRouteFromStadia();
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(
            "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640},"
                + " \"to\": {\"lng\": 4.8500, \"lat\": 45.7700}, \"profile\": \""
                + profile
                + "\""
                + extra
                + "}")
        .when()
        .post("/api/router")
        .then()
        .statusCode(200);
    ArgumentCaptor<ValhallaRequest> captor = ArgumentCaptor.forClass(ValhallaRequest.class);
    verify(stadiaMapsClient).route(captor.capture());
    return captor.getValue();
  }

  @Test
  void route_withoutTuning_shouldSendTheProfileOptionsUntouched() {
    assertEquals(
        Map.of("bicycle", Map.of("bicycle_type", "hybrid")),
        routeWith("BIKE", "").costingOptions());
  }

  @Test
  void route_fastbikeWithoutTuning_shouldSendTheProfileOptionsUntouched() {
    assertEquals(
        Map.of("bicycle", Map.of("bicycle_type", "road", "use_roads", 1, "avoid_bad_surfaces", 1)),
        routeWith("FASTBIKE", "").costingOptions());
  }

  @Test
  void route_fastbikeWithUseRoads_shouldReplaceOnlyThatValue() {
    Map<String, Object> options =
        routeWith("FASTBIKE", ", \"useRoads\": 0.25").costingOptions().get("bicycle");

    assertEquals(0.25, options.get("use_roads"));
    assertEquals("road", options.get("bicycle_type"));
    assertEquals(1, options.get("avoid_bad_surfaces"));
  }

  @Test
  void route_bikeWithUseHills_shouldAddUseHillsOnly() {
    Map<String, Object> options =
        routeWith("BIKE", ", \"useHills\": 0").costingOptions().get("bicycle");

    assertEquals(0.0, options.get("use_hills"));
    assertFalse(options.containsKey("use_roads"));
    assertEquals("hybrid", options.get("bicycle_type"));
  }

  @Test
  void route_withOutOfRangeTuning_shouldReturn400BeforeCallingStadia() {
    dataService.setDomainEnableGpxPlanner(domain, true);
    for (String extra : new String[] {", \"useHills\": 1.5", ", \"useRoads\": -0.1"}) {
      given()
          .auth()
          .oauth2(getAccessToken(USER1))
          .contentType(MediaType.APPLICATION_JSON)
          .body(
              "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640},"
                  + " \"to\": {\"lng\": 4.8500, \"lat\": 45.7700}, \"profile\": \"BIKE\""
                  + extra
                  + "}")
          .when()
          .post("/api/router")
          .then()
          .statusCode(400);
    }

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void route_runHikeAndMotorcycleWithTuning_shouldIgnoreIt() {
    String both = ", \"useHills\": 0.5, \"useRoads\": 0.5";
    assertTrue(routeWith("RUN_HIKE", both).costingOptions().isEmpty());
    Mockito.reset(stadiaMapsClient);
    assertTrue(routeWith("MOTORCYCLE", both).costingOptions().isEmpty());
  }

  // ==================== Surface: the rough maneuvers (WEB-100, C1a) ====================

  /** A zigzag of 21 points about 235 m apart (synthetic, around Lyon), which survives the pipeline. */
  private static String zigzagShape() {
    double[][] points = new double[21][];
    for (int i = 0; i < points.length; i++) {
      points[i] = new double[] {4.83 + 0.001 * i, 45.76 + (i % 2) * 0.002};
    }
    return PolylineCodec.encode2(points);
  }

  private static ValhallaResponse tripOf(List<ValhallaResponse.ValhallaManeuver> maneuvers) {
    return new ValhallaResponse(
        new ValhallaResponse.ValhallaTrip(
            List.of(new ValhallaResponse.ValhallaLeg(zigzagShape(), maneuvers))));
  }

  private static ValhallaResponse.ValhallaManeuver maneuver(int begin, int end, Boolean rough) {
    return new ValhallaResponse.ValhallaManeuver(begin, end, rough);
  }

  private JsonNode routeBody() throws Exception {
    dataService.setDomainEnableGpxPlanner(domain, true);
    String json = route(USER1, null).statusCode(200).extract().asString();
    return new ObjectMapper().readTree(json);
  }

  @Test
  void route_withRoughManeuvers_shouldReportTheUnpavedRunOnTheOutputEdges() throws Exception {
    when(stadiaMapsClient.route(any(ValhallaRequest.class)))
        .thenReturn(
            tripOf(List.of(maneuver(0, 6, null), maneuver(6, 12, true), maneuver(12, 20, false))));

    JsonNode body = routeBody();

    int edges = body.path("route").path("coordinates").size() - 1;
    JsonNode unpaved = body.path("unpaved");
    assertEquals(1, unpaved.size());
    // The rough maneuver covers the 6th to the 12th of the 20 segments: 30 % to 60 % of the line.
    assertEquals(0.3, unpaved.get(0).path("from").asInt() / (double) edges, 0.1);
    assertEquals(0.6, unpaved.get(0).path("to").asInt() / (double) edges, 0.1);
    assertTrue(unpaved.get(0).path("to").asInt() <= edges);
  }

  @Test
  void route_withAdjacentRoughManeuvers_shouldMergeThemIntoOneRun() throws Exception {
    when(stadiaMapsClient.route(any(ValhallaRequest.class)))
        .thenReturn(
            tripOf(List.of(maneuver(0, 4, true), maneuver(4, 9, true), maneuver(9, 20, null))));

    JsonNode unpaved = routeBody().path("unpaved");

    assertEquals(1, unpaved.size());
    assertEquals(0, unpaved.get(0).path("from").asInt());
  }

  @Test
  void route_withoutRoughManeuver_shouldReportAnEmptyList() throws Exception {
    when(stadiaMapsClient.route(any(ValhallaRequest.class)))
        .thenReturn(tripOf(List.of(maneuver(0, 20, null))));

    JsonNode body = routeBody();

    assertTrue(body.has("unpaved"));
    assertEquals(0, body.path("unpaved").size());
  }

  @Test
  void route_withoutManeuvers_shouldOmitTheSurface() throws Exception {
    when(stadiaMapsClient.route(any(ValhallaRequest.class))).thenReturn(tripOf(null));

    JsonNode body = routeBody();

    assertFalse(body.has("unpaved") && !body.path("unpaved").isNull());
    assertTrue(body.path("route").path("coordinates").size() > 2);
  }

  @Test
  void route_whenTheEmptyTripHasNoSurface_shouldOmitIt() throws Exception {
    emptyRouteFromStadia();

    assertFalse(routeBody().hasNonNull("unpaved"));
  }

  // ==================== The raw geometry (API-147, phase C) ====================

  @Test
  void route_shouldReturnTheRawShapeUntouched() throws Exception {
    // Two legs: their shapes are concatenated as decoded, the shared point twice
    String first = zigzagShape();
    String second =
        PolylineCodec.encode2(new double[][] {{4.85, 45.76}, {4.851, 45.7605}, {4.852, 45.761}});
    when(stadiaMapsClient.route(any(ValhallaRequest.class)))
        .thenReturn(
            new ValhallaResponse(
                new ValhallaResponse.ValhallaTrip(
                    List.of(
                        new ValhallaResponse.ValhallaLeg(first, null),
                        new ValhallaResponse.ValhallaLeg(second, null)))));

    JsonNode body = routeBody();

    double[][] shape = PolylineCodec.decode2(body.path("shape").asText(), Integer.MAX_VALUE);
    double[][] a = PolylineCodec.decode2(first, Integer.MAX_VALUE);
    double[][] b = PolylineCodec.decode2(second, Integer.MAX_VALUE);
    assertEquals(a.length + b.length, shape.length);
    assertEquals(a[1][0], shape[1][0], 1e-9);
    assertEquals(a[1][1], shape[1][1], 1e-9);
    assertEquals(b[2][0], shape[shape.length - 1][0], 1e-9);
    assertEquals(b[2][1], shape[shape.length - 1][1], 1e-9);
    // The displayed route is still the simplified one, its ends those of the shape
    JsonNode route = body.path("route").path("coordinates");
    assertTrue(route.size() < shape.length);
    assertEquals(shape[0][0], route.get(0).get(0).asDouble(), 1e-6);
    assertEquals(shape[0][1], route.get(0).get(1).asDouble(), 1e-6);
  }

  @Test
  void route_whenTheTripIsEmpty_shouldOmitTheShape() throws Exception {
    emptyRouteFromStadia();

    assertFalse(routeBody().hasNonNull("shape"));
  }

  @Test
  void valhallaRequest_shouldSerializeSnakeCaseKeys() throws Exception {
    ValhallaRequest request = routeWith("FASTBIKE", ", \"useHills\": 0.5, \"useRoads\": 0.75");

    JsonNode bicycle =
        new ObjectMapper()
            .readTree(new ObjectMapper().writeValueAsString(request))
            .path("costing_options")
            .path("bicycle");
    assertEquals(0.5, bicycle.path("use_hills").asDouble());
    assertEquals(0.75, bicycle.path("use_roads").asDouble());
  }
}
