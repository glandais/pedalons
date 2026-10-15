package fr.pedalons.api.gpx;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
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
}
