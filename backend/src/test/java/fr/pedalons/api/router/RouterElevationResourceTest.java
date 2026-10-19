package fr.pedalons.api.router;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.valhalla.StadiaMapsClient;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.route.planner.PolylineCodec;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.mockito.InjectSpy;
import io.restassured.response.ValidatableResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * {@code POST /api/router/elevation} (docs/LEDGER_*.md WEB-100, B1b): the relief of straight lines
 * with the FAST elevations, who may call it, its bounds, and that the routing provider is never
 * called.
 */
@QuarkusTest
class RouterElevationResourceTest extends AbstractResourceTest {

  @InjectMock @RestClient StadiaMapsClient stadiaMapsClient;

  @InjectSpy GpxPipeline pipeline;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setDomainEnableGpxPlanner(domain, true);
    dataService.setTeamEnableRoutePlanner(team1, true);
    Mockito.reset(stadiaMapsClient, pipeline);
  }

  // ------------------------------------------------------------------ fixtures

  /** A line heading east along the equator, {@code lngSpan} degrees long (1 degree ~ 111 km). */
  private static String line(double lng, double lngSpan) {
    return "{\"from\": {\"lng\": %s, \"lat\": 0.0}, \"to\": {\"lng\": %s, \"lat\": 0.0}}"
        .formatted(lng, lng + lngSpan);
  }

  /** About one kilometre, with a real distance between its ends. */
  private static String km() {
    return line(4.80, 0.009);
  }

  private static String body(String teamSlug, List<String> lines) {
    String team = teamSlug == null ? "" : "\"teamSlug\": \"" + teamSlug + "\", ";
    return "{" + team + "\"lines\": [" + String.join(",", lines) + "]}";
  }

  private ValidatableResponse post(String user, String json) {
    var spec = given();
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.contentType("application/json")
        .body(json)
        .when()
        .post("/api/router/elevation")
        .then();
  }

  private ValidatableResponse elevation(String user, String teamSlug, String... lines) {
    return post(user, body(teamSlug, List.of(lines)));
  }

  // ------------------------------------------------------------------ the answer

  @Test
  void lineElevation_shape_oneTrackPerLine_inOrder() {
    var tracks =
        elevation(USER1, null, km(), line(4.90, 0.018))
            .statusCode(200)
            .body("elevationFallback", equalTo(false))
            .body("lines.size()", equalTo(2))
            .extract()
            .<List<Map<String, Object>>>path("lines");

    double[] distances = {1000.0, 2000.0};
    double[] starts = {4.80, 4.90};
    double[] ends = {4.809, 4.918};
    for (int k = 0; k < 2; k++) {
      var t = tracks.get(k);
      double[][] coords =
          PolylineCodec.decode2((String) t.get("line"), GpxLimits.MAX_PLANNER_POINTS);
      assertTrue(coords.length >= 2);
      assertEquals(starts[k], coords[0][0], 1e-5);
      assertEquals(0.0, coords[0][1], 1e-5);
      assertEquals(ends[k], coords[coords.length - 1][0], 1e-5);
      double[] ele = PolylineCodec.decode1((String) t.get("ele"), coords.length);
      double[] climb = PolylineCodec.decode1((String) t.get("climb"), coords.length);
      assertEquals(coords.length, ele.length);
      assertEquals(coords.length, climb.length);
      assertEquals(0.0, climb[0], 0.05);
      for (int i = 1; i < climb.length; i++) {
        assertTrue(climb[i] >= climb[i - 1]);
      }
      assertEquals(((Number) t.get("ascend")).doubleValue(), climb[climb.length - 1], 0.05);
      assertEquals(distances[k], ((Number) t.get("dist")).doubleValue(), distances[k] * 0.02);
    }
    verifyNoInteractions(stadiaMapsClient);
  }

  @Test
  void lineElevation_degenerateLine_answersTwoPoints() {
    var tracks =
        elevation(USER1, null, line(4.8, 0.0))
            .statusCode(200)
            .body("lines.size()", equalTo(1))
            .extract()
            .<List<Map<String, Object>>>path("lines");
    double[][] coords =
        PolylineCodec.decode2((String) tracks.getFirst().get("line"), GpxLimits.MAX_PLANNER_POINTS);
    assertTrue(coords.length >= 2);
    assertEquals(4.8, coords[0][0], 1e-5);
    assertEquals(4.8, coords[coords.length - 1][0], 1e-5);
  }

  // ------------------------------------------------------------------ validation and bounds

  @Test
  void lineElevation_emptyList_is400() {
    post(USER1, body(null, List.of())).statusCode(400);
  }

  @Test
  void lineElevation_fiftyOneLines_is400() {
    List<String> lines = new ArrayList<>();
    for (int i = 0; i < GpxLimits.MAX_STRAIGHT_LINES + 1; i++) {
      lines.add(km());
    }
    post(USER1, body(null, lines)).statusCode(400);
  }

  @Test
  void lineElevation_missingEnd_is400() {
    post(USER1, body(null, List.of("{\"to\": {\"lng\": 2, \"lat\": 48}}"))).statusCode(400);
    post(USER1, body(null, List.of("{\"from\": {\"lng\": 2, \"lat\": 48}}"))).statusCode(400);
  }

  @Test
  void lineElevation_emptyBody_is400() {
    post(USER1, "").statusCode(400);
  }

  @Test
  void lineElevation_fiftyLines_isAccepted() {
    List<String> lines = new ArrayList<>();
    for (int i = 0; i < GpxLimits.MAX_STRAIGHT_LINES; i++) {
      lines.add(line(4.0 + i * 0.01, 0.002));
    }
    post(USER1, body(null, lines)).statusCode(200).body("lines.size()", equalTo(50));
  }

  @Test
  void lineElevation_coordinatesOutOfBounds_is400() {
    post(
            USER1,
            body(
                null,
                List.of(
                    "{\"from\": {\"lng\": 181, \"lat\": 0}, \"to\": {\"lng\": 4, \"lat\": 0}}")))
        .statusCode(400);
    post(
            USER1,
            body(
                null,
                List.of(
                    "{\"from\": {\"lng\": 4, \"lat\": 0}, \"to\": {\"lng\": 4, \"lat\": -91}}")))
        .statusCode(400);
  }

  @Test
  void lineElevation_over100km_isTooLong_withoutReadingElevations() {
    // 0.91 degree of longitude on the equator is ~101 km.
    elevation(USER1, null, line(4.0, 0.91))
        .statusCode(400)
        .body("code", equalTo("ROUTING_SEGMENT_TOO_LONG"));
    verify(pipeline, never()).processWithClimb(any(), any(), any());
  }

  @Test
  void lineElevation_threeTimes70km_isTooLong_withoutReadingElevations() {
    // Each line is ~70 km, together ~210 km.
    elevation(USER1, null, line(4.0, 0.63), line(5.0, 0.63), line(6.0, 0.63))
        .statusCode(400)
        .body("code", equalTo("ROUTING_SEGMENT_TOO_LONG"));
    verify(pipeline, never()).processWithClimb(any(), any(), any());
  }

  // ------------------------------------------------------------------ who may call it

  @Test
  void lineElevation_withoutAuth_is401() {
    post(null, body(null, List.of(km()))).statusCode(401);
  }

  @Test
  void lineElevation_withTeam_asMember_isAllowed() {
    elevation(USER1, team1Slug, km()).statusCode(200);
  }

  @Test
  void lineElevation_withTeam_asNonMember_is403() {
    elevation(USER4, team1Slug, km()).statusCode(403);
  }

  @Test
  void lineElevation_withTeam_whenTeamPlannerDisabled_isRoutePlannerDisabled() {
    dataService.setTeamEnableRoutePlanner(team1, false);
    elevation(USER1, team1Slug, km())
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void lineElevation_withoutTeam_whenDomainPlannerDisabled_isRoutePlannerDisabled() {
    dataService.setDomainEnableGpxPlanner(domain, false);
    elevation(USER1, null, km()).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void lineElevation_withTeamOfAnotherDomain_is404() {
    var other = dataService.createDomain("other.example.com", "Other", "https://other.example.com");
    var owner = dataService.createUser(other, "owner@other.example.com", "Owner");
    var otherTeam =
        dataService.createTeam(other, owner, "Other team", "other-team", Visibility.PUBLIC);
    dataService.setTeamEnableRoutePlanner(otherTeam, true);

    elevation(USER1, "other-team", km()).statusCode(404);
  }
}
