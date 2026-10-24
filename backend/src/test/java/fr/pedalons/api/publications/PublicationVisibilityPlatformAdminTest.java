package fr.pedalons.api.publications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * What a platform admin's lists show (ledger API-137): a cross-team listing, or any listing with
 * {@code minRole}, follows their real membership; the lists of the one team they open, and any
 * detail, keep the full view moderation needs.
 */
@QuarkusTest
class PublicationVisibilityPlatformAdminTest extends AbstractResourceTest {

  private static final String ROOT = "root";

  private User root;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    root = dataService.createPlatformAdminUser("root@example.com", "Root");
    Instant next = Instant.now().plus(7, ChronoUnit.DAYS);
    // team1 is PUBLIC, team2 is TEAM-only; root belongs to neither.
    dataService.createRide(
        team1, user1, "Public", "public-ride", next, Visibility.PUBLIC, Status.PUBLISHED);
    dataService.createRide(
        team1, user1, "Draft", "draft-ride", next, Visibility.PUBLIC, Status.DRAFT);
    dataService.createRide(
        team1, user1, "Members", "members-ride", next, Visibility.TEAM, Status.PUBLISHED);
    Ride hidden =
        dataService.createRide(
            team1, user1, "Hidden", "hidden-ride", next, Visibility.PUBLIC, Status.PUBLISHED);
    dataService.hideForModeration(hidden);
    dataService.createRide(
        team2, user1, "Private", "private-ride", next, Visibility.TEAM, Status.PUBLISHED);
    dataService.createRide(
        team2, user1, "Private Draft", "private-draft", next, Visibility.TEAM, Status.DRAFT);
  }

  private ValidatableResponse list(String path, String minRole) {
    var request = given().auth().oauth2(getAccessToken(ROOT)).queryParam("size", 50);
    if (minRole != null) {
      request = request.queryParam("minRole", minRole);
    }
    return request.when().get(path).then().statusCode(200);
  }

  @Test
  void listAll_asPlatformAdminNonMember_shouldNotReturnDraftsPrivateOrHidden() {
    list("/api/publications", null)
        .body("publications.slug", hasItem("public-ride"))
        .body(
            "publications.slug",
            not(
                anyOf(
                    hasItem("draft-ride"),
                    hasItem("members-ride"),
                    hasItem("hidden-ride"),
                    hasItem("private-ride"),
                    hasItem("private-draft"))));
  }

  @Test
  void listAll_minRoleMember_asPlatformAdminMember_shouldNotReturnDrafts() {
    dataService.addUserToTeam(root, team1, TeamRole.MEMBER);

    list("/api/publications", "MEMBER")
        .body("publications.slug", hasItems("public-ride", "members-ride"))
        .body(
            "publications.slug",
            not(
                anyOf(
                    hasItem("draft-ride"),
                    hasItem("hidden-ride"),
                    hasItem("private-ride"),
                    hasItem("private-draft"))));
  }

  @Test
  void listTeam_asPlatformAdmin_shouldStillReturnDrafts() {
    list("/api/teams/" + team1Slug + "/publications", null)
        .body(
            "publications.slug",
            hasItems("public-ride", "draft-ride", "members-ride", "hidden-ride"));
    list("/api/teams/" + team2Slug + "/publications", null)
        .body("publications.slug", hasItems("private-ride", "private-draft"));
  }

  @Test
  void getBySlug_asPlatformAdmin_draftOfForeignTeam_isReadable() {
    given()
        .auth()
        .oauth2(getAccessToken(ROOT))
        .when()
        .get("/api/teams/" + team2Slug + "/rides/private-draft")
        .then()
        .statusCode(200)
        .body("slug", equalTo("private-draft"));
  }
}
