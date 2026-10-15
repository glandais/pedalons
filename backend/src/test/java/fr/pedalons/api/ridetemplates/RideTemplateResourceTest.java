package fr.pedalons.api.ridetemplates;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.ridetemplates.request.RideTemplateGroupRequest;
import fr.pedalons.dto.ridetemplates.request.RideTemplateRequest;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class RideTemplateResourceTest extends AbstractResourceTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private RideTemplateRequest createValidRequest(String name) {
    return new RideTemplateRequest(
        name,
        "Template description in **markdown**",
        Visibility.TEAM,
        Status.PUBLISHED,
        List.of(
            RideTemplateGroupRequest.builder()
                .name("Group A")
                .averageSpeed(25.0f)
                .maxParticipants(20)
                .build(),
            RideTemplateGroupRequest.builder()
                .name("Group B")
                .averageSpeed(30.0f)
                .maxParticipants(15)
                .build()));
  }

  // ==================== List Templates Tests ====================

  @Test
  void listTemplates_asAdmin_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(200)
        .body("templates", is(notNullValue()))
        .body("total", greaterThanOrEqualTo(0))
        .body("page", equalTo(0))
        .body("size", equalTo(20));
  }

  @Test
  void listTemplates_asOrganizer_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(200)
        .body("templates", is(notNullValue()));
  }

  @Test
  void listTemplates_asMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(403);
  }

  @Test
  void listTemplates_withoutAuth_shouldReturn401() {
    given().when().get("/api/teams/" + team1Slug + "/ride-templates").then().statusCode(401);
  }

  @Test
  void listTemplates_asNonMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(403);
  }

  @Test
  void listTemplates_toNonexistentTeam_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/nonexistent-team/ride-templates")
        .then()
        .statusCode(404);
  }

  @Test
  void listTemplates_withSearch_shouldSucceed() {
    // Create a template first
    RideTemplateRequest request = createValidRequest("Searchable Template");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(201);

    // Search for it
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("search", "Searchable")
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(200)
        .body("templates", is(notNullValue()));
  }

  // ==================== Next number (docs/LEDGER_*.md API-108) ====================

  private String createNumberedTemplate(String name, @Nullable Integer nextNumber) {
    RideTemplateRequest base = createValidRequest(name);
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new RideTemplateRequest(
                base.name(),
                base.markdown(),
                base.visibility(),
                base.status(),
                base.groups(),
                null,
                nextNumber))
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(201)
        .body("nextNumber", nextNumber == null ? nullValue() : equalTo(nextNumber))
        .extract()
        .path("slug");
  }

  private void createRideFrom(String teamSlug, @Nullable String templateId) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new RideRequest(
                "Sortie numérotée",
                MediaDto.builder().build(),
                wall(Instant.now().plus(3, ChronoUnit.DAYS)),
                Status.PUBLISHED,
                Visibility.TEAM,
                null,
                null,
                null,
                null,
                List.of(new GroupRequest(null, "A", null, null, null, null)),
                null,
                templateId))
        .when()
        .post("/api/teams/" + teamSlug + "/rides")
        .then()
        .statusCode(201);
  }

  private ValidatableResponse getTemplateResponse(String slug) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates/" + slug)
        .then()
        .statusCode(200);
  }

  @Test
  void nextNumber_isRaisedByEachRideCreatedFromTheTemplate() {
    String slug = createNumberedTemplate("Jeudi", 41);
    String id = getTemplateResponse(slug).extract().path("id");

    createRideFrom(team1Slug, id);
    createRideFrom(team1Slug, id);
    // A ride created without the template leaves its number alone.
    createRideFrom(team1Slug, null);

    getTemplateResponse(slug).body("nextNumber", equalTo(43));
  }

  @Test
  void nextNumber_null_staysNullWhenARideIsCreatedFromTheTemplate() {
    String slug = createNumberedTemplate("Samedi", null);
    String id = getTemplateResponse(slug).extract().path("id");

    createRideFrom(team1Slug, id);

    getTemplateResponse(slug).body("nextNumber", nullValue());
  }

  @Test
  void nextNumber_isNotRaisedByARideOfAnotherTeam() {
    String slug = createNumberedTemplate("Dimanche", 7);
    String id = getTemplateResponse(slug).extract().path("id");

    // USER1 can create rides in team2 too, but the template is team1's.
    createRideFrom(team2Slug, id);

    getTemplateResponse(slug).body("nextNumber", equalTo(7));
  }

  @Test
  void nextNumber_negative_shouldReturn400() {
    RideTemplateRequest base = createValidRequest("Négatif");
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new RideTemplateRequest(
                base.name(),
                base.markdown(),
                base.visibility(),
                base.status(),
                base.groups(),
                null,
                -1))
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(400);
  }

  // ==================== Create Template Tests ====================

  @Test
  void createTemplate_asAdmin_shouldSucceed() {
    RideTemplateRequest request = createValidRequest("Admin Template");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(201)
        .body("slug", notNullValue())
        .body("name", equalTo("Admin Template"))
        .body("markdown", equalTo("Template description in **markdown**"))
        .body("visibility", equalTo("TEAM"))
        .body("status", equalTo("PUBLISHED"))
        .body("groups", hasSize(2))
        .body("groups[0].name", equalTo("Group A"))
        .body("groups[0].averageSpeed", equalTo(25.0f))
        .body("groups[0].maxParticipants", equalTo(20))
        .body("groups[1].name", equalTo("Group B"));
  }

  @Test
  void createTemplate_asOrganizer_shouldSucceed() {
    RideTemplateRequest request = createValidRequest("Organizer Template");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(201)
        .body("name", equalTo("Organizer Template"));
  }

  @Test
  void createTemplate_asMember_shouldBeDenied() {
    RideTemplateRequest request = createValidRequest("Member Template");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(403);
  }

  @Test
  void createTemplate_withoutAuth_shouldReturn401() {
    RideTemplateRequest request = createValidRequest("Unauth Template");

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(401);
  }

  @Test
  void createTemplate_asNonMember_shouldReturn403() {
    RideTemplateRequest request = createValidRequest("NonMember Template");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(403);
  }

  @Test
  void createTemplate_toNonexistentTeam_shouldReturn404() {
    RideTemplateRequest request = createValidRequest("Test Template");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/nonexistent-team/ride-templates")
        .then()
        .statusCode(404);
  }

  @Test
  void createTemplate_withEmptyGroups_shouldSucceed() {
    RideTemplateRequest request =
        new RideTemplateRequest("No Groups Template", "", Visibility.TEAM, Status.DRAFT, List.of());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(201)
        .body("name", equalTo("No Groups Template"))
        .body("groups", hasSize(0));
  }

  /** docs/LEDGER_*.md SEC-19: a template's markdown has the same bound as a content's. */
  @Test
  void createTemplate_markdownPastTheBound_shouldReturn400() {
    RideTemplateRequest valid = createValidRequest("Too Long Template");
    RideTemplateRequest request =
        new RideTemplateRequest(
            valid.name(),
            "a".repeat(MediaDto.MAX_MARKDOWN_LENGTH + 1),
            valid.visibility(),
            valid.status(),
            valid.groups());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/ride-templates")
        .then()
        .statusCode(400)
        .body("code", equalTo("VALIDATION"))
        .body("errorDetails.fieldErrors.field", hasItem("markdown"));
  }

  // ==================== Get Template Tests ====================

  @Test
  void getTemplate_asAdmin_shouldSucceed() {
    RideTemplateRequest request = createValidRequest("Get Test Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(request)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(200)
        .body("slug", equalTo(templateSlug))
        .body("name", equalTo("Get Test Template"));
  }

  @Test
  void getTemplate_asOrganizer_shouldSucceed() {
    RideTemplateRequest request = createValidRequest("Organizer Get Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(request)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Organizer Get Template"));
  }

  @Test
  void getTemplate_asMember_shouldReturn403() {
    RideTemplateRequest request = createValidRequest("Member Get Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(request)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void getTemplate_nonexistent_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates/nonexistent-slug")
        .then()
        .statusCode(403);
  }

  @Test
  void getTemplate_asNonMember_shouldReturn403() {
    RideTemplateRequest request = createValidRequest("NonMember Get Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(request)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(403);
  }

  // ==================== Update Template Tests ====================

  @Test
  void updateTemplate_asAdmin_shouldSucceed() {
    RideTemplateRequest createRequest = createValidRequest("Original Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    RideTemplateRequest updateRequest =
        new RideTemplateRequest(
            "Updated Template",
            "New description",
            Visibility.PUBLIC,
            Status.DRAFT,
            List.of(
                RideTemplateGroupRequest.builder()
                    .name("Updated Group")
                    .averageSpeed(35.0f)
                    .maxParticipants(10)
                    .build()));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(updateRequest)
        .when()
        .put("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Template"))
        .body("markdown", equalTo("New description"))
        .body("visibility", equalTo("PUBLIC"))
        .body("status", equalTo("DRAFT"))
        .body("groups", hasSize(1))
        .body("groups[0].name", equalTo("Updated Group"));
  }

  @Test
  void updateTemplate_asOrganizer_shouldSucceed() {
    RideTemplateRequest createRequest = createValidRequest("Organizer Update Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    RideTemplateRequest updateRequest =
        new RideTemplateRequest(
            "Updated by Organizer", "", Visibility.TEAM, Status.PUBLISHED, List.of());

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(updateRequest)
        .when()
        .put("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated by Organizer"));
  }

  @Test
  void updateTemplate_asMember_shouldBeDenied() {
    RideTemplateRequest createRequest = createValidRequest("Member Update Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    RideTemplateRequest updateRequest =
        new RideTemplateRequest(
            "Hacked by Member", "", Visibility.TEAM, Status.PUBLISHED, List.of());

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(updateRequest)
        .when()
        .put("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void updateTemplate_nonexistent_shouldReturn403() {
    RideTemplateRequest updateRequest =
        new RideTemplateRequest("Nonexistent", "", Visibility.TEAM, Status.PUBLISHED, List.of());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(updateRequest)
        .when()
        .put("/api/teams/" + team1Slug + "/ride-templates/nonexistent-slug")
        .then()
        .statusCode(403);
  }

  // ==================== Delete Template Tests ====================

  @Test
  void deleteTemplate_asAdmin_shouldSucceed() {
    RideTemplateRequest createRequest = createValidRequest("Delete Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(204);

    // Verify template is no longer accessible (403 for security by obscurity)
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void deleteTemplate_asOrganizer_shouldSucceed() {
    RideTemplateRequest createRequest = createValidRequest("Organizer Delete Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(204);
  }

  @Test
  void deleteTemplate_asMember_shouldBeDenied() {
    RideTemplateRequest createRequest = createValidRequest("Member Delete Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .delete("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void deleteTemplate_asNonMember_shouldReturn403() {
    RideTemplateRequest createRequest = createValidRequest("NonMember Delete Template");

    String templateSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(createRequest)
            .when()
            .post("/api/teams/" + team1Slug + "/ride-templates")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .delete("/api/teams/" + team1Slug + "/ride-templates/" + templateSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void deleteTemplate_nonexistent_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/ride-templates/nonexistent-slug")
        .then()
        .statusCode(403);
  }
}
