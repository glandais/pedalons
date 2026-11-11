package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.admin.AdminTeamAttributesRequest;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AdminTeamResourceTest extends AbstractResourceTest {

  private User platformAdmin;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    platformAdmin = dataService.createPlatformAdminUser("admin@example.com", "Platform Admin");
  }

  private String platformAdminToken() {
    return jwtService.generateAccessToken(platformAdmin);
  }

  // ==================== Update Team Attributes ====================

  @Test
  void updateTeamAttributes_asAdmin_shouldSucceed() {
    String teamId = TsidUtils.toString(team1.getId());
    AdminTeamAttributesRequest request =
        new AdminTeamAttributesRequest(true, true, true, true, true);

    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(request)
        .when()
        .patch("/api/admin/teams/" + teamId + "/attributes")
        .then()
        .statusCode(200)
        .body("visibilityEditable", equalTo(true))
        .body("joinable", equalTo(true))
        .body("addMemberAllowed", equalTo(true))
        .body("enableRoutePlanner", equalTo(true))
        .body("publicContentAllowed", equalTo(true));
  }

  @Test
  void updateTeamAttributes_asNonAdmin_shouldReturn403() {
    String teamId = TsidUtils.toString(team1.getId());
    AdminTeamAttributesRequest request =
        new AdminTeamAttributesRequest(true, true, true, true, true);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .patch("/api/admin/teams/" + teamId + "/attributes")
        .then()
        .statusCode(403);
  }

  @Test
  void updateTeamAttributes_withUnknownId_shouldReturn404() {
    // TSID for Long value 1 — valid format but never matches a real team
    String nonExistentId = TsidUtils.toString(1L);
    AdminTeamAttributesRequest request =
        new AdminTeamAttributesRequest(false, false, false, false, false);

    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(request)
        .when()
        .patch("/api/admin/teams/" + nonExistentId + "/attributes")
        .then()
        .statusCode(404)
        .body("code", equalTo("TEAM_NOT_FOUND"));
  }

  @Test
  void updateTeamAttributes_shouldPersistChanges() {
    String teamId = TsidUtils.toString(team1.getId());

    // Set all to true
    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(new AdminTeamAttributesRequest(true, true, true, true, true))
        .when()
        .patch("/api/admin/teams/" + teamId + "/attributes")
        .then()
        .statusCode(200);

    // Verify via GET that changes persisted
    given()
        .auth()
        .oauth2(platformAdminToken())
        .when()
        .get("/api/admin/teams/" + teamId)
        .then()
        .statusCode(200)
        .body("visibilityEditable", equalTo(true))
        .body("joinable", equalTo(true))
        .body("addMemberAllowed", equalTo(true))
        .body("enableRoutePlanner", equalTo(true))
        .body("publicContentAllowed", equalTo(true));
  }

  /** Off for every team until the platform admin turns it on (docs/LEDGER_*.md API-176). */
  @Test
  void publicContentAllowed_isOffByDefault() {
    given()
        .auth()
        .oauth2(platformAdminToken())
        .when()
        .get("/api/admin/teams/" + TsidUtils.toString(team1.getId()))
        .then()
        .statusCode(200)
        .body("publicContentAllowed", equalTo(false));
  }

  /**
   * A client unaware of the flag omits it: the save of the other attributes must leave it as it is,
   * never withdraw it (docs/LEDGER_*.md API-176).
   */
  @Test
  void updateTeamAttributes_withoutPublicContentAllowed_keepsIt() {
    dataService.setTeamPublicContentAllowed(team1, true);
    String teamId = TsidUtils.toString(team1.getId());

    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(
            "{\"visibilityEditable\":false,\"joinable\":false,\"addMemberAllowed\":false,"
                + "\"enableRoutePlanner\":false}")
        .when()
        .patch("/api/admin/teams/" + teamId + "/attributes")
        .then()
        .statusCode(200)
        .body("joinable", equalTo(false))
        .body("publicContentAllowed", equalTo(true));
  }

  /**
   * The planner flag is platform-admin territory: it must not ride in on the team's own update
   * payload, which a team admin controls.
   */
  @Test
  void updateTeam_asTeamAdmin_shouldNotChangeEnableRoutePlanner() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            """
            {
              "name": "Team 1",
              "media": {"markdown": "", "assets": {"images": [], "attachments": []}},
              "visibility": "PUBLIC",
              "enableTrips": true,
              "enableAds": true,
              "enablePosts": true,
              "enableRides": true,
              "enableRoutes": true,
              "enableRoutePlanner": true
            }
            """)
        .when()
        .put("/api/teams/" + team1.getSlug())
        .then()
        .statusCode(200)
        .body("enableRoutePlanner", equalTo(false));
  }

  @Test
  void updateTeamAttributes_unauthenticated_shouldReturn401() {
    String teamId = TsidUtils.toString(team1.getId());
    AdminTeamAttributesRequest request =
        new AdminTeamAttributesRequest(true, true, true, true, true);

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .patch("/api/admin/teams/" + teamId + "/attributes")
        .then()
        .statusCode(401);
  }

  // ==================== Archived teams ====================

  @Test
  void anArchivedTeamStaysListedAndReadable_soItCanBeRestored() {
    String teamId = TsidUtils.toString(team1.getId());
    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .when()
        .post("/api/admin/teams/" + teamId + "/toggle-deleted")
        .then()
        .statusCode(200)
        .body("deleted", equalTo(true));

    given()
        .auth()
        .oauth2(platformAdminToken())
        .queryParam("size", 100)
        .when()
        .get("/api/admin/teams")
        .then()
        .statusCode(200)
        .body("teams.find { it.id == '" + teamId + "' }.deleted", equalTo(true));

    given()
        .auth()
        .oauth2(platformAdminToken())
        .when()
        .get("/api/admin/teams/" + teamId)
        .then()
        .statusCode(200)
        .body("deleted", equalTo(true));
  }
}
