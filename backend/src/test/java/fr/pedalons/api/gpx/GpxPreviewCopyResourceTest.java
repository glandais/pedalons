package fr.pedalons.api.gpx;

import static fr.pedalons.service.route.planner.PlannerStateFixtures.example;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.gpx.request.GpxPreviewCopyRequest;
import fr.pedalons.dto.gpx.request.GpxPreviewFromPointsRequest;
import fr.pedalons.service.limits.LimitsClock;
import fr.pedalons.service.route.GpxLimits;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-197: {@code POST /gpx-previews/{id}/copy} — any signed-in account copies any
 * preview it has the link of; the copy is the caller's, counts no planner save, and keeps the
 * planner state only when the caller is the creator.
 */
@io.quarkus.test.junit.QuarkusTest
class GpxPreviewCopyResourceTest extends AbstractResourceTest {

  private static final File WAYPOINTS_GPX = new File("src/test/resources/waypoints.gpx");
  private static final int PERSONAL_QUOTA = 10;
  private static final Instant NOW = Instant.parse("2026-11-15T10:00:00Z");

  @Inject LimitsClock limitsClock;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    limitsClock.setForTest(Clock.fixed(NOW, ZoneOffset.UTC));
    dataService.setDomainEnableGpxPlanner(domain, true);
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  @AfterEach
  void resetClock() {
    limitsClock.setForTest(null);
  }

  // ==================== helpers ====================

  private String createDrawn(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(new GpxPreviewFromPointsRequest("Boucle dessinée", null, example()))
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(201)
        .extract()
        .path("id");
  }

  private String uploadWaypoints(String user, String departure, String averageSpeed) {
    var request = given().auth().oauth2(getAccessToken(user));
    request = request.multiPart("gpxFile", WAYPOINTS_GPX, "application/gpx+xml");
    if (departure != null) {
      request = request.multiPart("departure", departure);
    }
    if (averageSpeed != null) {
      request = request.multiPart("averageSpeed", averageSpeed);
    }
    return request.when().post("/api/gpx-previews").then().statusCode(201).extract().path("id");
  }

  private ValidatableResponse copy(String user, String id, String name) {
    var spec = given();
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.contentType(MediaType.APPLICATION_JSON)
        .body(new GpxPreviewCopyRequest(name))
        .when()
        .post("/api/gpx-previews/" + id + "/copy")
        .then();
  }

  private ValidatableResponse read(String id) {
    return given().when().get("/api/gpx-previews/" + id).then();
  }

