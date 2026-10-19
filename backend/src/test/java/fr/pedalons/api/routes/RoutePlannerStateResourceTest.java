package fr.pedalons.api.routes;

import static fr.pedalons.service.route.planner.PlannerStateFixtures.*;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.dto.common.asset.MediaDto;
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
import org.hibernate.Hibernate;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** docs/LEDGER_*.md WEB-100 (C4a): the planner state of a route, saved with it and read back. */
@QuarkusTest
class RoutePlannerStateResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");
  private static final File TWO_TRACKS_GPX = new File("src/test/resources/two_tracks.gpx");

  @Inject EntityManager em;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  // ==================== helpers ====================

  private static RouteRequest request(
      String name, List<GeoPoint> points, PlannerState plannerState) {
    return new RouteRequest(
        name,
        MediaDto.builder().build(),
        SurfaceType.GRAVEL,
        Visibility.PUBLIC,
        points,
        null,
        plannerState);
  }

  private static RouteRequest stateRequest(String name, PlannerState plannerState) {
    return request(name, null, plannerState);
  }

  private ValidatableResponse create(RouteRequest route, File gpx) {
    var spec =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("route", route, MediaType.APPLICATION_JSON);
    if (gpx != null) {
      spec = spec.multiPart("gpxFile", gpx, "application/gpx+xml");
    }
    return spec.when().post("/api/teams/" + team1Slug + "/routes").then();
  }

  private String createWithState(PlannerState state) {
    return create(stateRequest("Drawn route", state), null).statusCode(201).extract().path("slug");
  }

  private ValidatableResponse update(String slug, RouteRequest route, File gpx) {
    var spec =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("route", route, MediaType.APPLICATION_JSON);
    if (gpx != null) {
      spec = spec.multiPart("gpxFile", gpx, "application/gpx+xml");
    }
    return spec.when().put("/api/teams/" + team1Slug + "/routes/" + slug).then();
  }

  private ValidatableResponse readState(String slug, String user) {
    var spec = given();
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().get("/api/teams/" + team1Slug + "/routes/" + slug + "/planner-state").then();
  }

  private void assertStateIs(String slug, PlannerState expected) {
    readState(slug, USER1)
        .statusCode(200)
        .header("Cache-Control", containsString("no-store"))
        .body("state.version", equalTo(1))
        .body("state.profile", equalTo(expected.profile().name()))
        .body("state.pieces.size()", equalTo(expected.pieces().size()))
        .body("state.junctions.size()", equalTo(expected.junctions().size()))
        .body("state.sources.size()", equalTo(expected.sources().size()));
  }

  private void assertNoState(String slug) {
    readState(slug, USER1).statusCode(200).body("state", nullValue());
  }

  private Long routeId(String slug) {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                em.createQuery("select r.id from Route r where r.slug = :slug", Long.class)
                    .setParameter("slug", slug)
                    .getSingleResult());
  }

  // ==================== create and read ====================

  @Test
  void createWithState_isReadBackAsItWas() {
    PlannerState state = example();
    String slug = createWithState(state);

    readState(slug, USER1)
        .statusCode(200)
        .body("state.junctions[1].kind", equalTo("JOIN"))
        .body("state.junctions[1].source", equalTo(0))
        .body("state.junctions[1].idx", equalTo(5))
        .body("state.junctions[2].kind", equalTo("CONTROL"))
        .body("state.junctions[2].source", nullValue())
        .body("state.pieces[0].mode", equalTo("IMPORTED"))
        .body("state.pieces[0].from", equalTo(0))
        .body("state.pieces[0].to", equalTo(5))
        .body("state.pieces[1].mode", equalTo("ROUTED"))
        .body("state.pieces[1].line", equalTo(state.pieces().get(1).line()))
        .body("state.sources[0].line", equalTo(state.sources().getFirst().line()))
        .body("state.sources[0].ele", equalTo(state.sources().getFirst().ele()))
        .body("state.sources[0].ascendScale", equalTo(1.0f));
    assertStateIs(slug, state);
  }

  @Test
  void theSavedTrackFollowsTheDerivation() {
    PlannerState state = drawn();
    String slug = createWithState(state);

    Long id = routeId(slug);
    GpxTrack track =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  GpxTrack t =
                      em.createQuery(
                              "select t from GpxTrack t where t.route.id = :id", GpxTrack.class)
                          .setParameter("id", id)
                          .getSingleResult();
                  t.getTrackPoints().size();
                  return t;
                });
    List<GpxTrack.TrackPoint> points = track.getTrackPoints();
    // The pipeline resamples, but the ends are the first and the last junction
    assertEquals(4.83, points.getFirst().lng(), 1e-4);
    assertEquals(45.76, points.getFirst().lat(), 1e-4);
    assertEquals(4.84, points.getLast().lng(), 1e-4);
    assertEquals(45.765, points.getLast().lat(), 1e-4);
  }

  @Test
  void readIsReservedToEditors() {
    String slug = createWithState(drawn());

    readState(slug, null).statusCode(401);
    readState(slug, USER3).statusCode(403);
    readState(slug, USER2).statusCode(200);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/nowhere/planner-state")
        .then()
        .statusCode(404);
  }

  @Test
  void readAcrossDomainsIsRefused() {
    String slug = createWithState(drawn());
    dataService.createDomain("other.example.com", "Other", "https://other.example.com");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .header("X-Forwarded-Host", "other.example.com")
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug + "/planner-state")
        .then()
        .statusCode(anyOf(is(404), is(401), is(403)));
  }

  @Test
  void aRouteWithoutStateAnswersNull() {
    String slug =
        create(request("From a file", null, null), EXAMPLE_GPX)
            .statusCode(201)
            .extract()
            .path("slug");
    assertNoState(slug);
  }

  @Test
  void aRouteFromPointsHasNoState() {
    String slug =
        create(
                request(
                    "From points",
                    List.of(new GeoPoint(4.8357, 45.764), new GeoPoint(4.85, 45.77)),
                    null),
                null)
            .statusCode(201)
            .extract()
            .path("slug");
    assertNoState(slug);
  }

  @Test
  void aMultiTrackRouteHasNoState() {
    String slug =
        create(request("Two tracks", null, null), TWO_TRACKS_GPX)
            .statusCode(201)
            .extract()
            .path("slug");
    assertNoState(slug);
  }

  @Test
  void theStateIsInNoOtherPayload() {
    String slug = createWithState(example());

    String detail =
        given()
            .when()
            .get("/api/teams/" + team1Slug + "/routes/" + slug)
            .then()
            .statusCode(200)
            .extract()
            .asString();
    String list =
        given()
            .when()
            .get("/api/teams/" + team1Slug + "/routes")
            .then()
            .statusCode(200)
            .extract()
            .asString();
    String bulk =
        given()
            .queryParam("slugs", slug)
            .when()
            .get("/api/teams/" + team1Slug + "/routes/bulk")
            .then()
            .statusCode(200)
            .extract()
            .asString();
    for (String json : List.of(detail, list, bulk)) {
      assertFalse(json.contains("plannerState"), json);
      assertFalse(json.contains("junctions"), json);
    }
  }

  // ==================== update ====================

  @Test
  void updateWithAFile_clearsTheState() {
    String slug = createWithState(example());
    update(slug, request("Drawn route", null, example()), EXAMPLE_GPX).statusCode(200);
    assertNoState(slug);
  }

  @Test
  void updateWithPoints_clearsTheState() {
    String slug = createWithState(example());
    update(
            slug,
            request(
                "Drawn route",
                List.of(new GeoPoint(4.8357, 45.764), new GeoPoint(4.85, 45.77)),
                null),
            null)
        .statusCode(200);
    assertNoState(slug);
  }

  @Test
  void updateWithAState_replacesIt() {
    String slug = createWithState(example());
    PlannerState next = withProfile(drawn(), RouterProfile.MTB);
    update(slug, stateRequest("Drawn route", next), null).statusCode(200);

    readState(slug, USER1)
        .statusCode(200)
        .body("state.profile", equalTo("MTB"))
        .body("state.sources.size()", equalTo(0));
  }

  @Test
  void updateOfTheTitleOnly_keepsTheState() {
    String slug = createWithState(example());
    update(slug, request("Renamed route", null, null), null).statusCode(200);
    assertStateIs(slug, example());
  }

  @Test
  void changingTheSlug_keepsTheState() {
    String slug = createWithState(example());
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(MediaType.APPLICATION_JSON)
        .body("{\"slug\":\"new-slug-for-state\"}")
        .when()
        .patch("/api/teams/" + team1Slug + "/routes/" + slug + "/slug")
        .then()
        .statusCode(200);
    assertStateIs("new-slug-for-state", example());
  }

  @Test
  void aStaleRevision_isNotReadBack() {
    String slug = createWithState(example());
    Long id = routeId(slug);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxTrack track =
                  em.createQuery("select t from GpxTrack t where t.route.id = :id", GpxTrack.class)
                      .setParameter("id", id)
                      .getSingleResult();
              track.setPlannerState(new PlannerStateDocument(12345L, example()));
            });
    assertNoState(slug);
  }

  // ==================== refusals ====================

  @Test
  void pointsWithAState_is400() {
    create(
            request(
                "Both", List.of(new GeoPoint(4.8357, 45.764), new GeoPoint(4.85, 45.77)), drawn()),
            null)
        .statusCode(400)
        .body("code", equalTo("PLANNER_STATE_INVALID"));
    // Even with a file
    create(
            request(
                "Both", List.of(new GeoPoint(4.8357, 45.764), new GeoPoint(4.85, 45.77)), drawn()),
            EXAMPLE_GPX)
        .statusCode(400)
        .body("code", equalTo("PLANNER_STATE_INVALID"));
  }

  @Test
  void anInvalidState_is400_andChangesNothing() {
    String slug = createWithState(example());
    PlannerState bad =
        new PlannerState(
            2, drawn().profile(), drawn().sources(), drawn().junctions(), drawn().pieces());

    update(slug, stateRequest("Should not be saved", bad), null)
        .statusCode(400)
        .body("code", equalTo("PLANNER_STATE_INVALID"));

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Drawn route"));
    assertStateIs(slug, example());
  }

  @Test
  void aStateOnATeamWithoutPlanner_isRefused() {
    dataService.setTeamEnableRoutePlanner(team1, false);
    create(stateRequest("Closed", drawn()), null)
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void aStateWithAFile_takesTheFile_andIgnoresTheState_evenInvalid() {
    // Well-formed (a malformed body fails @ValidateSchema whatever else it carries), but of an
    // unknown version: invalid for PlannerStates, which never looks at it when a file is sent
    PlannerState bad =
        new PlannerState(
            2, example().profile(), example().sources(), example().junctions(), example().pieces());
    String slug =
        create(request("File wins", null, bad), EXAMPLE_GPX).statusCode(201).extract().path("slug");
    assertNoState(slug);
  }

  @Test
  void aStateWithoutPointsNorState_isEmpty() {
    create(request("Nothing", null, null), null).statusCode(400).body("code", equalTo("GPX_EMPTY"));
  }

  // ==================== storage ====================

  @Test
  void thePlannerStateColumn_isLazy() {
    String slug = createWithState(example());
    Long id = routeId(slug);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Long trackId =
                  em.createQuery("select t.id from GpxTrack t where t.route.id = :id", Long.class)
                      .setParameter("id", id)
                      .getSingleResult();
              GpxTrack track = em.find(GpxTrack.class, trackId);
              assertNotNull(track);
              assertFalse(Hibernate.isPropertyInitialized(track, "plannerState"));
              assertNotNull(track.getPlannerState());
            });
  }
}
