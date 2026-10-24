package fr.pedalons.api.teams;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.teams.request.TeamRequest;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.migration.live.BiketeamTestData;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.team.TeamService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamResourceTest extends AbstractResourceTest {

  @Inject TeamService teamService;
  @Inject PedalonsQueryContext queryContext;
  @Inject BiketeamTestData biketeamData;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  @Test
  void listPublicTeams_shouldReturnEmptyList() {
    given()
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams", is(notNullValue()))
        .body("total", greaterThanOrEqualTo(0))
        .body("page", equalTo(0))
        .body("size", equalTo(20));
  }

  @Test
  void listPublicTeams_shouldSupportPagination() {
    given()
        .queryParam("page", 1)
        .queryParam("size", 10)
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("page", equalTo(1))
        .body("size", equalTo(10));
  }

  @Test
  void listPublicTeams_shouldSupportSearch() {
    given()
        .queryParam("search", "cycling")
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams", is(notNullValue()));
  }

  /**
   * {@code sortBy=MEMBER_COUNT} orders the directory by the member count the rows carry, and the
   * team id ends the key: three teams tied on one member come back in id order, the same on every
   * page, so paging one row at a time neither repeats nor skips one of them.
   */
  @Test
  void listTeams_sortByMemberCount_isTotalAcrossPages() {
    Team big = dataService.createTeam(user1, "Tri Grande", "tri-grande", Visibility.PUBLIC);
    dataService.addUserToTeam(user2, big, TeamRole.MEMBER);
    dataService.addUserToTeam(user3, big, TeamRole.MEMBER);
    Team medium = dataService.createTeam(user1, "Tri Moyenne", "tri-moyenne", Visibility.PUBLIC);
    dataService.addUserToTeam(user2, medium, TeamRole.MEMBER);
    // Three ties on one member, their names deliberately against the id order.
    Team tieA = dataService.createTeam(user1, "Tri Zeta", "tri-zeta", Visibility.PUBLIC);
    Team tieB = dataService.createTeam(user1, "Tri Beta", "tri-beta", Visibility.PUBLIC);
    Team tieC = dataService.createTeam(user1, "Tri Alpha", "tri-alpha", Visibility.PUBLIC);

    List<String> expected =
        List.of(big.getSlug(), medium.getSlug(), tieC.getSlug(), tieB.getSlug(), tieA.getSlug());
    // Descending: the id breaks the ties descending too.
    List<Long> tieIds = List.of(tieA.getId(), tieB.getId(), tieC.getId());
    assertTrue(tieIds.get(0) < tieIds.get(1) && tieIds.get(1) < tieIds.get(2));

    List<String> paged = new java.util.ArrayList<>();
    for (int page = 0; page < 5; page++) {
      paged.addAll(
          given()
              .queryParam("search", "Tri")
              .queryParam("sortBy", "MEMBER_COUNT")
              .queryParam("page", page)
              .queryParam("size", 1)
              .when()
              .get("/api/teams")
              .then()
              .statusCode(200)
              .body("total", equalTo(5))
              .extract()
              .jsonPath()
              .getList("teams.slug", String.class));
    }
    assertEquals(expected, paged);

    given()
        .queryParam("search", "Tri")
        .queryParam("sortBy", "MEMBER_COUNT")
        .queryParam("sortDir", "ASC")
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams.slug", equalTo(expected.reversed()))
        .body("teams.memberCount", equalTo(List.of(1, 1, 1, 2, 3)));
  }

  /** Without sortBy the directory keeps its name order. */
  @Test
  void listTeams_withoutSort_keepsTheNameOrder() {
    dataService.createTeam(user1, "Tri Zeta", "tri-zeta", Visibility.PUBLIC);
    dataService.createTeam(user1, "Tri Alpha", "tri-alpha", Visibility.PUBLIC);

    given()
        .queryParam("search", "Tri")
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams.slug", equalTo(List.of("tri-alpha", "tri-zeta")));
  }

  @Test
  void getTeam_withNonexistentSlug_shouldReturn404() {
    given().when().get("/api/teams/nonexistent-team-slug").then().statusCode(404);
  }

  @Test
  void getTeam_publicTeam_shouldReturnTeamDetails() {
    given()
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("slug", equalTo(team1Slug))
        .body("name", equalTo("Team 1"))
        .body("visibility", equalTo("PUBLIC"));
  }

  // ==================== Visibility: PUBLIC_UNLISTED ====================

  @Test
  void listTeams_anonymous_shouldExcludePublicUnlisted() {
    dataService.createTeam(user4, "Unlisted Club", "unlisted-club", Visibility.PUBLIC_UNLISTED);

    given()
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        // team1 is PUBLIC and must be listed, the unlisted team must never be
        .body("teams.slug", hasItem(team1Slug))
        .body("teams.slug", not(hasItem("unlisted-club")))
        .body("teams.slug", not(hasItem(team2Slug)));
  }

  @Test
  void listTeams_member_shouldIncludePublicUnlisted() {
    dataService.createTeam(user4, "Unlisted Club", "unlisted-club", Visibility.PUBLIC_UNLISTED);

    // user4 is ADMIN/member of the unlisted team, so it must appear in its own listing
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams.slug", hasItem("unlisted-club"));
  }

  @Test
  void listTeams_loggedNonMember_shouldExcludePublicUnlisted() {
    dataService.createTeam(user4, "Unlisted Club", "unlisted-club", Visibility.PUBLIC_UNLISTED);

    // user5 is a member of neither the unlisted team nor team1/team2
    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams.slug", not(hasItem("unlisted-club")));
  }

  @Test
  void listTeams_anonymousSearch_shouldNotFindPublicUnlisted() {
    dataService.createTeam(user4, "Hidden Squad", "hidden-squad", Visibility.PUBLIC_UNLISTED);

    given()
        .queryParam("search", "Hidden")
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams.slug", not(hasItem("hidden-squad")));
  }

  @Test
  void getTeam_publicUnlisted_anonymous_shouldReturnTeamDetails() {
    dataService.createTeam(user4, "Unlisted Club", "unlisted-club", Visibility.PUBLIC_UNLISTED);

    // direct URL access is the whole point of an unlisted team
    given()
        .when()
        .get("/api/teams/unlisted-club")
        .then()
        .statusCode(200)
        .body("slug", equalTo("unlisted-club"))
        .body("visibility", equalTo("PUBLIC_UNLISTED"));
  }

  @Test
  void getTeam_privateTeam_anonymous_shouldReturn403() {
    // team2 has TEAM visibility: not reachable by URL for a non-member
    given().when().get("/api/teams/" + team2Slug).then().statusCode(403);
  }

  @Test
  void createTeamViaApi_shouldCreateTeamSuccessfully() {
    TeamRequest teamRequest =
        new TeamRequest(
            "API Test Team",
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
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .body(teamRequest)
        .when()
        .post("/api/teams")
        .then()
        .statusCode(201)
        .body("name", equalTo("API Test Team"))
        .body("slug", startsWith("api-test-team"))
        .body("visibility", equalTo("TEAM"));
  }

  @Test
  void createTeam_withoutAuth_shouldReturn401() {
    TeamRequest teamRequest =
        new TeamRequest(
            "API Test Team",
            MediaDto.builder().build(),
            Visibility.PUBLIC,
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
        .contentType("application/json")
        .body(teamRequest)
        .when()
        .post("/api/teams")
        .then()
        .statusCode(401);
  }

  @Test
  void getMyTeams_shouldReturnUserTeams() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams?minRole=MEMBER")
        .then()
        .statusCode(200)
        .body("teams", hasSize(greaterThanOrEqualTo(2)))
        .body("teams[0].role", equalTo("ADMIN"));
  }

  @Test
  void joinPublicTeam_shouldAddUserAsMember() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/members/join")
        .then()
        .statusCode(201)
        .body("role", equalTo("MEMBER"));
  }

  @Test
  void joinPrivateTeam_shouldBeDenied() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team2Slug + "/members/join")
        .then()
        .statusCode(403);
  }

  @Test
  void updateTeam_asAdmin_shouldSucceed() {
    TeamRequest teamRequest =
        new TeamRequest(
            "Updated Name",
            MediaDto.builder().markdown("New description").build(),
            Visibility.PUBLIC,
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
        .put("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Name"))
        .body("about.markdown", equalTo("New description"));
  }

  @Test
  void updateTeam_asNonAdmin_shouldBeDenied() {
    TeamRequest teamRequest =
        new TeamRequest(
            "Hacked Name",
            MediaDto.builder().build(),
            Visibility.PUBLIC,
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
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(teamRequest)
        .when()
        .put("/api/teams/" + team1Slug)
        .then()
        .statusCode(403);
  }

  @Test
  void leaveTeam_shouldRemoveMembership() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/members/leave")
        .then()
        .statusCode(204);
  }

  @Test
  void getTeamMembers_shouldReturnMemberList() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/members")
        .then()
        .statusCode(200)
        .body("members", hasSize(3))
        .body("total", equalTo(3));
  }

  @Test
  void getMembers_withoutAuth_shouldReturn401() {
    given().when().get("/api/teams/some-team/members").then().statusCode(401);
  }

  @Test
  void deleteTeam_asAdmin_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug)
        .then()
        .statusCode(204);

    // Verify team is no longer accessible
    given().when().get("/api/teams/" + team1Slug).then().statusCode(404);
  }

  @Test
  void createTeam_withDeletedTeamName_shouldSuffixTheSlug() {
    TeamRequest teamRequest =
        new TeamRequest(
            "Reborn Team",
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
    String firstSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER5))
            .contentType("application/json")
            .body(teamRequest)
            .post("/api/teams")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");
    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .delete("/api/teams/" + firstSlug)
        .then()
        .statusCode(204);

    // uk_teams_domain_slug still holds the deleted team's slug: the new one must not collide
    given()
        .auth()
        .oauth2(getAccessToken(USER5))
        .contentType("application/json")
        .body(teamRequest)
        .post("/api/teams")
        .then()
        .statusCode(201)
        .body("slug", equalTo(firstSlug + "-1"));
  }

  // docs/LEDGER_*.md MIG-5: biketeam redirects a migrated team's old addresses to it.

  @Test
  void deleteTeam_migratedFromBiketeam_isRefusedToItsAdmin_andTheTeamStays() {
    biketeamData.mapTeam("team-one", team1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug)
        .then()
        .statusCode(400)
        .body("code", equalTo("MIGRATED_TEAM"));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200);
  }

  @Test
  void deleteTeam_migratedFromBiketeam_isRefusedToAPlatformAdminToo() {
    biketeamData.mapTeam("team-one", team1);
    dataService.createPlatformAdminUser("godmode@example.com", "God Mode");

    given()
        .auth()
        .oauth2(getAccessToken("godmode"))
        .when()
        .delete("/api/teams/" + team1Slug)
        .then()
        .statusCode(400)
        .body("code", equalTo("MIGRATED_TEAM"));
  }

  /** Ledger API-137: the real role, null for a non-member, and still the whole menu of pages. */
  @Test
  void getTeam_asPlatformAdminNonMember_shouldReturnNullRole_andAllPages() {
    dataService.createPlatformAdminUser("godmode@example.com", "God Mode");
    var draft = dataService.createAdditionalPage(team2, user1, "Brouillon", 1);
    dataService.setTeamEntityStatus(draft, fr.pedalons.enums.Status.DRAFT);
    dataService.createAdditionalPage(team2, user1, "Réservée", 2, Visibility.TEAM);

    given()
        .auth()
        .oauth2(getAccessToken("godmode"))
        .when()
        .get("/api/teams/" + team2Slug)
        .then()
        .statusCode(200)
        .body("role", nullValue())
        .body("pages.size()", equalTo(2))
        // The administration panel's split stays: it is a right, not a role.
        .body("memberCountByRole", notNullValue());
  }

  /** Ledger API-137: « Mes équipes » of a platform admin who belongs to no team is empty. */
  @Test
  void listTeams_minRoleMember_asPlatformAdminWithoutTeam_shouldBeEmpty() {
    dataService.createPlatformAdminUser("godmode@example.com", "God Mode");

    given()
        .auth()
        .oauth2(getAccessToken("godmode"))
        .queryParam("minRole", "MEMBER")
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams", empty())
        .body("total", equalTo(0));

    // The directory, without minRole, still lists every team of the domain, private ones included.
    given()
        .auth()
        .oauth2(getAccessToken("godmode"))
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("total", equalTo(2))
        .body("teams.role", everyItem(nullValue()));
  }

  @Test
  void deleteTeam_asNonAdmin_shouldBeDenied() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/teams/" + team1Slug)
        .then()
        .statusCode(403);
  }

  @Test
  void deleteTeam_asNonMember_shouldBeDenied() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/teams/" + team2Slug)
        .then()
        .statusCode(403);
  }

  // ==================== Change Slug Tests ====================

  @Test
  void changeSlug_asAdmin_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("new-team-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("new-team-slug"));
  }

  @Test
  void changeSlug_asNonAdmin_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(new SlugChangeRequest("hacked-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/slug")
        .then()
        .statusCode(403);
  }

  @Test
  void changeSlug_withoutAuth_shouldReturn401() {
    given()
        .contentType("application/json")
        .body(new SlugChangeRequest("unauth-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/slug")
        .then()
        .statusCode(401);
  }

  @Test
  void changeSlug_asNonMember_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(new SlugChangeRequest("nonmember-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/slug")
        .then()
        .statusCode(403);
  }

  // ==================== Members-only pages ====================

  @Test
  void aMembersOnlyPage_isListedToMembersOnly() {
    dataService.createAdditionalPage(team1, user1, "Horaires", 0, Visibility.PUBLIC);
    dataService.createAdditionalPage(team1, user1, "Codes du local", 1, Visibility.TEAM);

    // Anonymous: neither the team nor the directory names the members-only page.
    given()
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("pages.slug", contains("horaires"));
    given()
        .queryParam("size", 50)
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams.find { it.slug == '" + team1Slug + "' }.pages.slug", contains("horaires"));

    // Signed in, not a member: same.
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("pages.slug", contains("horaires"));

    // A member: both.
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("pages.slug", contains("horaires", "codes-du-local"));
  }
}
