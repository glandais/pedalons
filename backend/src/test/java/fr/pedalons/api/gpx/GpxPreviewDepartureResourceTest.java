package fr.pedalons.api.gpx;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.service.route.GpxLimits;
import io.restassured.response.ValidatableResponse;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.time.Instant;
import java.time.LocalDate;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/**
 * The departure date and the average speed of a GPX preview (docs/LEDGER_*.md API-149): given by
 * upload, merge, drawing and update, read back by whoever holds the link. The weather itself is in
 * {@code GpxPreviewWeatherResourceTest}.
 */
@io.quarkus.test.junit.QuarkusTest
class GpxPreviewDepartureResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");
  private static final File MERGE_PART_A = new File("src/test/resources/merge_part_a.gpx");
  private static final File MERGE_PART_B = new File("src/test/resources/merge_part_b.gpx");

  private static final String PARIS_POINTS =
      "[{\"lng\":4.8357,\"lat\":45.7640},{\"lng\":4.8500,\"lat\":45.7700}]";
  private static final String TOKYO_POINTS =
      "[{\"lng\":139.6917,\"lat\":35.6895},{\"lng\":139.7100,\"lat\":35.7000}]";

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setDomainEnableGpxPlanner(domain, true);
  }

  // ------------------------------------------------------------------ helpers

  private io.restassured.specification.RequestSpecification asUser1() {
    return given().auth().oauth2(getAccessToken(USER1));
  }

  private ValidatableResponse upload(String departure, String averageSpeed) {
    var request = asUser1().multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml");
    if (departure != null) {
      request = request.multiPart("departure", departure);
    }
    if (averageSpeed != null) {
      request = request.multiPart("averageSpeed", averageSpeed);
    }
    return request.when().post("/api/gpx-previews").then();
  }

  private ValidatableResponse fromPoints(String pointsJson, String extra) {
    return asUser1()
        .contentType(MediaType.APPLICATION_JSON)
        .body("{\"name\":\"Drawn\",\"points\":" + pointsJson + extra + "}")
        .when()
        .post("/api/gpx-previews/from-points")
        .then();
  }

  private ValidatableResponse put(String id, String previewJson) {
    return asUser1()
        .multiPart("preview", previewJson, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + id)
        .then();
  }

  private String createDated() {
    return upload("2026-11-10T08:30:00", "27.5").statusCode(201).extract().path("id");
  }

  // ------------------------------------------------------------------ creation

  @Test
  void upload_withDateAndSpeed_isReadInTheZoneOfTheStart_andReadableByTheLink() {
    String id =
        upload("2026-11-10T08:30:00", "27.5")
            .statusCode(201)
            .body("departureTime", notNullValue())
            .body("departureTimezone", equalTo("Europe/Paris"))
            .body("averageSpeed", equalTo(27.5f))
            .extract()
            .path("id");

    String time =
        given()
            .when()
            .get("/api/gpx-previews/" + id)
            .then()
            .statusCode(200)
            .body("departureTimezone", equalTo("Europe/Paris"))
            .body("averageSpeed", equalTo(27.5f))
            .extract()
            .path("departureTime");
    // 08:30 in Paris in November is 07:30Z
    assertEquals(Instant.parse("2026-11-10T07:30:00Z"), Instant.parse(time));
  }

  @Test
  void upload_withoutDateNorSpeed_hasNeither() {
    upload(null, null)
        .statusCode(201)
        .body("departureTime", nullValue())
        .body("departureTimezone", nullValue())
        .body("averageSpeed", nullValue());
  }

  @Test
  void upload_withASpeedAlone_keepsItWithoutADate() {
    upload(null, "30")
        .statusCode(201)
        .body("departureTime", nullValue())
        .body("averageSpeed", equalTo(30f));
  }

  @Test
  void merge_withDateAndSpeed() {
    asUser1()
        .multiPart("gpxFiles", MERGE_PART_A, "application/gpx+xml")
        .multiPart("gpxFiles", MERGE_PART_B, "application/gpx+xml")
        .multiPart("departure", "2026-11-10T08:30:00")
        .multiPart("averageSpeed", "22")
        .when()
        .post("/api/gpx-previews/merge")
        .then()
        .statusCode(201)
        .body("departureTimezone", equalTo("Europe/Paris"))
        .body("averageSpeed", equalTo(22f));
  }

  @Test
  void fromPoints_withDateAndSpeed() {
    fromPoints(PARIS_POINTS, ",\"departure\":\"2026-11-10T08:30:00\",\"averageSpeed\":24.5")
        .statusCode(201)
        .body("departureTimezone", equalTo("Europe/Paris"))
        .body("averageSpeed", equalTo(24.5f));
  }

  @Test
  void fromPoints_inTokyo_readsTheWallTimeThere() {
    String time =
        fromPoints(TOKYO_POINTS, ",\"departure\":\"2026-11-10T08:00:00\"")
            .statusCode(201)
            .body("departureTimezone", equalTo("Asia/Tokyo"))
            .extract()
            .path("departureTime");

    assertEquals(Instant.parse("2026-11-09T23:00:00Z"), Instant.parse(time));
  }

  @Test
  void list_carriesTheDateButNoSpeed() {
    createDated();

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gpx-previews")
        .then()
        .statusCode(200)
        .body("previews[0].departureTime", notNullValue())
        .body("previews[0].departureTimezone", equalTo("Europe/Paris"));
  }

  // ------------------------------------------------------------------ refusals

  @ParameterizedTest
  @ValueSource(
      strings = {"2026-11-10T08:30:00Z", "2026-11-10T08:30:00+01:00", "demain", "2026-11-10"})
  void upload_withADateThatIsNotAWallTime_is400(String departure) {
    upload(departure, null).statusCode(400);
  }

  @ParameterizedTest
  @ValueSource(strings = {"0", "9.9", "60.5", "101", "-3", "abc", "NaN", "Infinity", "1e-9", "25f"})
  void upload_withASpeedOutOfBounds_is400(String speed) {
    upload(null, speed).statusCode(400);
  }

  @ParameterizedTest
  @ValueSource(strings = {"10", "60", "18.25"})
  void upload_withASpeedWithinBounds_isAccepted(String speed) {
    upload(null, speed).statusCode(201);
  }

  @ParameterizedTest
  @ValueSource(strings = {"0", "9.9", "60.5", "-3", "1e-9"})
  void fromPoints_withASpeedOutOfBounds_is400(String speed) {
    fromPoints(PARIS_POINTS, ",\"averageSpeed\":" + speed).statusCode(400);
  }

  @Test
  void upload_withAnEndlessSpeedText_is400_beforeItIsParsed() {
    upload(null, "1".repeat(100_000)).statusCode(400);
  }

  @Test
  void aDatedPreviewPastTheQuota_is400_butUndatedOnesAndEditsOfADatedOneAreNot() {
    // Relative: the quota counts the departures to come only.
    String upcoming = LocalDate.now().plusDays(3) + "T08:30:00";
    String first = null;
    for (int i = 0; i < GpxLimits.MAX_UPCOMING_DATED_PREVIEWS; i++) {
      String id = upload(upcoming, null).statusCode(201).extract().path("id");
      first = first == null ? id : first;
    }
    upload(upcoming, null).statusCode(400);
    upload(null, null).statusCode(201);
    put(first, "{\"name\":\"Moved\",\"departure\":\"" + upcoming + "\"}").statusCode(200);
  }

  @Test
  void fromPoints_withAnInstant_is400() {
    fromPoints(PARIS_POINTS, ",\"departure\":\"2026-11-10T08:30:00Z\"").statusCode(400);
    fromPoints(PARIS_POINTS, ",\"departure\":\"2026-11-10T08:30:00+02:00\"").statusCode(400);
  }

  @Test
  void update_withAnInstantInThePreviewPart_is400() {
    String id = createDated();

    put(id, "{\"name\":\"Renamed\",\"departure\":\"2026-11-10T08:30:00Z\"}").statusCode(400);
    put(id, "{\"name\":\"Renamed\",\"averageSpeed\":61}").statusCode(400);
  }

  // ------------------------------------------------------------------ update

  @Test
  void update_withoutTheFields_keepsDateAndSpeed_forARename_aWaypointsSave_andANewFile() {
    String id = createDated();

    put(id, "{\"name\":\"Renamed\"}")
        .statusCode(200)
        .body("departureTimezone", equalTo("Europe/Paris"))
        .body("averageSpeed", equalTo(27.5f))
        .body("departureTime", notNullValue());

    put(id, "{\"name\":\"Renamed again\",\"waypoints\":[]}")
        .statusCode(200)
        .body("averageSpeed", equalTo(27.5f))
        .body("departureTime", notNullValue());

    asUser1()
        .multiPart("preview", "{\"name\":\"New file\"}", MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .put("/api/gpx-previews/" + id)
        .then()
        .statusCode(200)
        .body("averageSpeed", equalTo(27.5f))
        .body("departureTime", notNullValue());
  }

  @Test
  void update_replacesTheDateAndTheSpeed() {
    String id = createDated();

    String time =
        put(id, "{\"name\":\"Later\",\"departure\":\"2026-11-11T09:00:00\",\"averageSpeed\":31}")
            .statusCode(200)
            .body("averageSpeed", equalTo(31f))
            .extract()
            .path("departureTime");

    assertEquals(Instant.parse("2026-11-11T08:00:00Z"), Instant.parse(time));
  }

  @Test
  void update_clearDeparture_leavesTheSpeed_andClearAverageSpeed_leavesTheDate() {
    String id = createDated();

    put(id, "{\"name\":\"No date\",\"clearDeparture\":true}")
        .statusCode(200)
        .body("departureTime", nullValue())
        .body("departureTimezone", nullValue())
        .body("averageSpeed", equalTo(27.5f));

    put(id, "{\"name\":\"Dated\",\"departure\":\"2026-11-10T08:30:00\"}").statusCode(200);
    put(id, "{\"name\":\"No speed\",\"clearAverageSpeed\":true}")
        .statusCode(200)
        .body("averageSpeed", nullValue())
        .body("departureTime", notNullValue());
  }

  @Test
  void update_aValueAndItsRemoval_is400_andWritesNothing() {
    String id = createDated();
    String name = given().when().get("/api/gpx-previews/" + id).then().extract().path("name");

    put(id, "{\"name\":\"Both\",\"departure\":\"2026-11-12T09:00:00\",\"clearDeparture\":true}")
        .statusCode(400);
    put(id, "{\"name\":\"Both\",\"averageSpeed\":30,\"clearAverageSpeed\":true}").statusCode(400);

    given()
        .when()
        .get("/api/gpx-previews/" + id)
        .then()
        .statusCode(200)
        .body("name", equalTo(name))
        .body("averageSpeed", equalTo(27.5f))
        .body("departureTime", notNullValue());
  }

  @Test
  void update_movingTheTrackToTokyo_keepsTheLocalTime_andMovesTheInstant() {
    String id =
        fromPoints(PARIS_POINTS, ",\"departure\":\"2026-11-10T08:00:00\",\"averageSpeed\":26")
            .statusCode(201)
            .extract()
            .path("id");

    String time =
        put(id, "{\"name\":\"Moved\",\"points\":" + TOKYO_POINTS + "}")
            .statusCode(200)
            .body("departureTimezone", equalTo("Asia/Tokyo"))
            .body("averageSpeed", equalTo(26f))
            .extract()
            .path("departureTime");

    // 08:00 in Tokyo, not 08:00 in Paris
    assertEquals(Instant.parse("2026-11-09T23:00:00Z"), Instant.parse(time));
  }

  @Test
  void update_byAnotherUser_is403() {
    String id = createDated();

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .multiPart(
            "preview", "{\"name\":\"Hijack\",\"clearDeparture\":true}", MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + id)
        .then()
        .statusCode(403);
  }
}
