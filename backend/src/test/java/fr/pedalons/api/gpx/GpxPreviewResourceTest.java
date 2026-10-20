package fr.pedalons.api.gpx;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class GpxPreviewResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  /** Uploads example.gpx as USER1 and returns the resulting public id. */
  private String createPreview(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(201)
        .extract()
        .path("id");
  }

  // ==================== Create ====================

  @Test
  void createPreview_shouldAnalyseTheFile() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("name", notNullValue())
        .body("distance", greaterThan(0.0f))
        .body("owned", equalTo(true))
        .body("tracks", not(empty()));
  }

  // ==================== Planner toggle (domain-level) ====================

  private static final String FROM_POINTS_BODY =
      """
      {"name": "Drawn preview", "points": [{"lng": 4.8357, "lat": 45.7640},
       {"lng": 4.8500, "lat": 45.7700}]}
      """;

  @Test
  void createPreviewFromPoints_whenPlannerDisabled_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(FROM_POINTS_BODY)
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void createPreviewFromPoints_whenPlannerEnabled_shouldSucceed() {
    dataService.setDomainEnableGpxPlanner(domain, true);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(FROM_POINTS_BODY)
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(201)
        .body("name", equalTo("Drawn preview"));
  }

  /** The toggle closes drawing only: uploading a file stays open. */
  @Test
  void createPreview_fromFile_whenPlannerDisabled_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(201);
  }

  @Test
  void createPreview_withoutAuth_shouldReturn401() {
    given()
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(401);
  }

  @Test
  void createPreview_withoutFile_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("unused", "x")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(400);
  }

  @Test
  void createPreview_withInvalidGpx_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", new File("src/test/resources/invalid.gpx"), "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(400);
  }

  // ==================== Merge (API-112) ====================

  private static final File MERGE_PART_A = new File("src/test/resources/merge_part_a.gpx");
  private static final File MERGE_PART_B = new File("src/test/resources/merge_part_b.gpx");

  @Test
  void mergePreviews_shouldChainTheTracksIntoOne() {
    // Part B is the second half of the ride recorded backwards: the merge rides it reversed, so
    // the result is one track with no gap, about 7.5 km along latitude 47.5.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFiles", MERGE_PART_B, "application/gpx+xml")
        .multiPart("gpxFiles", MERGE_PART_A, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("name", equalTo("Retour + Aller"))
        .body("owned", equalTo(true))
        .body("tracks", hasSize(1))
        .body("distance", allOf(greaterThan(7000.0f), lessThan(8500.0f)));
  }

  @Test
  void mergePreviews_shouldBeListedAndReadable() {
    String id =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("gpxFiles", MERGE_PART_A, "application/gpx+xml")
            .multiPart("gpxFiles", EXAMPLE_GPX, "application/gpx+xml")
            .when()
            .post("/api/gpx-previews/merge")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    given().when().get("/api/gpx-previews/" + id).then().statusCode(200).body("id", equalTo(id));
  }

  @Test
  void mergePreviews_withOneFile_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFiles", MERGE_PART_A, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_MERGE_FILE_COUNT"));
  }

  @Test
  void mergePreviews_withElevenFiles_shouldReturn400() {
    var request = given().auth().oauth2(getAccessToken(USER1));
    for (int i = 0; i < 11; i++) {
      request = request.multiPart("gpxFiles", MERGE_PART_A, "application/gpx+xml");
    }
    request
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_MERGE_FILE_COUNT"));
  }

  @Test
  void mergePreviews_withoutFile_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("unused", "x")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(400)
        .body("code", equalTo("FILE_REQUIRED"));
  }

  @Test
  void mergePreviews_withAnInvalidFile_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFiles", MERGE_PART_A, "application/gpx+xml")
        .multiPart("gpxFiles", new File("src/test/resources/invalid.gpx"), "application/gpx+xml")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_FAILURE"));
  }

  @Test
  void mergePreviews_withAFileWithoutPoints_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFiles", MERGE_PART_A, "application/gpx+xml")
        .multiPart("gpxFiles", new File("src/test/resources/empty.gpx"), "application/gpx+xml")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_EMPTY"));
  }

  @Test
  void mergePreviews_withoutAuth_shouldReturn401() {
    given()
        .multiPart("gpxFiles", MERGE_PART_A, "application/gpx+xml")
        .multiPart("gpxFiles", MERGE_PART_B, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(401);
  }

  // ==================== Read ====================

  @Test
  void getPreview_shouldReturnItToItsCreator() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("id", equalTo(previewId))
        .body("owned", equalTo(true))
        .body("tracks[0].line", notNullValue());
  }

  @Test
  void getPreview_shouldBeReadableByAnotherAuthenticatedUser() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("owned", equalTo(false));
  }

  @Test
  void getPreview_withoutAuth_shouldSucceed() {
    String previewId = createPreview(USER1);

    given()
        .when()
        .get("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("id", equalTo(previewId))
        .body("owned", equalTo(false))
        .body("tracks", not(empty()));
  }

  @Test
  void getPreview_withUnknownId_shouldReturn404() {
    given().when().get("/api/gpx-previews/" + UUID.randomUUID()).then().statusCode(404);
  }

  // ==================== Delete ====================

  @Test
  void deletePreview_asCreator_shouldSucceed() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(204);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(404);
  }

  @Test
  void deletePreview_asNonCreator_shouldReturn403() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .delete("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(403);
  }

  // ==================== Update ====================

  @Test
  void updatePreview_asCreator_shouldRename() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("preview", "{\"name\":\"Renamed preview\"}", MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("id", equalTo(previewId))
        .body("name", equalTo("Renamed preview"))
        .body("owned", equalTo(true))
        .body("tracks", not(empty()));
  }

  @Test
  void updatePreview_withNewGpx_shouldReplaceTrackAndRecomputeMetrics() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("preview", "{\"name\":\"Replaced track\"}", MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("name", equalTo("Replaced track"))
        .body("distance", greaterThan(0.0f))
        .body("tracks", not(empty()));
  }

  @Test
  void updatePreview_asNonCreator_shouldReturn403() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .multiPart("preview", "{\"name\":\"Hijacked\"}", MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(403);
  }

  @Test
  void updatePreview_withoutAuth_shouldReturn401() {
    String previewId = createPreview(USER1);

    given()
        .multiPart("preview", "{\"name\":\"Anonymous\"}", MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(401);
  }

  @Test
  void updatePreview_withUnknownId_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("preview", "{\"name\":\"Nowhere\"}", MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + UUID.randomUUID())
        .then()
        .statusCode(404);
  }

  @Test
  void updatePreview_withTooShortName_shouldReturn400() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("preview", "{\"name\":\"ab\"}", MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(400);
  }

  // ==================== Save as route ====================

  @Test
  void createRouteFromPreview_shouldCreateARouteOnTheTeam() {
    String previewId = createPreview(USER1);
    RouteRequest request =
        new RouteRequest(
            "From preview",
            MediaDto.builder().markdown("Saved from the GPX tools").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(request)
        .when()
        .post("/api/gpx-previews/" + previewId + "/routes/" + team1Slug)
        .then()
        .statusCode(201)
        .body("name", equalTo("From preview"))
        .body("distance", greaterThan(0.0f));
  }

  @Test
  void createRouteFromPreview_asNonMember_shouldReturn403() {
    String previewId = createPreview(USER1);
    RouteRequest request =
        new RouteRequest(
            "From preview", MediaDto.builder().build(), SurfaceType.ROAD, Visibility.PUBLIC, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType(MediaType.APPLICATION_JSON)
        .body(request)
        .when()
        .post("/api/gpx-previews/" + previewId + "/routes/" + team1Slug)
        .then()
        .statusCode(403);
  }

  // ==================== Drawn previews and the team planner (A10) ====================

  private static RouteRequest routeRequest() {
    return new RouteRequest(
        "From drawn preview",
        MediaDto.builder().build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null);
  }

  private String createDrawnPreview(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(FROM_POINTS_BODY)
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(201)
        .body("drawn", equalTo(true))
        .extract()
        .path("id");
  }

  private io.restassured.response.ValidatableResponse saveAsRoute(String previewId, String user) {
    return saveAsRoute(previewId, user, team1Slug);
  }

  private io.restassured.response.ValidatableResponse saveAsRoute(
      String previewId, String user, String teamSlug) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(routeRequest())
        .when()
        .post("/api/gpx-previews/" + previewId + "/routes/" + teamSlug)
        .then();
  }

  @Test
  void createPreview_fromFile_shouldNotBeDrawn() {
    String id = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gpx-previews/" + id)
        .then()
        .statusCode(200)
        .body("drawn", equalTo(false));
  }

  @Test
  void createRouteFromPreview_drawn_whenTeamPlannerDisabled_shouldReturn400() {
    dataService.setDomainEnableGpxPlanner(domain, true);
    String previewId = createDrawnPreview(USER1);

    saveAsRoute(previewId, USER1).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void createRouteFromPreview_drawn_whenTeamPlannerEnabled_shouldSucceed() {
    dataService.setDomainEnableGpxPlanner(domain, true);
    dataService.setTeamEnableRoutePlanner(team1, true);
    String previewId = createDrawnPreview(USER1);

    saveAsRoute(previewId, USER1).statusCode(201).body("name", equalTo("From drawn preview"));
  }

  @Test
  void createRouteFromPreview_drawn_asNonMember_shouldReturn403NotRevealTheFlag() {
    dataService.setDomainEnableGpxPlanner(domain, true);
    String previewId = createDrawnPreview(USER1);

    saveAsRoute(previewId, USER4).statusCode(403);
  }

  @Test
  void createRouteFromPreview_drawn_withTeamOfAnotherDomain_shouldReturn404() {
    dataService.setDomainEnableGpxPlanner(domain, true);
    var other = dataService.createDomain("other.example.com", "Other", "https://other.example.com");
    var owner = dataService.createUser(other, "owner@other.example.com", "Owner");
    var otherTeam =
        dataService.createTeam(other, owner, "Other team", "other-team", Visibility.PUBLIC);
    dataService.setTeamEnableRoutePlanner(otherTeam, true);
    String previewId = createDrawnPreview(USER1);

    saveAsRoute(previewId, USER1, "other-team").statusCode(404);
  }

  /** Only the drawing is governed: an imported file becomes a route of a team without planner. */
  @Test
  void createRouteFromPreview_imported_whenTeamPlannerDisabled_shouldSucceed() {
    saveAsRoute(createPreview(USER1), USER1).statusCode(201);
  }

  @Test
  void updatePreview_withFile_afterDrawing_shouldResetDrawn() {
    dataService.setDomainEnableGpxPlanner(domain, true);
    String previewId = createDrawnPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("preview", "{\"name\":\"Imported now\"}", MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("drawn", equalTo(false));

    dataService.setTeamEnableRoutePlanner(team1, false);
    saveAsRoute(previewId, USER1).statusCode(201);
  }

  @Test
  void updatePreview_withPoints_shouldSetDrawn() {
    dataService.setDomainEnableGpxPlanner(domain, true);
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(
            "preview",
            "{\"name\":\"Drawn now\",\"points\":[{\"lng\":4.8357,\"lat\":45.7640},"
                + "{\"lng\":4.85,\"lat\":45.77}]}",
            MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("drawn", equalTo(true));

    saveAsRoute(previewId, USER1).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  // ==================== Send to GPS service ====================

  @Test
  void uploadToGpsService_withoutConnection_shouldReturn400() {
    String previewId = createPreview(USER1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        // No body, but the class-level @Consumes rejects RestAssured's default text/plain.
        .contentType(MediaType.APPLICATION_JSON)
        .when()
        .post("/api/gpx-previews/" + previewId + "/gps/GARMIN")
        .then()
        .statusCode(400);
  }

  // ==================== Waypoints (docs/LEDGER_*.md WEB-100, C3c, API-134) ====================

  private static final File WAYPOINTS_GPX = new File("src/test/resources/waypoints.gpx");

  @Inject GpxPreviewRepository gpxPreviewRepository;

  private String createPreviewFrom(File gpx) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", gpx, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(201)
        .extract()
        .path("id");
  }

  private java.util.List<java.util.Map<String, Object>> previewWaypoints(String previewId) {
    return given()
        .when()
        .get("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .extract()
        .path("waypoints");
  }

  private java.util.List<java.util.Map<String, Object>> routeWaypoints(String slug) {
    return given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(200)
        .extract()
        .path("waypoints");
  }

  private static RouteRequest routeRequestWithWaypoints(
      java.util.List<fr.pedalons.dto.routes.request.WaypointRequest> waypoints) {
    return new RouteRequest(
        "Promoted",
        MediaDto.builder().build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null,
        null,
        null,
        waypoints);
  }

  private static fr.pedalons.dto.routes.request.WaypointRequest authorPoint(
      String name, fr.pedalons.enums.WaypointType type, double lat, double lng) {
    return new fr.pedalons.dto.routes.request.WaypointRequest(
        null, new fr.pedalons.common.GeoPoint(lng, lat), type, name, null, null, null);
  }

  /** Red on the code before C3c: original.gpx carries no <wpt>, and the promotion read it. */
  @Test
  void promotePreview_keepsItsWaypoints() {
    String previewId = createPreviewFrom(WAYPOINTS_GPX);
    java.util.List<java.util.Map<String, Object>> onPreview = previewWaypoints(previewId);
    org.junit.jupiter.api.Assertions.assertEquals(3, onPreview.size());

    String slug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType(MediaType.APPLICATION_JSON)
            .body(routeRequest())
            .when()
            .post("/api/gpx-previews/" + previewId + "/routes/" + team1Slug)
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    java.util.List<java.util.Map<String, Object>> waypoints = routeWaypoints(slug);

    org.junit.jupiter.api.Assertions.assertEquals(3, waypoints.size());
    org.junit.jupiter.api.Assertions.assertEquals(
        java.util.Set.of("Source", "Café du coin", "Mystère"),
        waypoints.stream()
            .map(w -> (String) w.get("name"))
            .collect(java.util.stream.Collectors.toSet()));
    org.junit.jupiter.api.Assertions.assertEquals(
        "WATER",
        waypoints.stream()
            .filter(w -> "Source".equals(w.get("name")))
            .findFirst()
            .orElseThrow()
            .get("type"));
    org.junit.jupiter.api.Assertions.assertTrue(
        waypoints.stream().allMatch(w -> "IMPORTED".equals(w.get("origin"))));
    org.junit.jupiter.api.Assertions.assertTrue(
        waypoints.stream().allMatch(w -> w.get("distance") != null), "placed on the new route");
  }

  @Test
  void promotePreview_keepsAuthorPoints() {
    String previewId = createPreviewFrom(WAYPOINTS_GPX);
    java.util.List<fr.pedalons.dto.routes.request.WaypointRequest> list =
        new java.util.ArrayList<>();
    list.add(authorPoint("Sommet", fr.pedalons.enums.WaypointType.SUMMIT, 47.2024271, -1.5456685));
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(
            "preview",
            new fr.pedalons.dto.gpx.request.GpxPreviewUpdateRequest(
                "Renamed preview", null, null, list),
            MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("waypoints", hasSize(1))
        .body("waypoints[0].origin", equalTo("AUTHOR"));

    String slug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType(MediaType.APPLICATION_JSON)
            .body(routeRequest())
            .when()
            .post("/api/gpx-previews/" + previewId + "/routes/" + team1Slug)
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    java.util.List<java.util.Map<String, Object>> waypoints = routeWaypoints(slug);
    org.junit.jupiter.api.Assertions.assertEquals(1, waypoints.size());
    org.junit.jupiter.api.Assertions.assertEquals("Sommet", waypoints.getFirst().get("name"));
    org.junit.jupiter.api.Assertions.assertEquals("SUMMIT", waypoints.getFirst().get("type"));
    org.junit.jupiter.api.Assertions.assertEquals("AUTHOR", waypoints.getFirst().get("origin"));
  }

  @Test
  void promotePreview_requestListWins() {
    String previewId = createPreviewFrom(WAYPOINTS_GPX);

    String slug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType(MediaType.APPLICATION_JSON)
            .body(
                routeRequestWithWaypoints(
                    java.util.List.of(
                        authorPoint(
                            "Seul", fr.pedalons.enums.WaypointType.WATER, 47.2024271, -1.5456685))))
            .when()
            .post("/api/gpx-previews/" + previewId + "/routes/" + team1Slug)
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    java.util.List<java.util.Map<String, Object>> waypoints = routeWaypoints(slug);
    org.junit.jupiter.api.Assertions.assertEquals(1, waypoints.size());
    org.junit.jupiter.api.Assertions.assertEquals("Seul", waypoints.getFirst().get("name"));
  }

  @Test
  void updatePreview_pointsOnly_keepsRevision_rewritesFilteredAndFit() {
    String previewId = createPreviewFrom(WAYPOINTS_GPX);
    UUID publicId = UUID.fromString(previewId);
    Long revisionBefore =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    gpxPreviewRepository
                        .findByPublicId(domain.getId(), publicId)
                        .orElseThrow()
                        .getFilesRevision());
    byte[] gpxBefore =
        given()
            .when()
            .get("/api/gpx-previews/" + previewId + "/gpx")
            .then()
            .statusCode(200)
            .extract()
            .asByteArray();
    java.util.List<fr.pedalons.dto.routes.request.WaypointRequest> list =
        new java.util.ArrayList<>();
    list.add(
        authorPoint("Atelier", fr.pedalons.enums.WaypointType.BIKE_SHOP, 47.2024271, -1.5456685));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(
            "preview",
            new fr.pedalons.dto.gpx.request.GpxPreviewUpdateRequest("Same track", null, null, list),
            MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(200)
        .body("waypoints", hasSize(1));

    Long revisionAfter =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    gpxPreviewRepository
                        .findByPublicId(domain.getId(), publicId)
                        .orElseThrow()
                        .getFilesRevision());
    org.junit.jupiter.api.Assertions.assertEquals(
        revisionBefore, revisionAfter, "the track did not change: no new revision");
    String gpxAfter =
        given()
            .when()
            .get("/api/gpx-previews/" + previewId + "/gpx")
            .then()
            .statusCode(200)
            .extract()
            .asString();
    org.junit.jupiter.api.Assertions.assertTrue(gpxAfter.contains("Atelier"));
    org.junit.jupiter.api.Assertions.assertFalse(
        new String(gpxBefore, java.nio.charset.StandardCharsets.UTF_8).contains("Atelier"));
    org.junit.jupiter.api.Assertions.assertTrue(gpxAfter.contains("Car Repair"));
    byte[] fit =
        given()
            .when()
            .get("/api/gpx-previews/" + previewId + "/fit")
            .then()
            .statusCode(200)
            .extract()
            .asByteArray();
    org.junit.jupiter.api.Assertions.assertEquals(
        1,
        new com.garmin.fit.FitDecoder(fit)
            .decode(new com.garmin.fit.DecodeOptions())
            .getMessages()
            .getCoursePointMesgs()
            .size());
  }

  @Test
  void fromPoints_withWaypoints() {
    dataService.setDomainEnableGpxPlanner(domain, true);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(
            """
            {"name": "Drawn with points",
             "points": [{"lng": 4.8357, "lat": 45.7640}, {"lng": 4.8500, "lat": 45.7700}],
             "waypoints": [{"position": {"lng": 4.8400, "lat": 45.7655}, "type": "CAFE",
                            "name": "Café du départ"}]}
            """)
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(201)
        .body("waypoints", hasSize(1))
        .body("waypoints[0].name", equalTo("Café du départ"))
        .body("waypoints[0].type", equalTo("CAFE"))
        .body("waypoints[0].origin", equalTo("AUTHOR"));
  }
}
