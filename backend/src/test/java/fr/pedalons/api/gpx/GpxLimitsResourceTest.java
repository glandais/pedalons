package fr.pedalons.api.gpx;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.route.GpxLimits;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The GPX pipeline is bounded before it allocates (docs/LEDGER_*.md SEC-6): every HTTP route that
 * imports a track refuses an oversized file, a track longer than {@link
 * GpxLimits#MAX_TRACK_DISTANCE_METERS}, too many planner points and out-of-range coordinates.
 *
 * <p>Each long track here is a handful of points a hemisphere apart: before the fix, its 10 m
 * resampling allocated millions of points.
 */
@QuarkusTest
class GpxLimitsResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");

  private final List<File> tempFiles = new ArrayList<>();

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setDomainEnableGpxPlanner(domain, true);
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  @AfterEach
  void deleteTempFiles() {
    tempFiles.forEach(File::delete);
  }

  /** Three points, each segment about 19 900 km: far over the bound, a few hundred bytes. */
  private static List<GeoPoint> farApartPoints() {
    return List.of(new GeoPoint(0, 0), new GeoPoint(179, 0), new GeoPoint(0, 0));
  }

  private File longGpx() throws IOException {
    StringBuilder trkpts = new StringBuilder();
    for (GeoPoint p : farApartPoints()) {
      trkpts.append(
          "<trkpt lat=\"%s\" lon=\"%s\"><ele>0</ele></trkpt>".formatted(p.lat(), p.lng()));
    }
    String gpx =
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><name>Too long</name><trkseg>%s</trkseg></trk>
        </gpx>
        """
            .formatted(trkpts);
    File file = Files.createTempFile("long-", ".gpx").toFile();
    tempFiles.add(file);
    Files.writeString(file.toPath(), gpx);
    return file;
  }

  /** One byte over the bound: its content is never read. */
  private File oversizedGpx() throws IOException {
    File file = Files.createTempFile("oversized-", ".gpx").toFile();
    tempFiles.add(file);
    try (RandomAccessFile raf = new RandomAccessFile(file, "rw")) {
      raf.setLength(GpxLimits.MAX_GPX_SIZE_BYTES + 1);
    }
    return file;
  }

  /** Under the bound of one file, but two of them together go over the bound of a merge. */
  private File halfOversizedGpx() throws IOException {
    File file = Files.createTempFile("half-oversized-", ".gpx").toFile();
    tempFiles.add(file);
    try (RandomAccessFile raf = new RandomAccessFile(file, "rw")) {
      raf.setLength(GpxLimits.MAX_MERGE_TOTAL_BYTES / 2 + 1);
    }
    return file;
  }

  private String createPreview() {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(201)
        .extract()
        .path("id");
  }

  private static RouteRequest routeRequest(String name, List<GeoPoint> points) {
    return new RouteRequest(
        name, MediaDto.builder().build(), SurfaceType.ROAD, Visibility.PUBLIC, points);
  }

  private static String pointsJson(List<GeoPoint> points) {
    StringBuilder json = new StringBuilder("[");
    for (GeoPoint p : points) {
      if (json.length() > 1) {
        json.append(',');
      }
      json.append("{\"lng\":").append(p.lng()).append(",\"lat\":").append(p.lat()).append('}');
    }
    return json.append(']').toString();
  }

  // ==================== GPX tools ====================

  @Test
  void createPreview_withTooLongTrack_shouldReturn400() throws IOException {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", longGpx(), "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_TOO_LONG"));
  }

  @Test
  void createPreview_withOversizedFile_shouldReturn400() throws IOException {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", oversizedGpx(), "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(400)
        .body("code", equalTo("FILE_TOO_LARGE"));
  }

  @Test
  void importGpx_withTooLongTrack_shouldReturn400() throws IOException {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", longGpx(), "application/gpx+xml")
        .when()
        .post("/api/router/import-gpx")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_TOO_LONG"));
  }

  @Test
  void importGpx_withOversizedFile_shouldReturn400() throws IOException {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFile", oversizedGpx(), "application/gpx+xml")
        .when()
        .post("/api/router/import-gpx")
        .then()
        .statusCode(400)
        .body("code", equalTo("FILE_TOO_LARGE"));
  }

  @Test
  void mergePreviews_withOversizedFile_shouldReturn400() throws IOException {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFiles", EXAMPLE_GPX, "application/gpx+xml")
        .multiPart("gpxFiles", oversizedGpx(), "application/gpx+xml")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(400)
        .body("code", equalTo("FILE_TOO_LARGE"));
  }

  @Test
  void mergePreviews_withFilesOverTheCombinedBound_shouldReturn400() throws IOException {
    // Each file passes the bound of a single upload; together they would feed the pipeline more.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFiles", halfOversizedGpx(), "application/gpx+xml")
        .multiPart("gpxFiles", halfOversizedGpx(), "application/gpx+xml")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(400)
        .body("code", equalTo("FILE_TOO_LARGE"));
  }

  @Test
  void mergePreviews_withTooLongTrack_shouldReturn400() throws IOException {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("gpxFiles", EXAMPLE_GPX, "application/gpx+xml")
        .multiPart("gpxFiles", longGpx(), "application/gpx+xml")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_TOO_LONG"));
  }

  @Test
  void createPreviewFromPoints_withTooLongTrack_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body("{\"name\":\"Too long\",\"points\":" + pointsJson(farApartPoints()) + "}")
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_TOO_LONG"));
  }

  @Test
  void createPreviewFromPoints_withOutOfRangeLatitude_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(
            "{\"name\":\"Off the"
                + " map\",\"points\":[{\"lng\":4.8,\"lat\":45.7},{\"lng\":4.8,\"lat\":91}]}")
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(400)
        .body("code", equalTo("VALIDATION"));
  }

  @Test
  void createPreviewFromPoints_withTooManyPoints_shouldReturn400() {
    List<GeoPoint> points = new ArrayList<>();
    for (int i = 0; i <= GpxLimits.MAX_PLANNER_POINTS; i++) {
      points.add(new GeoPoint(4.8, 45.7));
    }
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body("{\"name\":\"Too many\",\"points\":" + pointsJson(points) + "}")
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(400)
        .body("code", equalTo("VALIDATION"));
  }

  /** The PUT did not apply the size bound before SEC-6. */
  @Test
  void updatePreview_withOversizedFile_shouldReturn400() throws IOException {
    String previewId = createPreview();

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("preview", "{\"name\":\"Oversized\"}", MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", oversizedGpx(), "application/gpx+xml")
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(400)
        .body("code", equalTo("FILE_TOO_LARGE"));
  }

  @Test
  void updatePreview_withTooLongPoints_shouldReturn400() {
    String previewId = createPreview();

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(
            "preview",
            "{\"name\":\"Too long\",\"points\":" + pointsJson(farApartPoints()) + "}",
            MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + previewId)
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_TOO_LONG"));
  }

  // ==================== Team routes ====================

  @Test
  void createRoute_withOversizedFile_shouldReturn400() throws IOException {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", routeRequest("Oversized", null), MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", oversizedGpx(), "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(400)
        .body("code", equalTo("FILE_TOO_LARGE"));
  }

  @Test
  void createRoute_withTooLongPoints_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", routeRequest("Too long", farApartPoints()), MediaType.APPLICATION_JSON)
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_TOO_LONG"));
  }

  /**
   * Refused before the route is touched: the error keeps its code (the update used to turn every
   * failure into GPX_FAILURE) and the route keeps its track.
   */
  @Test
  void updateRoute_withTooLongTrack_shouldReturn400AndKeepTheRoute() throws IOException {
    Route existing = dataService.createRoute(team1, user1, "Existing Route", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", routeRequest("Renamed Route", null), MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", longGpx(), "application/gpx+xml")
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + existing.getSlug())
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_TOO_LONG"));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + existing.getSlug())
        .then()
        .statusCode(200)
        .body("name", equalTo("Existing Route"));
  }

  @Test
  void updateRoute_withOversizedFile_shouldReturn400() throws IOException {
    Route existing = dataService.createRoute(team1, user1, "Existing Route", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", routeRequest("Existing Route", null), MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", oversizedGpx(), "application/gpx+xml")
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + existing.getSlug())
        .then()
        .statusCode(400)
        .body("code", equalTo("FILE_TOO_LARGE"));
  }

  @Test
  void updateRoute_withOutOfRangeLongitude_shouldReturn400() {
    Route existing = dataService.createRoute(team1, user1, "Existing Route", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(
            "route",
            routeRequest(
                "Existing Route", List.of(new GeoPoint(4.8, 45.7), new GeoPoint(181, 45.7))),
            MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + existing.getSlug())
        .then()
        .statusCode(400)
        .body("code", equalTo("VALIDATION"));
  }
}
