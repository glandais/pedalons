package fr.pedalons.api.teams;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.teams.request.TeamRequest;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamMembershipResourceTest extends AbstractResourceTest {

  // USER4 and USER5 have no existing admin teams after setUp(), so they can create teams via API
  // without hitting the USER_TEAM_LIMIT_REACHED constraint. USER1 is already admin of team1 and
  // team2 created in setUp() and cannot create additional teams.

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  /** Creates a team via API (TEAM visibility, as required on creation) and returns the slug. */
  private String createTeamViaApi(String creatorUser) {
    TeamRequest teamRequest =
        new TeamRequest(
            "Team",
            MediaDto.builder().build(),
            Visibility.TEAM,
            true,
            true,
            true,
            true,
            true,
            false,
            null,
            null,
            null);
    return given()
        .auth()
        .oauth2(getAccessToken(creatorUser))
        .contentType("application/json")
        .body(teamRequest)
        .when()
        .post("/api/teams")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  private void enableJoin(String slug) {
    Team team = dataService.findTeamBySlug(domain, slug);
    dataService.setTeamVisibility(team, Visibility.PUBLIC);
    dataService.setTeamJoinable(team, true);
  }

  private void enableAddMember(String slug) {
    Team team = dataService.findTeamBySlug(domain, slug);
    dataService.setTeamAddMemberAllowed(team, true);
  }

  // ==================== Join Team ====================

  @Test
  void joinTeam_alreadyMember_shouldReturn409() {
    String slug = createTeamViaApi(USER4);
    enableJoin(slug);

    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(409)
        .body("code", equalTo("ALREADY_REGISTERED"));
  }

  @Test
  void joinTeam_whenNotJoinable_shouldReturn403() {
    String slug = createTeamViaApi(USER4);
    // A new team is born joinable (docs/LEDGER_*.md BILL-10): a public team the platform admin
    // closed.
    Team team = dataService.findTeamBySlug(domain, slug);
    dataService.setTeamVisibility(team, Visibility.PUBLIC);
    dataService.setTeamJoinable(team, false);

    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(403)
        .body("code", equalTo("FORBIDDEN"));
  }

  // ==================== Member Role ====================

  @Test
  void updateMemberRole_asAdmin_shouldSucceed() {
    String slug = createTeamViaApi(USER4);
    enableJoin(slug);

    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body("{\"role\": \"ADMIN\"}")
        .when()
        .put("/api/teams/" + slug + "/members/" + TsidUtils.toString(user5.getId()))
        .then()
        .statusCode(200)
        .body("role", equalTo("ADMIN"));
  }

  @Test
  void updateMemberRole_asMember_shouldBeDenied() {
    String slug = createTeamViaApi(USER4);
    enableJoin(slug);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body("{\"role\": \"ADMIN\"}")
        .when()
        .put("/api/teams/" + slug + "/members/" + TsidUtils.toString(user5.getId()))
        .then()
        .statusCode(403);
  }

  // ==================== Remove Member ====================

  @Test
  void removeMember_asAdmin_shouldSucceed() {
    String slug = createTeamViaApi(USER4);
    enableJoin(slug);

    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .delete("/api/teams/" + slug + "/members/" + TsidUtils.toString(user5.getId()))
        .then()
        .statusCode(204);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + slug + "/members")
        .then()
        .statusCode(200)
        .body("total", equalTo(1));
  }

  @Test
  void removeMember_asMember_shouldBeDenied() {
    String slug = createTeamViaApi(USER4);
    enableJoin(slug);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/teams/" + slug + "/members/" + TsidUtils.toString(user5.getId()))
        .then()
        .statusCode(403);
  }

  @Test
  void removeLastAdmin_shouldBeDenied() {
    String slug = createTeamViaApi(USER4);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/leave")
        .then()
        .statusCode(400)
        .body("code", equalTo("LAST_ADMIN"));
  }

  @Test
  void demoteLastAdmin_shouldBeDenied() {
    String slug = createTeamViaApi(USER4);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body("{\"role\": \"MEMBER\"}")
        .when()
        .put("/api/teams/" + slug + "/members/" + TsidUtils.toString(user4.getId()))
        .then()
        .statusCode(400)
        .body("code", equalTo("LAST_ADMIN"));
  }

  // ==================== Add Member ====================

  @Test
  void addMember_byAdmin_shouldSucceed() {
    String slug = createTeamViaApi(USER4);
    enableAddMember(slug);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body("{\"userId\": \"" + TsidUtils.toString(user5.getId()) + "\", \"role\": \"MEMBER\"}")
        .when()
        .post("/api/teams/" + slug + "/members")
        .then()
        .statusCode(201)
        .body("role", equalTo("MEMBER"));

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + slug + "/members")
        .then()
        .statusCode(200)
        .body("total", equalTo(2));
  }

  @Test
  void addMember_whenNotAllowed_shouldReturn400() {
    String slug = createTeamViaApi(USER4);
    // A new team is born open (docs/LEDGER_*.md BILL-10): the platform admin closed this one.
    dataService.setTeamAddMemberAllowed(dataService.findTeamBySlug(domain, slug), false);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body("{\"userId\": \"" + TsidUtils.toString(user5.getId()) + "\", \"role\": \"MEMBER\"}")
        .when()
        .post("/api/teams/" + slug + "/members")
        .then()
        .statusCode(400)
        .body("code", equalTo("TEAM_ADD_MEMBER_NOT_ALLOWED"));
  }

  // ==================== Pagination ====================

  @Test
  void getTeamMembers_withPagination_shouldWork() {
    String slug = createTeamViaApi(USER4);
    enableJoin(slug);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + slug + "/members/join")
        .then()
        .statusCode(201);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .queryParam("page", 0)
        .queryParam("size", 2)
        .when()
        .get("/api/teams/" + slug + "/members")
        .then()
        .statusCode(200)
        .body("members", hasSize(2))
        .body("total", equalTo(3))
        .body("page", equalTo(0))
        .body("size", equalTo(2));

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .queryParam("page", 1)
        .queryParam("size", 2)
        .when()
        .get("/api/teams/" + slug + "/members")
        .then()
        .statusCode(200)
        .body("members", hasSize(1))
        .body("total", equalTo(3));
  }

  // ==================== Team Creation Limit ====================

  @Test
  void createTeam_shouldEnforceOneTeamLimitPerUser() {
    // USER1 is already admin of team1 and team2 (from setUp), so creating another should fail
    TeamRequest teamRequest =
        new TeamRequest(
            "Third Team",
            MediaDto.builder().build(),
            Visibility.TEAM,
            true,
            true,
            true,
            true,
            true,
            false,
            null,
            null,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(teamRequest)
        .when()
        .post("/api/teams")
        .then()
        .statusCode(400)
        .body("code", equalTo("USER_TEAM_LIMIT_REACHED"));
  }
}