  private ValidatableResponse readState(String user, String id) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .when()
        .get("/api/gpx-previews/" + id + "/planner-state")
        .then();
  }

  private ValidatableResponse rename(String user, String id, String name) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .multiPart("preview", "{\"name\":\"" + name + "\"}", MediaType.APPLICATION_JSON)
        .when()
        .put("/api/gpx-previews/" + id)
        .then();
  }

  private ValidatableResponse delete(String user, String id) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .when()
        .delete("/api/gpx-previews/" + id)
        .then();
  }

  // ==================== tests ====================

  @Test
  void theCreator_copies_andKeepsThePlannerState() {
    String id = createDrawn(USER1);

    String copyId =
        copy(USER1, id, "Copie de la boucle")
            .statusCode(201)
            .body("name", equalTo("Copie de la boucle"))
            .body("owned", equalTo(true))
            .body("drawn", equalTo(example().drawn()))
            .extract()
            .path("id");

    assertNotEquals(id, copyId);
    readState(USER1, copyId)
        .statusCode(200)
        .body("state.profile", equalTo(example().profile().name()));
  }

  @Test
  void anotherAccount_copies_withoutTheState_butWithWaypoints_andOwnsTheCopy() {
    String id = uploadWaypoints(USER1, null, null);
    int waypoints = read(id).extract().path("waypoints.size()");

    String copyId =
        copy(USER4, id, "Ma copie")
            .statusCode(201)
            .body("name", equalTo("Ma copie"))
            .body("owned", equalTo(true))
            .body("waypoints.size()", equalTo(waypoints))
            .extract()
            .path("id");

    readState(USER4, copyId).statusCode(200).body("state", nullValue());
    // The owner of the copy edits and deletes it, but still not the source
    rename(USER4, copyId, "Copie renommee").statusCode(200).body("name", equalTo("Copie renommee"));
    rename(USER4, id, "Pirate").statusCode(403);
    delete(USER4, id).statusCode(403);
    delete(USER4, copyId).statusCode(204);
    read(copyId).statusCode(404);
    read(id).statusCode(200);
  }

  @Test
  void aCopyByAnotherAccount_ofADrawnPreview_neverRevealsTheState() {
    String id = createDrawn(USER1);

    String copyId = copy(USER2, id, "Copie d'ailleurs").statusCode(201).extract().path("id");

    readState(USER2, copyId).statusCode(200).body("state", nullValue());
    // The source's state is still the creator's only
    readState(USER2, id).statusCode(403);
    readState(USER1, id).statusCode(200).body("state", notNullValue());
  }

  @Test
  void theSource_isLeftUnchanged() {
    String id = uploadWaypoints(USER1, null, "25");
    String before = read(id).extract().asString();

    copy(USER4, id, "Une copie").statusCode(201);

    assertEquals(before, read(id).extract().asString());
  }

  @Test
  void theAverageSpeedAndAFutureDeparture_areCopied() {
    String departure =
        LocalDateTime.now().plusDays(20).withNano(0).format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
    String id = uploadWaypoints(USER1, departure, "27");
    String departureTime = read(id).extract().path("departureTime");

    copy(USER4, id, "Copie datée")
        .statusCode(201)
        .body("averageSpeed", equalTo(27.0f))
        .body("departureTime", equalTo(departureTime));
  }

  @Test
  void anAnonymousCaller_is401() {
    String id = createDrawn(USER1);

    copy(null, id, "Copie anonyme").statusCode(401);
  }

  @Test
  void anUnknownOrMalformedId_is404() {
    copy(USER1, UUID.randomUUID().toString(), "Copie fantôme").statusCode(404);
    copy(USER1, "pas-un-uuid", "Copie fantôme").statusCode(404);
  }

  @Test
  void aPreviewOfAnotherDomain_is404() {
    String id = createDrawn(USER1);
    var otherDomain =
        dataService.createDomain("other.example.com", "Other", "https://other.example.com");
    var stranger = dataService.createUser(otherDomain, "stranger@other.example.com", "Stranger");

    given()
        .auth()
        .oauth2(jwtService.generateAccessToken(stranger))
        .header("X-Forwarded-Host", "other.example.com")
        .contentType(MediaType.APPLICATION_JSON)
        .body(new GpxPreviewCopyRequest("Copie étrangère"))
        .when()
        .post("/api/gpx-previews/" + id + "/copy")
        .then()
        .statusCode(404);
  }

  @Test
  void anInvalidName_is400() {
    String id = createDrawn(USER1);

    copy(USER1, id, "ab").statusCode(400);
    copy(USER1, id, "   ").statusCode(400);
    copy(USER1, id, "x".repeat(201)).statusCode(400);
  }

  @Test
  void withThePersonalQuotaSpent_aCopyStillGoesThrough_andCountsNothing() {
    String id = createDrawn(USER1);
    dataService.addPlannerSaves(user1, null, PERSONAL_QUOTA, NOW);
    long before = dataService.countPlannerSaves(null, user1);

    // The quota is really spent: a new drawing is refused
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body(new GpxPreviewFromPointsRequest("Refusée", null, example()))
        .when()
        .post("/api/gpx-previews/from-points")
        .then()
        .statusCode(403)
        .body("errorDetails.scope", equalTo("PERSONAL"));

    copy(USER1, id, "Copie hors quota").statusCode(201);

    assertEquals(before, dataService.countPlannerSaves(null, user1));
  }

  @Test
  void theCreator_copyingWhileThePlannerIsClosed_loosesTheState() {
    String id = createDrawn(USER1);
    dataService.setDomainEnableGpxPlanner(domain, false);

    String copyId =
        copy(USER1, id, "Copie sans planificateur")
            .statusCode(201)
            .body("drawn", equalTo(false))
            .extract()
            .path("id");

    readState(USER1, copyId).statusCode(200).body("state", nullValue());
  }

  @Test
  void aCallerAtTheDatedPreviewsMaximum_copiesWithoutTheDeparture() {
    String departure =
        LocalDateTime.now().plusDays(20).withNano(0).format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
    String id = uploadWaypoints(USER1, departure, "27");
    for (int i = 0; i < GpxLimits.MAX_UPCOMING_DATED_PREVIEWS; i++) {
      dataService.createGpxPreview(
          domain,
          user4,
          UUID.randomUUID(),
          List.of(),
          1L,
          Instant.now().plusSeconds(86400L * 30),
          "Europe/Paris",
          null);
    }

    copy(USER4, id, "Copie sans date")
        .statusCode(201)
        .body("departureTime", nullValue())
        .body("averageSpeed", equalTo(27.0f));
  }
}
