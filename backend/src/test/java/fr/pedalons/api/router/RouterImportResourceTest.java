package fr.pedalons.api.router;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.gpx.FakeElevationProducer;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.route.planner.PolylineCodec;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import io.restassured.specification.RequestSpecification;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;

/**
 * {@code POST /api/router/import-gpx} (docs/LEDGER_*.md WEB-100, C4b): a GPX file processed with
 * the FAST elevations for the route editor, who may call it, its limits, and that nothing is stored.
 */
@QuarkusTest
class RouterImportResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");

  @Inject EntityManager em;
  @Inject fr.pedalons.service.route.GpxProcessingService gpxProcessingService;
  @Inject S3Client s3Client;

  @ConfigProperty(name = "storage.bucket", defaultValue = "pedalons")
  String bucket;

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

  // ------------------------------------------------------------------ fixtures

  /** A track of {@code points} points heading east from {@code lat}, a point every ~70 m. */
  private static String track(String name, double lat, int points) {
    StringBuilder pts = new StringBuilder();
    for (int i = 0; i < points; i++) {
      pts.append(
          "<trkpt lat=\"%s\" lon=\"%s\"><ele>%s</ele></trkpt>"
              .formatted(lat, -1.55 + i * 0.001, 10 + i));
    }
    String n = name == null ? "" : "<name>" + name + "</name>";
    return "<trk>" + n + "<trkseg>" + pts + "</trkseg></trk>";
  }

  private File gpx(String metadataName, String body) throws IOException {
    String meta =
        metadataName == null ? "" : "<metadata><name>" + metadataName + "</name></metadata>";
    String xml =
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">%s%s</gpx>
        """
            .formatted(meta, body);
    return write(xml);
  }

  private File write(String content) throws IOException {
    File file = Files.createTempFile("import-", ".gpx").toFile();
    tempFiles.add(file);
    Files.writeString(file.toPath(), content, StandardCharsets.UTF_8);
    return file;
  }

  private static String waypoints(int count) {
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < count; i++) {
      sb.append("<wpt lat=\"47.2\" lon=\"-1.55\"><name>w%d</name></wpt>".formatted(i));
    }
    return sb.toString();
  }

  private RequestSpecification as(String user) {
    return given().auth().oauth2(getAccessToken(user));
  }

  private ValidatableResponse importAs(String user, File file, String teamSlug) {
    return post(as(user).multiPart("gpxFile", file, "application/gpx+xml"), teamSlug);
  }

  private ValidatableResponse post(RequestSpecification spec, String teamSlug) {
    if (teamSlug != null) {
      spec = spec.multiPart("teamSlug", teamSlug);
    }
    return spec.when().post("/api/router/import-gpx").then();
  }

  private ValidatableResponse importFile(File file) {
    return post(as(USER1).multiPart("gpxFile", file, "application/gpx+xml"), null);
  }

  private ValidatableResponse importNamed(File file, String fileName) throws IOException {
    return post(
        as(USER1)
            .multiPart(
                "gpxFile", fileName, Files.readAllBytes(file.toPath()), "application/gpx+xml"),
        null);
  }

  private long count(String table) {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                ((Number) em.createNativeQuery("select count(*) from " + table).getSingleResult())
                    .longValue());
  }

  private long storedObjects() {
    long n = 0;
    for (var o :
        s3Client
            .listObjectsV2Paginator(ListObjectsV2Request.builder().bucket(bucket).build())
            .contents()) {
      assertNotNull(o.key());
      n++;
    }
    return n;
  }

  // ------------------------------------------------------------------ the answer

  @Test
  void importGpx_shape_andFastElevations() throws IOException {
    var response =
        importFile(EXAMPLE_GPX)
            .statusCode(200)
            .body("name", equalTo("RR #254 Court"))
            .body("waypointCount", equalTo(0))
            .body("elevationFallback", equalTo(false))
            .extract();

    List<java.util.Map<String, Object>> tracks = response.path("tracks");
    assertEquals(1, tracks.size());
    var t = tracks.getFirst();
    String line = (String) t.get("line");
    String ele = (String) t.get("ele");
    String climb = (String) t.get("climb");
    double[][] coords = PolylineCodec.decode2(line, GpxLimits.MAX_PLANNER_POINTS);
    assertTrue(coords.length >= 2);
    double[] elevations = PolylineCodec.decode1(ele, coords.length);
    double[] climbs = PolylineCodec.decode1(climb, coords.length);
    for (double e : elevations) {
      assertEquals(FakeElevationProducer.FAST_ELEVATION, e, 1.0);
    }
    assertEquals(0.0, climbs[0], 0.05);
    for (int i = 1; i < climbs.length; i++) {
      assertTrue(climbs[i] >= climbs[i - 1]);
    }
    assertTrue(((Number) t.get("dist")).doubleValue() > 1000);
    assertEquals(((Number) t.get("ascend")).doubleValue(), climbs[climbs.length - 1], 0.05);
  }

  /** docs/LEDGER_*.md API-147, phase C: each track comes with its raw, sanitized 2D track. */
  @Test
  void importGpx_returnsTheRawTrackOfTheFile() throws IOException {
    List<java.util.Map<String, Object>> tracks =
        importFile(EXAMPLE_GPX).statusCode(200).extract().path("tracks");
    var t = tracks.getFirst();
    double[][] line = PolylineCodec.decode2((String) t.get("line"), GpxLimits.MAX_PLANNER_POINTS);
    double[][] shape =
        PolylineCodec.decode2((String) t.get("shape"), GpxLimits.MAX_PLANNER_SHAPE_POINTS);
    io.github.glandais.engine.path.Path raw =
        gpxProcessingService
            .rawTracks(gpxProcessingService.parseGpx(EXAMPLE_GPX.toPath()))
            .paths()
            .getFirst();
    assertEquals(raw.getSize(), shape.length, "every sanitized point of the file");
    assertTrue(shape.length > line.length);
    assertEquals(raw.longitudeDeg(0), shape[0][0], 1e-6);
    assertEquals(raw.latitudeDeg(0), shape[0][1], 1e-6);
    int last = raw.getSize() - 1;
    assertEquals(raw.longitudeDeg(last), shape[last][0], 1e-6);
    assertEquals(raw.latitudeDeg(last), shape[last][1], 1e-6);
  }

  @Test
  void importGpx_name_metadataThenTrackThenFileName() throws IOException {
    importFile(gpx("From metadata", track("Track name", 47.2, 30)))
        .statusCode(200)
        .body("name", equalTo("From metadata"));
    importFile(gpx(null, track("Track name", 47.2, 30)))
        .statusCode(200)
        .body("name", equalTo("Track name"));
    importNamed(gpx(null, track(null, 47.2, 30)), "Sortie du dimanche.gpx")
        .statusCode(200)
        .body("name", equalTo("Sortie du dimanche"));
  }

  /** docs/LEDGER_*.md WEB-100, C3c: the editor receives the file's waypoints, typed. */
  @Test
  void importGpx_returnsTypedWaypoints() throws IOException {
    String typed =
        "<wpt lat=\"47.2\" lon=\"-1.55\"><name>Source</name><desc>Eau</desc>"
            + "<sym>Drinking Water</sym><type>water</type></wpt>"
            + "<wpt lat=\"47.21\" lon=\"-1.55\"><name>Vieux</name></wpt>";
    File file = gpx("Typed", track("A", 47.20, 30) + typed);

    importFile(file)
        .statusCode(200)
        .body("waypointCount", equalTo(2))
        .body("waypoints.size()", equalTo(2))
        .body("waypoints[0].name", equalTo("Source"))
        .body("waypoints[0].type", equalTo("WATER"))
        .body("waypoints[0].origin", equalTo("IMPORTED"))
        .body("waypoints[0]", org.hamcrest.Matchers.not(org.hamcrest.Matchers.hasKey("id")))
        .body("waypoints[0]", org.hamcrest.Matchers.not(org.hamcrest.Matchers.hasKey("distance")))
        .body("waypoints[1].type", equalTo("INFO"));
  }

  @Test
  void importGpx_tracksKeepTheOrderOfTheFile_andWaypointsAreCounted() throws IOException {
    File file = gpx("Multi", track("A", 47.20, 30) + track("B", 47.30, 30) + waypoints(3));
    var tracks =
        importFile(file)
            .statusCode(200)
            .body("tracks.size()", equalTo(2))
            .body("waypointCount", equalTo(3))
            .extract()
            .<List<java.util.Map<String, Object>>>path("tracks");
    double firstLat = PolylineCodec.decode2((String) tracks.get(0).get("line"), 1000)[0][1];
    double secondLat = PolylineCodec.decode2((String) tracks.get(1).get("line"), 1000)[0][1];
    assertEquals(47.20, firstLat, 0.001);
    assertEquals(47.30, secondLat, 0.001);
  }

  @Test
  void importGpx_nineTracks_isTooLarge() throws IOException {
    StringBuilder body = new StringBuilder();
    for (int i = 0; i < GpxLimits.MAX_PLANNER_SOURCES + 1; i++) {
      body.append(track("T" + i, 47.0 + i * 0.01, 10));
    }
    importFile(gpx("Nine", body.toString()))
        .statusCode(400)
        .body("code", equalTo("PLANNER_IMPORT_TOO_LARGE"));
  }

  @Test
  void importGpx_eightTracks_isAccepted() throws IOException {
    StringBuilder body = new StringBuilder();
    for (int i = 0; i < GpxLimits.MAX_PLANNER_SOURCES; i++) {
      body.append(track("T" + i, 47.0 + i * 0.01, 10));
    }
    importFile(gpx("Eight", body.toString()))
        .statusCode(200)
        .body("tracks.size()", equalTo(GpxLimits.MAX_PLANNER_SOURCES));
  }

  // ------------------------------------------------------------------ errors

  @Test
  void importGpx_withoutFile_isFileRequired() {
    post(as(USER1).multiPart("teamSlug", team1Slug), null)
        .statusCode(400)
        .body("code", equalTo("FILE_REQUIRED"));
  }

  @Test
  void importGpx_oversized_isFileTooLarge() throws IOException {
    File file = Files.createTempFile("oversized-", ".gpx").toFile();
    tempFiles.add(file);
    try (RandomAccessFile raf = new RandomAccessFile(file, "rw")) {
      raf.setLength(GpxLimits.MAX_GPX_SIZE_BYTES + 1);
    }
    importFile(file).statusCode(400).body("code", equalTo("FILE_TOO_LARGE"));
  }

  @Test
  void importGpx_notGpx_isGpxFailure() throws IOException {
    importFile(write("this is not xml")).statusCode(400).body("code", equalTo("GPX_FAILURE"));
  }

  @Test
  void importGpx_withoutTrack_isGpxEmpty() throws IOException {
    importFile(gpx("Waypoints only", waypoints(2)))
        .statusCode(400)
        .body("code", equalTo("GPX_EMPTY"));
    importFile(gpx("One point", track("Dot", 47.2, 1)))
        .statusCode(400)
        .body("code", equalTo("GPX_EMPTY"));
  }

  @Test
  void importGpx_tooLong_isGpxTooLong() throws IOException {
    String pts =
        "<trkpt lat=\"0\" lon=\"0\"/><trkpt lat=\"0\" lon=\"179\"/><trkpt lat=\"0\" lon=\"0\"/>";
    importFile(gpx("Long", "<trk><trkseg>" + pts + "</trkseg></trk>"))
        .statusCode(400)
        .body("code", equalTo("GPX_TOO_LONG"));
  }

  // ------------------------------------------------------------------ who may import

  @Test
  void importGpx_withoutAuth_is401() {
    given()
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .post("/api/router/import-gpx")
        .then()
        .statusCode(401);
  }

  @Test
  void importGpx_withTeam_asMember_isAllowed() {
    importAs(USER1, EXAMPLE_GPX, team1Slug).statusCode(200);
  }

  @Test
  void importGpx_withTeam_asNonMember_is403() {
    importAs(USER4, EXAMPLE_GPX, team1Slug).statusCode(403);
  }

  @Test
  void importGpx_withTeam_whenTeamPlannerDisabled_isRoutePlannerDisabled() {
    dataService.setTeamEnableRoutePlanner(team1, false);
    importAs(USER1, EXAMPLE_GPX, team1Slug)
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void importGpx_withoutTeam_whenDomainPlannerDisabled_isRoutePlannerDisabled() {
    dataService.setDomainEnableGpxPlanner(domain, false);
    importFile(EXAMPLE_GPX).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void importGpx_withTeamOfAnotherDomain_is404() {
    var other = dataService.createDomain("other.example.com", "Other", "https://other.example.com");
    var owner = dataService.createUser(other, "owner@other.example.com", "Owner");
    var otherTeam =
        dataService.createTeam(other, owner, "Other team", "other-team", Visibility.PUBLIC);
    dataService.setTeamEnableRoutePlanner(otherTeam, true);

    importAs(USER1, EXAMPLE_GPX, "other-team").statusCode(404);
  }

  @Test
  void importGpx_rightsAreCheckedBeforeTheFileIsRequired() {
    post(as(USER4), team1Slug).statusCode(403);
  }

  @Test
  void importGpx_teamSlugOver250Characters_isRefused() {
    importAs(USER1, EXAMPLE_GPX, "a".repeat(251)).statusCode(400);
  }

  @Test
  void importGpx_name_dropsControlCharactersAndKeepsSurrogatePairs() throws IOException {
    String name = "x".repeat(249) + "\uD83D\uDEB4";
    importFile(gpx(name, track(null, 47.2, 5)))
        .statusCode(200)
        .body("name", equalTo("x".repeat(249)));
  }

  @Test
  void importGpx_rightsAreCheckedBeforeTheSize() throws IOException {
    File file = Files.createTempFile("oversized-", ".gpx").toFile();
    tempFiles.add(file);
    try (RandomAccessFile raf = new RandomAccessFile(file, "rw")) {
      raf.setLength(GpxLimits.MAX_GPX_SIZE_BYTES + 1);
    }
    importAs(USER4, file, team1Slug).statusCode(403);
  }

  // ------------------------------------------------------------------ nothing is stored

  @Test
  void importGpx_storesNothing() {
    long previews = count("gpx_previews");
    long assets = count("assets");
    long refreshes = count("elevation_refresh");
    long objects = storedObjects();

    importFile(EXAMPLE_GPX).statusCode(200);
    importAs(USER1, EXAMPLE_GPX, team1Slug).statusCode(200);

    assertEquals(previews, count("gpx_previews"));
    assertEquals(assets, count("assets"));
    assertEquals(refreshes, count("elevation_refresh"));
    assertEquals(objects, storedObjects());
    assertFalse(objects < 0);
  }
}
