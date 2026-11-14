package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertEquals;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.builder.MultiPartSpecBuilder;
import io.restassured.response.ValidatableResponse;
import io.restassured.specification.MultiPartSpecification;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.MediaType;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code excludedFromGenerator} of a route (docs/LEDGER_*.md API-198, lot 3 plan §4): "Ne pas
 * utiliser pour générer des parcours". Omitted on an update it leaves the box as it is, since
 * clients older than 14.13.0 never send it.
 */
@QuarkusTest
class RouteExcludedFromGeneratorResourceTest extends AbstractResourceTest {

  @Inject ObjectMapper objectMapper;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  private MultiPartSpecification part(RouteRequest request) {
    try {
      return new MultiPartSpecBuilder(
              objectMapper.writeValueAsString(request).getBytes(StandardCharsets.UTF_8))
          .controlName("route")
          .mimeType(MediaType.APPLICATION_JSON)
          .build();
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  private static RouteRequest request(String name, Boolean excluded) {
    return new RouteRequest(
        name,
        MediaDto.builder().build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null,
        null,
        null,
        null,
        excluded);
  }

  private ValidatableResponse create(String user, RouteRequest request) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .multiPart(part(request))
        .multiPart(
            "gpxFile", new java.io.File("src/test/resources/example.gpx"), "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then();
  }

  private ValidatableResponse update(String user, String slug, RouteRequest request) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .multiPart(part(request))
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + slug)
        .then();
  }

  private ValidatableResponse detail(String slug) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + slug)
        .then();
  }

  @Test
  void creatingWithTheBox_showsItInTheDetail() {
    String slug =
        create(USER1, request("Event route", true)).statusCode(201).extract().path("slug");
    detail(slug).statusCode(200).body("excludedFromGenerator", equalTo(true));
  }

  @Test
  void creatingWithoutTheField_isFalse() {
    String slug =
        create(USER1, request("Plain route", null)).statusCode(201).extract().path("slug");
    detail(slug).statusCode(200).body("excludedFromGenerator", equalTo(false));
  }

  @Test
  void anUpdateWithoutTheField_leavesTheBoxAsItIs() {
    String slug = create(USER1, request("Ticked", true)).statusCode(201).extract().path("slug");
    // an older client, or the mobile form: it does not know the field
    update(USER1, slug, request("Ticked, renamed", null)).statusCode(200);
    detail(slug).statusCode(200).body("excludedFromGenerator", equalTo(true));
  }

  @Test
  void anUpdateWithFalse_clearsIt_andWithTrue_setsIt() {
    String slug = create(USER1, request("Toggled", true)).statusCode(201).extract().path("slug");
    update(USER1, slug, request("Toggled", false)).statusCode(200);
    detail(slug).body("excludedFromGenerator", equalTo(false));
    update(USER1, slug, request("Toggled", true)).statusCode(200);
    detail(slug).body("excludedFromGenerator", equalTo(true));
  }

  @Test
  void aPlainMember_cannotChangeIt() {
    String slug = create(USER1, request("Mine", true)).statusCode(201).extract().path("slug");
    update(USER3, slug, request("Mine", false)).statusCode(403);
    detail(slug).body("excludedFromGenerator", equalTo(true));
  }

  @Test
  void aDuplicate_keepsTheBox() {
    String slug = create(USER1, request("Original", true)).statusCode(201).extract().path("slug");
    String copy =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(java.util.Map.of("name", "Copy of original"))
            .when()
            .post("/api/teams/" + team1Slug + "/routes/" + slug + "/duplicate")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");
    detail(copy).body("excludedFromGenerator", equalTo(true));
  }

  @Test
  void theShapeBeforeLot3_meansFalse() {
    Route route = dataService.createRoute(team1, user1, "Seeded");
    assertEquals(false, route.isExcludedFromGenerator());
    detail(route.getSlug()).statusCode(200).body("excludedFromGenerator", equalTo(false));
    RouteRequest old =
        new RouteRequest(
            "Old shape",
            MediaDto.builder().build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null);
    assertEquals(null, old.excludedFromGenerator());
  }
}
