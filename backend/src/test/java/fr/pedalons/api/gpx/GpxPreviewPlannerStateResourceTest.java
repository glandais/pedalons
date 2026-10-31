package fr.pedalons.api.gpx;

import static fr.pedalons.service.route.planner.PlannerStateFixtures.*;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertFalse;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.planner.PlannerSource;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.gpx.request.GpxPreviewFromPointsRequest;
import fr.pedalons.dto.gpx.request.GpxPreviewUpdateRequest;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** docs/LEDGER_*.md WEB-100 (C4a): the planner state of a GPX preview, readable by its creator only. */
@QuarkusTest
class GpxPreviewPlannerStateResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");
  private static final List<GeoPoint> POINTS =
      List.of(new GeoPoint(4.8357, 45.7640), new GeoPoint(4.85, 45.77));

  @Inject EntityManager em;
  @Inject fr.pedalons.repository.gpx.GpxPreviewRepository gpxPreviewRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setDomainEnableGpxPlanner(domain, true);
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  // ==================== helpers ====================

  private ValidatableResponse fromPoints(String user, GpxPreviewFromPointsRequest body) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(body)
        .when()
        .post("/api/gpx-previews/from-points")
        .then();
  }

  private String createWithState(PlannerState state) {
    return fromPoints(USER1, new GpxPreviewFromPointsRequest("Drawn preview", null, state))
        .statusCode(201)
        .extract()
        .path("id");
  }

  private ValidatableResponse readState(String id, String user) {
    var spec = given();
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().get("/api/gpx-previews/" + id + "/planner-state").then();
  }

  private ValidatableResponse update(String id, GpxPreviewUpdateRequest body, File gpx) {
    var spec =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("preview", body, MediaType.APPLICATION_JSON);
    if (gpx != null) {
      spec = spec.multiPart("gpxFile", gpx, "application/gpx+xml");
    }
    return spec.when().put("/api/gpx-previews/" + id).then();
  }

  private void assertHasState(String id, RouterProfile profile) {
    readState(id, USER1)
        .statusCode(200)
        .header("Cache-Control", containsString("no-store"))
        .body("state.profile", equalTo(profile.name()));
  }

  private void assertNoState(String id) {
    readState(id, USER1).statusCode(200).body("state", nullValue());
  }

  private RouteRequest routeRequest() {
    return new RouteRequest(
        "Promoted", MediaDto.builder().build(), SurfaceType.ROAD, Visibility.PUBLIC, null);
  }

  private ValidatableResponse promote(String id, String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(routeRequest())
        .when()
        .post("/api/gpx-previews/" + id + "/routes/" + team1Slug)
        .then();
  }

  // ==================== create ====================

  @Test
  void aDrawnStateMakesADrawnPreview_andIsReadBack() {
    fromPoints(USER1, new GpxPreviewFromPointsRequest("Drawn preview", null, example()))
        .statusCode(201)
        .body("drawn", equalTo(true))
        .body("$", not(hasKey("plannerState")));
    String id = createWithState(example());

    readState(id, USER1)
        .statusCode(200)
        .body("state.pieces.size()", equalTo(example().pieces().size()))
        .body("state.junctions.size()", equalTo(example().junctions().size()))
        .body("state.sources[0].line", equalTo(example().sources().getFirst().line()));
  }

  /** The raw lines of a preview, decoded: one point count per track. */
  private List<Integer> rawLinePoints(String id) {
    List<String> lines =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    gpxPreviewRepository
                        .findByPublicId(domain.getId(), UUID.fromString(id))
                        .orElseThrow()
                        .readableRawLines());
    org.junit.jupiter.api.Assertions.assertNotNull(lines);
    return lines.stream()
        .map(
            l ->
                fr.pedalons.service.route.planner.PolylineCodec.decode2(l, Integer.MAX_VALUE)
                    .length)
        .toList();
  }

  /**
   * docs/LEDGER_*.md API-147, phase C: a drawn preview keeps the router's raw shapes, every point,
   * and a state without them its lines, as before.
   */
  @Test
  void aDrawnStateWithShapes_keepsTheRawShapes() {
    String withShapes = createWithState(drawnWithShapes());
    org.junit.jupiter.api.Assertions.assertEquals(
        List.of(DRAWN_WITH_SHAPES_DERIVED), rawLinePoints(withShapes));
    readState(withShapes, USER1)
        .statusCode(200)
        .body("state.pieces[0].shape", equalTo(drawnWithShapes().pieces().getFirst().shape()));

    String without = createWithState(drawn());
    org.junit.jupiter.api.Assertions.assertEquals(List.of(3 + 1 + 2), rawLinePoints(without));
  }

  @Test
  void aSourceClimb_isReadBackAsItWas() {
    String id = createWithState(exampleWithClimb());

    readState(id, USER1)
        .statusCode(200)
        .body("state.sources[0].climb", equalTo(exampleWithClimb().sources().getFirst().climb()));
  }

  @Test
  void anInvalidSourceClimb_isRefused() {
    PlannerState e = exampleWithClimb();
    PlannerSource s = e.sources().getFirst();
    PlannerState bad =
        new PlannerState(
            e.version(),
            e.profile(),
            List.of(new PlannerSource(s.line(), s.ele(), 1.0, "??")),
            e.junctions(),
            e.pieces());
    fromPoints(USER1, new GpxPreviewFromPointsRequest("Bad climb", null, bad))
        .statusCode(400)
        .body("code", equalTo("PLANNER_STATE_INVALID"));
  }

  @Test
  void anImportedOnlyStateIsNotDrawn() {
    fromPoints(USER1, new GpxPreviewFromPointsRequest("Untouched file", null, importedOnly()))
        .statusCode(201)
        .body("drawn", equalTo(false));
  }

  @Test
  void neitherPointsNorState_isGpxEmpty() {
    fromPoints(USER1, new GpxPreviewFromPointsRequest("Nothing here", null, null))
        .statusCode(400)
        .body("code", equalTo("GPX_EMPTY"));
  }

  @Test
  void pointsAndState_isInvalid() {
    fromPoints(USER1, new GpxPreviewFromPointsRequest("Both of them", POINTS, drawn()))
        .statusCode(400)
        .body("code", equalTo("PLANNER_STATE_INVALID"));
  }

  @Test
  void anInvalidState_isInvalid() {
    PlannerState bad =
        new PlannerState(2, drawn().profile(), List.of(), drawn().junctions(), drawn().pieces());
    fromPoints(USER1, new GpxPreviewFromPointsRequest("Bad state", null, bad))
        .statusCode(400)
        .body("code", equalTo("PLANNER_STATE_INVALID"));
  }

  @Test
  void aStateWithPlannerDisabled_isRefused() {
    dataService.setDomainEnableGpxPlanner(domain, false);
    fromPoints(USER1, new GpxPreviewFromPointsRequest("Closed", null, drawn()))
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  // ==================== read ====================

  @Test
  void onlyTheCreatorReadsTheState() {
    String id = createWithState(example());

    assertHasState(id, example().profile());
    readState(id, USER2).statusCode(403);
    readState(id, null).statusCode(401);
    readState(UUID.randomUUID().toString(), USER1).statusCode(404);
  }

  @Test
  void aStateAcrossDomains_isRefused() {
    String id = createWithState(example());
    dataService.createDomain("other.example.com", "Other", "https://other.example.com");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .header("X-Forwarded-Host", "other.example.com")
        .when()
        .get("/api/gpx-previews/" + id + "/planner-state")
        .then()
        .statusCode(anyOf(is(404), is(401), is(403)));
  }

  @Test
  void theStateIsInNoPublicPayload() {
    String id = createWithState(example());

    String dto =
        given().when().get("/api/gpx-previews/" + id).then().statusCode(200).extract().asString();
    String list =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get("/api/gpx-previews")
            .then()
            .statusCode(200)
            .extract()
            .asString();
    for (String json : List.of(dto, list)) {
      assertFalse(json.contains("plannerState"), json);
      assertFalse(json.contains("junctions"), json);
    }
  }

  // ==================== update ====================

  @Test
  void updateWithAFile_clearsTheState() {
    String id = createWithState(example());
    update(id, new GpxPreviewUpdateRequest("Replaced by file", null, null), EXAMPLE_GPX)
        .statusCode(200)
        .body("drawn", equalTo(false));
    assertNoState(id);
  }

  @Test
  void updateWithAFile_ignoresAStateEvenInvalid() {
    String id = createWithState(example());
    // Well-formed (a malformed body fails @ValidateSchema whatever else it carries), but of an
    // unknown version: invalid for PlannerStates, which never looks at it when a file is sent
    PlannerState bad =
        new PlannerState(
            2, example().profile(), example().sources(), example().junctions(), example().pieces());
    update(id, new GpxPreviewUpdateRequest("Replaced by file", null, bad), EXAMPLE_GPX)
        .statusCode(200);
    assertNoState(id);
  }

  @Test
  void updateWithPoints_clearsTheState() {
    String id = createWithState(example());
    update(id, new GpxPreviewUpdateRequest("Redrawn by points", POINTS, null), null)
        .statusCode(200)
        .body("drawn", equalTo(true));
    assertNoState(id);
  }

  @Test
  void updateWithAState_writesTheNewOne_andDrawnFollows() {
    String id = createWithState(example());
    update(
            id,
            new GpxPreviewUpdateRequest(
                "Redrawn", null, withProfile(importedOnly(), RouterProfile.MTB)),
            null)
        .statusCode(200)
        .body("drawn", equalTo(false));
    assertHasState(id, RouterProfile.MTB);

    update(
            id,
            new GpxPreviewUpdateRequest(
                "Redrawn", null, withProfile(drawn(), RouterProfile.FASTBIKE)),
            null)
        .statusCode(200)
        .body("drawn", equalTo(true));
    assertHasState(id, RouterProfile.FASTBIKE);
  }

  @Test
  void updateWithPointsAndState_isInvalid() {
    String id = createWithState(example());
    update(id, new GpxPreviewUpdateRequest("Both of them", POINTS, drawn()), null)
        .statusCode(400)
        .body("code", equalTo("PLANNER_STATE_INVALID"));
    assertHasState(id, example().profile());
  }

  @Test
  void renameOnly_keepsTheState() {
    String id = createWithState(example());
    update(id, new GpxPreviewUpdateRequest("Only renamed", null, null), null)
        .statusCode(200)
        .body("name", equalTo("Only renamed"));
    assertHasState(id, example().profile());
  }

  // ==================== promotion ====================

  @Test
  void promotionByTheCreator_carriesTheState() {
    String id = createWithState(example());

    String slug = promote(id, USER1).statusCode(201).extract().path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug + "/planner-state")
        .then()
        .statusCode(200)
        .body("state.profile", equalTo(example().profile().name()))
        .body("state.pieces.size()", equalTo(example().pieces().size()))
        .body("state.sources[0].line", equalTo(example().sources().getFirst().line()));
  }

  @Test
  void promotionByAnotherMember_carriesNothing() {
    String id = createWithState(example());

    String slug = promote(id, USER2).statusCode(201).extract().path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug + "/planner-state")
        .then()
        .statusCode(200)
        .body("state", nullValue());
  }

  @Test
  void promotionOfAStalePreviewState_carriesNothing() {
    String id = createWithState(example());
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxPreview preview =
                  em.createQuery(
                          "select p from GpxPreview p where p.publicId = :id", GpxPreview.class)
                      .setParameter("id", UUID.fromString(id))
                      .getSingleResult();
              preview.setPlannerState(new PlannerStateDocument(1L, example()));
            });

    String slug = promote(id, USER1).statusCode(201).extract().path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug + "/planner-state")
        .then()
        .statusCode(200)
        .body("state", nullValue());
  }

  @Test
  void aDrawnPreviewToATeamWithoutPlanner_isStillRefused() {
    String id = createWithState(example());
    dataService.setTeamEnableRoutePlanner(team1, false);

    promote(id, USER1).statusCode(400).body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }
}
