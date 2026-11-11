package fr.pedalons.api.routes;

import static fr.pedalons.service.route.planner.PlannerStateFixtures.example;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.ws.rs.core.MediaType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-180: {@code POST /routes/{slug}/preview} — a GPX preview of the caller's
 * made from a route they may read, with its title, planner state and waypoints.
 */
@QuarkusTest
class RoutePreviewFromRouteResourceTest extends AbstractResourceTest {

  @Inject EntityManager em;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setTeamEnableRoutePlanner(team1, true);
    dataService.setDomainEnableGpxPlanner(domain, true);
  }

  // ==================== helpers ====================

  private String createDrawn(String name, Visibility visibility) {
    RouteRequest request =
        new RouteRequest(
            name,
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.GRAVEL,
            visibility,
            null,
            null,
            example());
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", request, MediaType.APPLICATION_JSON)
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  private ValidatableResponse preview(String user, String slug) {
    var spec = given();
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().post("/api/teams/" + team1Slug + "/routes/" + slug + "/preview").then();
  }

  private long routeCount() {
    return QuarkusTransaction.requiringNew()
        .call(() -> em.createQuery("select count(r) from Route r", Long.class).getSingleResult());
  }

  // ==================== tests ====================

  @Test
  void anAnonymousCaller_is401() {
    String slug = createDrawn("Boucle", Visibility.PUBLIC);

    preview(null, slug).statusCode(401);
  }

  @Test
  void anAccountOfAnotherTeam_gets201_onAPublicRoute() {
    String slug = createDrawn("Boucle des étangs", Visibility.PUBLIC);

    // USER4 is a member of no team.
    preview(USER4, slug)
        .statusCode(201)
        .body("id", notNullValue())
        .body("name", equalTo("Boucle des étangs"))
        .body("owned", equalTo(true))
        .body("drawn", equalTo(example().drawn()));
  }

  @Test
  void anAccountOfAnotherTeam_gets404_onATeamRoute() {
    String slug = createDrawn("Boucle", Visibility.TEAM);

    preview(USER4, slug).statusCode(404);
  }

  @Test
  void aMember_gets201_onATeamRoute() {
    String slug = createDrawn("Boucle", Visibility.TEAM);

    preview(USER3, slug).statusCode(201).body("name", equalTo("Boucle"));
  }

  @Test
  void aDeletedRoute_givesNoPreview_404_evenToAnAdmin() {
    String slug = createDrawn("Boucle", Visibility.PUBLIC);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(204);

    preview(USER1, slug).statusCode(404);
    preview(USER4, slug).statusCode(404);
  }

  @Test
  void theCreator_readsThePlannerState_andTheRouteIsUnchanged() {
    String slug = createDrawn("Boucle", Visibility.PUBLIC);
    long routes = routeCount();

    String previewId = preview(USER4, slug).statusCode(201).extract().path("id");

    PlannerState state = example();
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/gpx-previews/" + previewId + "/planner-state")
        .then()
        .statusCode(200)
        .body("state.profile", equalTo(state.profile().name()))
        .body("state.pieces.size()", equalTo(state.pieces().size()))
        .body("state.junctions.size()", equalTo(state.junctions().size()))
        .body("state.pieces[1].line", equalTo(state.pieces().get(1).line()));
    // Someone else may not read it.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gpx-previews/" + previewId + "/planner-state")
        .then()
        .statusCode(403);

    // Nothing was created in the team, and the route reads as before.
    assertEquals(routes, routeCount());
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Boucle"));
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug + "/planner-state")
        .then()
        .statusCode(200)
        .body("state.pieces.size()", equalTo(state.pieces().size()));
  }
}
