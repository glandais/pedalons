package fr.pedalons.api.places;

import static io.restassured.RestAssured.given;
import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.places.request.PlaceRequest;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

@QuarkusTest
class PlaceResourceTest extends AbstractResourceTest {

  @Inject ObjectMapper objectMapper;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  // ==================== List Places Tests ====================

  @Test
  void listPlaces_asAdmin_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(200)
        .body("places", is(notNullValue()))
        .body("total", greaterThanOrEqualTo(0))
        .body("page", equalTo(0))
        .body("size", equalTo(50));
  }

  @Test
  void listPlaces_asOrganizer_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(200)
        .body("places", is(notNullValue()));
  }

  @Test
  void listPlaces_asMember_shouldBeDenied() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(403);
  }

  @Test
  void listPlaces_withoutAuth_shouldReturn401() {
    given().when().get("/api/teams/" + team1Slug + "/places").then().statusCode(401);
  }

  @Test
  void listPlaces_asNonMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(403);
  }

  @Test
  void listPlaces_toNonexistentTeam_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/nonexistent-team/places")
        .then()
        .statusCode(404);
  }

  @Test
  void listPlaces_withSearch_shouldReturnFilteredResults() {
    dataService.createPlace(team1, user1, "Gare de Lyon");
    dataService.createPlace(team1, user1, "Place de la République");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("search", "gare")
        .when()
        .get("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(200)
        .body("places.size()", equalTo(1))
        .body("places[0].name", equalTo("Gare de Lyon"));
  }

  @Test
  void listPlaces_withFilterStart_shouldReturnOnlyStartPlaces() {
    dataService.createPlace(team1, user1, "Start Only", true, false);
    dataService.createPlace(team1, user1, "End Only", false, true);
    dataService.createPlace(team1, user1, "Both", true, true);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("filterStart", "true")
        .when()
        .get("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(200)
        .body("places.size()", equalTo(2))
        .body("places.startPlace", everyItem(equalTo(true)));
  }

  @Test
  void listPlaces_withFilterEnd_shouldReturnOnlyEndPlaces() {
    dataService.createPlace(team1, user1, "Start Only", true, false);
    dataService.createPlace(team1, user1, "End Only", false, true);
    dataService.createPlace(team1, user1, "Both", true, true);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("filterEnd", "true")
        .when()
        .get("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(200)
        .body("places.size()", equalTo(2))
        .body("places.endPlace", everyItem(equalTo(true)));
  }

  // ==================== Create Place Tests ====================

  @Test
  void createPlace_asAdmin_shouldSucceed() {
    PlaceRequest request = new PlaceRequest("Test Place", "123 Main St", null, true, false, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(201)
        .body("id", notNullValue())
        .body("name", equalTo("Test Place"))
        .body("address", equalTo("123 Main St"))
        .body("startPlace", equalTo(true))
        .body("endPlace", equalTo(false));
  }

  @Test
  void createPlace_asOrganizer_shouldSucceed() {
    PlaceRequest request = new PlaceRequest("Organizer Place", null, null, false, true, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(201)
        .body("name", equalTo("Organizer Place"));
  }

  @Test
  void createPlace_asMember_shouldBeDenied() {
    PlaceRequest request = new PlaceRequest("Member Place", null, null, true, true, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(403);
  }

  @Test
  void createPlace_withoutAuth_shouldReturn401() {
    PlaceRequest request = new PlaceRequest("Unauth Place", null, null, true, true, null);

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(401);
  }

  @Test
  void createPlace_asNonMember_shouldReturn403() {
    PlaceRequest request = new PlaceRequest("NonMember Place", null, null, true, true, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(403);
  }

  @Test
  void createPlace_withCoordinates_shouldSucceed() {
    Point<G2D> point = point(WGS84, g(2.3522, 48.8566));
    PlaceRequest request =
        new PlaceRequest("Paris Place", "Paris, France", null, true, true, point);

    String json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(request);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(json)
        .when()
        .post("/api/teams/" + team1Slug + "/places")
        .then()
        .statusCode(201)
        .body("name", equalTo("Paris Place"))
        .body("geometry", notNullValue());
  }

  @Test
  void createPlace_toNonexistentTeam_shouldReturn404() {
    PlaceRequest request = new PlaceRequest("Test Place", null, null, true, false, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/nonexistent-team/places")
        .then()
        .statusCode(404);
  }

  // ==================== Get Place Tests ====================

  @Test
  void getPlace_asAdmin_shouldSucceed() {
    // First create a place
    PlaceRequest request = new PlaceRequest("Get Test Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(request)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    // Then get it
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(200)
        .body("id", equalTo(placeId))
        .body("name", equalTo("Get Test Place"));
  }

  @Test
  void getPlace_asOrganizer_shouldSucceed() {
    PlaceRequest request = new PlaceRequest("Organizer Get Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(request)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(200)
        .body("name", equalTo("Organizer Get Place"));
  }

  @Test
  void getPlace_asMember_shouldBeDenied() {
    PlaceRequest request = new PlaceRequest("Member Get Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(request)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(403);
  }

  @Test
  void getPlace_nonexistent_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/places/" + TsidUtils.toString(1L))
        .then()
        .statusCode(403);
  }

  // ==================== Update Place Tests ====================

  @Test
  void updatePlace_asAdmin_shouldSucceed() {
    PlaceRequest createRequest = new PlaceRequest("Original Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    PlaceRequest updateRequest =
        new PlaceRequest(
            "Updated Place", "New Address", "https://maps.google.com", false, true, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(updateRequest)
        .when()
        .put("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Place"))
        .body("address", equalTo("New Address"))
        .body("link", equalTo("https://maps.google.com"))
        .body("startPlace", equalTo(false))
        .body("endPlace", equalTo(true));
  }

  @Test
  void updatePlace_asOrganizer_shouldSucceed() {
    PlaceRequest createRequest =
        new PlaceRequest("Organizer Update Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    PlaceRequest updateRequest =
        new PlaceRequest("Updated by Organizer", null, null, true, true, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(updateRequest)
        .when()
        .put("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated by Organizer"));
  }

  @Test
  void updatePlace_asMember_shouldBeDenied() {
    PlaceRequest createRequest =
        new PlaceRequest("Member Update Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    PlaceRequest updateRequest =
        new PlaceRequest("Hacked by Member", null, null, true, false, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(updateRequest)
        .when()
        .put("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(403);
  }

  @Test
  void updatePlace_nonexistent_shouldReturn403() {
    PlaceRequest updateRequest = new PlaceRequest("Nonexistent", null, null, true, false, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(updateRequest)
        .when()
        .put("/api/teams/" + team1Slug + "/places/" + TsidUtils.toString(1L))
        .then()
        .statusCode(403);
  }

  // ==================== Delete Place Tests ====================

  @Test
  void deletePlace_asAdmin_shouldSucceed() {
    PlaceRequest createRequest = new PlaceRequest("Delete Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(204);

    // Verify place is no longer accessible (403 for security by obscurity)
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(403);
  }

  @Test
  void deletePlace_asOrganizer_shouldSucceed() {
    PlaceRequest createRequest =
        new PlaceRequest("Organizer Delete Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(204);
  }

  @Test
  void deletePlace_asMember_shouldBeDenied() {
    PlaceRequest createRequest =
        new PlaceRequest("Member Delete Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .delete("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(403);
  }

  @Test
  void deletePlace_asNonMember_shouldReturn403() {
    PlaceRequest createRequest =
        new PlaceRequest("NonMember Delete Place", null, null, true, false, null);

    String placeId =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/places")
            .then()
            .statusCode(201)
            .extract()
            .path("id");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .delete("/api/teams/" + team1Slug + "/places/" + placeId)
        .then()
        .statusCode(403);
  }

  @Test
  void deletePlace_nonexistent_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/places/" + TsidUtils.toString(1L))
        .then()
        .statusCode(403);
  }
}
