package fr.pedalons.api.pages;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.pages.request.ReorderPagesRequest;
import fr.pedalons.dto.pages.request.TeamPageRequest;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamPageResourceTest extends AbstractResourceTest {

  private TeamPage page;
  private String pageSlug;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    page = dataService.createAdditionalPage(team1, user1, "Test Page", 1, Visibility.PUBLIC);
    pageSlug = page.getSlug();
  }

  private TeamPageRequest createPageRequest(String title) {
    return new TeamPageRequest(
        title, MediaDto.builder().markdown("Page content").build(), Visibility.PUBLIC);
  }

  // ==================== List Pages ====================

  @Test
  void listPages_asAdmin_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/pages")
        .then()
        .statusCode(200)
        .body("size()", greaterThanOrEqualTo(1));
  }

  @Test
  void listPages_asMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/pages")
        .then()
        .statusCode(403);
  }

  @Test
  void listPages_withoutAuth_shouldReturn403() {
    given().when().get("/api/teams/" + team1Slug + "/pages").then().statusCode(403);
  }

  // ==================== Get Page ====================

  @Test
  void getPage_asAnonymous_onPublicPage_shouldSucceed() {
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/pages/" + pageSlug)
        .then()
        .statusCode(200)
        .body("title", equalTo("Test Page"))
        .body("slug", equalTo(pageSlug));
  }

  @Test
  void getPage_asMember_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/pages/" + pageSlug)
        .then()
        .statusCode(200)
        .body("title", equalTo("Test Page"));
  }

  @Test
  void getPage_nonexistent_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/pages/nonexistent-page")
        .then()
        .statusCode(404);
  }

  @Test
  void getPage_teamVisibility_asMember_shouldSucceed() {
    TeamPage teamPage =
        dataService.createAdditionalPage(team1, user1, "Team Page", 2, Visibility.TEAM);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/pages/" + teamPage.getSlug())
        .then()
        .statusCode(200)
        .body("title", equalTo("Team Page"));
  }

  @Test
  void getPage_teamVisibility_asNonMember_shouldReturn404() {
    TeamPage teamPage =
        dataService.createAdditionalPage(team1, user1, "Team Page", 2, Visibility.TEAM);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug + "/pages/" + teamPage.getSlug())
        .then()
        .statusCode(404);
  }

  // ==================== Create Page ====================

  @Test
  void createPage_asAdmin_shouldSucceed() {
    TeamPageRequest request = createPageRequest("New Page");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/pages")
        .then()
        .statusCode(201)
        .body("title", equalTo("New Page"))
        .body("slug", notNullValue());
  }

  @Test
  void createPage_asMember_shouldReturn403() {
    TeamPageRequest request = createPageRequest("Member Page");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/pages")
        .then()
        .statusCode(403);
  }

  @Test
  void createPage_withoutAuth_shouldReturn401() {
    TeamPageRequest request = createPageRequest("Unauth Page");

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/pages")
        .then()
        .statusCode(401);
  }

  @Test
  void createPage_asNonMember_shouldReturn403() {
    TeamPageRequest request = createPageRequest("NonMember Page");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/pages")
        .then()
        .statusCode(403);
  }

  @Test
  void createPage_exceedingMax_shouldReturn400() {
    // Create 2 more pages (already have 1 from setUp, max is 3)
    dataService.createAdditionalPage(team1, user1, "Page 2", 2);
    dataService.createAdditionalPage(team1, user1, "Page 3", 3);

    TeamPageRequest request = createPageRequest("Page 4");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/pages")
        .then()
        .statusCode(400);
  }

  // ==================== Update Page ====================

  @Test
  void updatePage_asAdmin_shouldSucceed() {
    TeamPageRequest request =
        new TeamPageRequest(
            "Updated Page",
            MediaDto.builder().markdown("Updated content").build(),
            Visibility.TEAM);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/pages/" + pageSlug)
        .then()
        .statusCode(200)
        .body("title", equalTo("Updated Page"))
        .body("visibility", equalTo("TEAM"));
  }

  @Test
  void updatePage_asMember_shouldReturn403() {
    TeamPageRequest request = createPageRequest("Hacked Page");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/pages/" + pageSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void updatePage_withoutAuth_shouldReturn401() {
    TeamPageRequest request = createPageRequest("Unauth Page");

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/pages/" + pageSlug)
        .then()
        .statusCode(401);
  }

  @Test
  void updatePage_aboutPage_shouldReturn403() {
    TeamPageRequest request = createPageRequest("Hacked About");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/pages/about")
        .then()
        .statusCode(403);
  }

  // ==================== Delete Page ====================

  @Test
  void deletePage_asAdmin_shouldSucceed() {
    TeamPage toDelete = dataService.createAdditionalPage(team1, user1, "To Delete", 2);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/pages/" + toDelete.getSlug())
        .then()
        .statusCode(204);

    // Verify deletion
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/pages/" + toDelete.getSlug())
        .then()
        .statusCode(404);
  }

  @Test
  void undeletePage_atMax_shouldReturn400() {
    // setUp has 1 page; bin a second one, then fill the cap of 3 with two more.
    TeamPage binned = dataService.createAdditionalPage(team1, user1, "In The Bin", 2);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/pages/" + binned.getSlug())
        .then()
        .statusCode(204);
    dataService.createAdditionalPage(team1, user1, "Page 2", 3);
    dataService.createAdditionalPage(team1, user1, "Page 3", 4);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/pages/" + binned.getSlug() + "/undelete")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOO_MANY_TEAM_PAGES"));
  }

  @Test
  void deletePage_asMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .delete("/api/teams/" + team1Slug + "/pages/" + pageSlug)
        .then()
        .statusCode(403);
  }

  @Test
  void deletePage_withoutAuth_shouldReturn401() {
    given().when().delete("/api/teams/" + team1Slug + "/pages/" + pageSlug).then().statusCode(401);
  }

  @Test
  void deletePage_aboutPage_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/pages/about")
        .then()
        .statusCode(403);
  }

  // ==================== Reorder Pages ====================

  @Test
  void reorderPages_asAdmin_shouldSucceed() {
    TeamPage page2 = dataService.createAdditionalPage(team1, user1, "Page 2", 2);
    TeamPage page3 = dataService.createAdditionalPage(team1, user1, "Page 3", 3);

    // Reverse order
    ReorderPagesRequest request =
        new ReorderPagesRequest(
            List.of(
                TsidUtils.toString(page3.getId()),
                TsidUtils.toString(page2.getId()),
                TsidUtils.toString(page.getId())));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/pages/reorder")
        .then()
        .statusCode(200)
        .body("size()", equalTo(3))
        .body("[0].title", equalTo("Page 3"));
  }

  @Test
  void reorderPages_asMember_shouldReturn403() {
    ReorderPagesRequest request =
        new ReorderPagesRequest(List.of(TsidUtils.toString(page.getId())));

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/pages/reorder")
        .then()
        .statusCode(403);
  }

  @Test
  void reorderPages_withoutAuth_shouldReturn401() {
    ReorderPagesRequest request =
        new ReorderPagesRequest(List.of(TsidUtils.toString(page.getId())));

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/pages/reorder")
        .then()
        .statusCode(401);
  }

  // ==================== Change Slug ====================

  @Test
  void changeSlug_asAdmin_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("new-page-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/pages/" + pageSlug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("new-page-slug"));
  }

  @Test
  void changeSlug_asMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(new SlugChangeRequest("hacked-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/pages/" + pageSlug + "/slug")
        .then()
        .statusCode(403);
  }

  @Test
  void changeSlug_withoutAuth_shouldReturn401() {
    given()
        .contentType("application/json")
        .body(new SlugChangeRequest("unauth-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/pages/" + pageSlug + "/slug")
        .then()
        .statusCode(401);
  }

  @Test
  void changeSlug_invalidFormat_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("Invalid Slug!"))
        .when()
        .patch("/api/teams/" + team1Slug + "/pages/" + pageSlug + "/slug")
        .then()
        .statusCode(400);
  }

  /**
   * "reorder" is the literal path segment {@code PUT /api/teams/{teamSlug}/pages/reorder} declares
   * alongside {@code PUT /{pageSlug}} — a page slugged that would be permanently shadowed by the
   * reorder endpoint. Rejected with the same 409 shape as a genuine slug-uniqueness conflict.
   */
  @Test
  void changeSlug_toReorder_shouldReturn409() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("reorder"))
        .when()
        .patch("/api/teams/" + team1Slug + "/pages/" + pageSlug + "/slug")
        .then()
        .statusCode(409);
  }

  /**
   * A page named so its slugified form collides with "reorder" is auto-suffixed on creation,
   * exactly like a genuine slug collision — see {@code SlugService.generateSlug}.
   */
  @Test
  void createPage_namedReorder_shouldSuffixIt() {
    TeamPageRequest request = createPageRequest("Reorder");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/pages")
        .then()
        .statusCode(201)
        .body("slug", equalTo("reorder-1"));
  }
}
