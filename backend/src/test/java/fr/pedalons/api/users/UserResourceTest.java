package fr.pedalons.api.users;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.migration.live.BiketeamTestData;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.File;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class UserResourceTest extends AbstractResourceTest {

  @Inject UserRepository userRepository;

  @Inject TeamRepository teamRepository;

  @Inject BiketeamTestData biketeamData;

  @Inject AuthSessionRepository authSessionRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  @Test
  void getCurrentUser_shouldReturnUserDetails() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/users/me")
        .then()
        .statusCode(200)
        .body("email", equalTo(EMAIL1));
  }

  @Test
  void getCurrentUser_withoutAuth_shouldReturn401() {
    given().when().get("/api/users/me").then().statusCode(401);
  }

  @Test
  void updateCurrentUser_shouldUpdateDisplayName() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body("{\"displayName\": \"Updated Name\"}")
        .when()
        .put("/api/users/me")
        .then()
        .statusCode(200)
        .body("displayName", equalTo("Updated Name"));
  }

  @Test
  void updateCurrentUser_withoutAuth_shouldReturn401() {
    given()
        .contentType("application/json")
        .body("{\"displayName\": \"Hacker\"}")
        .when()
        .put("/api/users/me")
        .then()
        .statusCode(401);
  }

  @Test
  void deleteCurrentUser_shouldSoftDeleteAccount() {
    // USER3 is a plain member: USER1, the sole admin of both teams, may not leave (see below).
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .delete("/api/users/me")
        .then()
        .statusCode(204);

    assertTrue(isDeleted(user3));
  }

  @Test
  void deleteCurrentUser_protectedAccount_signsOutButErasesNothing() {
    // The store reviewers' demo account (pedalons.account-deletion.protected-emails, %test value).
    User reviewer = dataService.createUser("store-reviewer@example.com", "Store reviewer");
    dataService.createAuthSession(reviewer, "reviewer-session", Instant.now().plusSeconds(3600));

    given()
        .auth()
        .oauth2(getAccessToken("store-reviewer"))
        .when()
        .delete("/api/users/me")
        .then()
        .statusCode(204);

    User after =
        QuarkusTransaction.requiringNew().call(() -> userRepository.findById(reviewer.getId()));
    assertFalse(after.isDeleted());
    assertEquals("Store reviewer", after.getDisplayName());
    assertEquals(
        0L,
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    authSessionRepository.count(
                        "user.id = ?1 and revoked = false", reviewer.getId())));
  }

  @Test
  void deleteCurrentUser_soleAdminOfATeamWithMembers_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/users/me")
        .then()
        .statusCode(400)
        .body("code", equalTo("SOLE_TEAM_ADMIN"));

    assertFalse(isDeleted(user1));
  }

  @Test
  void deleteCurrentUser_aloneInATeam_shouldDeleteTheTeam() {
    User solo = dataService.createUser("solo@example.com", "Solo");
    Team soloTeam = dataService.createTeam(solo, "Solo team", "solo-team", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken("solo"))
        .when()
        .delete("/api/users/me")
        .then()
        .statusCode(204);

    assertTrue(isDeleted(solo));
    assertTrue(
        QuarkusTransaction.requiringNew()
            .call(() -> teamRepository.findById(soloTeam.getId()).isDeleted()));
  }

  @Test
  void getMyDeletionImpact_soleAdminOfTeamsWithMembers_isBlocked() {
    Team soloTeam = dataService.createTeam(user1, "Solo team", "solo-team", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/users/me/deletion-impact")
        .then()
        .statusCode(200)
        .body("blocked", is(true))
        .body("blockingTeams.slug", containsInAnyOrder(team1Slug, team2Slug))
        .body("deletedTeams.slug", contains(soloTeam.getSlug()))
        .body("deletedTeams[0].name", equalTo("Solo team"));
  }

  @Test
  void getMyDeletionImpact_plainMember_isNotBlocked() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/users/me/deletion-impact")
        .then()
        .statusCode(200)
        .body("blocked", is(false))
        .body("blockingTeams", empty())
        .body("deletedTeams", empty())
        .body("migratedTeams", empty());
  }

  // ─── teams migrated from biketeam ────────────────────────────────────────

  @Test
  void deleteCurrentUser_soleAdminOfAMigratedTeam_aloneInIt_isRefused_andTheTeamStays() {
    User solo = dataService.createUser("solo@example.com", "Solo");
    Team migrated = dataService.createTeam(solo, "Club migré", "club-migre", Visibility.PUBLIC);
    biketeamData.mapTeam("club-migre", migrated);

    given()
        .auth()
        .oauth2(getAccessToken("solo"))
        .when()
        .get("/api/users/me/deletion-impact")
        .then()
        .statusCode(200)
        .body("blocked", is(true))
        .body("migratedTeams.slug", contains("club-migre"))
        .body("migratedTeams[0].name", equalTo("Club migré"))
        .body("deletedTeams", empty())
        .body("blockingTeams", empty());

    given()
        .auth()
        .oauth2(getAccessToken("solo"))
        .when()
        .delete("/api/users/me")
        .then()
        .statusCode(400)
        .body("code", equalTo("SOLE_MIGRATED_TEAM_ADMIN"));

    assertFalse(isDeleted(solo));
    assertFalse(
        QuarkusTransaction.requiringNew()
            .call(() -> teamRepository.findById(migrated.getId()).isDeleted()));
  }

  @Test
  void deleteCurrentUser_soleAdminOfAMigratedTeamWithMembers_isRefusedForTheMigration() {
    biketeamData.mapTeam("team-one", team1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/users/me/deletion-impact")
        .then()
        .statusCode(200)
        .body("blocked", is(true))
        // Named once, in its own list.
        .body("migratedTeams.slug", contains(team1Slug))
        .body("blockingTeams.slug", contains(team2Slug));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/users/me")
        .then()
        .statusCode(400)
        .body("code", equalTo("SOLE_MIGRATED_TEAM_ADMIN"));

    assertFalse(isDeleted(user1));
  }

  @Test
  void deleteCurrentUser_aMigratedTeamWithAnotherAdmin_doesNotBlock() {
    User solo = dataService.createUser("solo@example.com", "Solo");
    Team migrated = dataService.createTeam(solo, "Club migré", "club-migre", Visibility.PUBLIC);
    dataService.addUserToTeam(user4, migrated, TeamRole.ADMIN);
    biketeamData.mapTeam("club-migre", migrated);

    given()
        .auth()
        .oauth2(getAccessToken("solo"))
        .when()
        .get("/api/users/me/deletion-impact")
        .then()
        .statusCode(200)
        .body("blocked", is(false))
        .body("migratedTeams", empty());

    given()
        .auth()
        .oauth2(getAccessToken("solo"))
        .when()
        .delete("/api/users/me")
        .then()
        .statusCode(204);

    assertTrue(isDeleted(solo));
  }

  @Test
  void deleteCurrentUser_aTrashedMigratedTeam_doesNotBlock() {
    User solo = dataService.createUser("solo@example.com", "Solo");
    Team migrated = dataService.createTeam(solo, "Club migré", "club-migre", Visibility.PUBLIC);
    biketeamData.mapTeam("club-migre", migrated);
    biketeamData.trashTeam(migrated.getId());

    given()
        .auth()
        .oauth2(getAccessToken("solo"))
        .when()
        .get("/api/users/me/deletion-impact")
        .then()
        .statusCode(200)
        .body("blocked", is(false))
        .body("migratedTeams", empty())
        .body("deletedTeams", empty());

    given()
        .auth()
        .oauth2(getAccessToken("solo"))
        .when()
        .delete("/api/users/me")
        .then()
        .statusCode(204);
  }

  /** The migrated teams are found in one query for all of them, not one per team. */
  @Test
  void getMyDeletionImpact_costsTheSameForOneMigratedTeamAsForThree() {
    User solo = dataService.createUser("solo@example.com", "Solo");
    Team first = dataService.createTeam(solo, "Club 1", "club-1", Visibility.PUBLIC);
    biketeamData.mapTeam("club-1", first);
    String token = getAccessToken("solo");
    Runnable impact =
        () ->
            given()
                .auth()
                .oauth2(token)
                .when()
                .get("/api/users/me/deletion-impact")
                .then()
                .statusCode(200)
                .body("blocked", is(true));
    impact.run(); // warm-up: the first request of a user pays for its lookup caches.
    long one = queryStats.measure("GET /users/me/deletion-impact (1 migrated team)", impact);

    for (int i = 2; i <= 3; i++) {
      Team team = dataService.createTeam(solo, "Club " + i, "club-" + i, Visibility.PUBLIC);
      biketeamData.mapTeam("club-" + i, team);
    }
    impact.run();
    long three = queryStats.measure("GET /users/me/deletion-impact (3 migrated teams)", impact);

    assertEquals(one, three, () -> "per-team queries:\n" + queryStats.queryBreakdown(10));
  }

  @Test
  void getMyDeletionImpact_withoutAuth_shouldReturn401() {
    given().when().get("/api/users/me/deletion-impact").then().statusCode(401);
  }

  // Read in the database: there is no GET /api/users/{id} — the 404 this test used to expect from
  // one came from the missing route, whatever the account's state.
  private boolean isDeleted(User user) {
    return QuarkusTransaction.requiringNew()
        .call(() -> userRepository.findById(user.getId()).isDeleted());
  }

  @Test
  void deleteCurrentUser_withoutAuth_shouldReturn401() {
    given().when().delete("/api/users/me").then().statusCode(401);
  }

  // ==================== Upload Avatar Tests ====================

  @Test
  void uploadAvatar_withValidImage_shouldSucceed() {
    File imageFile = new File("src/test/resources/image.png");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", imageFile, "image/png")
        .when()
        .post("/api/users/me/avatar")
        .then()
        .statusCode(200)
        .body("avatarUrl", notNullValue());
  }

  @Test
  void uploadAvatar_withoutAuth_shouldReturn401() {
    File imageFile = new File("src/test/resources/image.png");

    given()
        .multiPart("file", imageFile, "image/png")
        .when()
        .post("/api/users/me/avatar")
        .then()
        .statusCode(401);
  }

  @Test
  void uploadAvatar_withoutFile_shouldReturn400() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("multipart/form-data")
        .when()
        .post("/api/users/me/avatar")
        .then()
        .statusCode(400);
  }

  // ==================== Delete Avatar Tests ====================

  @Test
  void deleteAvatar_withAuth_shouldSucceed() {
    // First upload an avatar
    File imageFile = new File("src/test/resources/image.png");
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("file", imageFile, "image/png")
        .when()
        .post("/api/users/me/avatar")
        .then()
        .statusCode(200);

    // Then delete it
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/users/me/avatar")
        .then()
        .statusCode(200);
  }

  @Test
  void deleteAvatar_withoutAuth_shouldReturn401() {
    given().when().delete("/api/users/me/avatar").then().statusCode(401);
  }

  @Test
  void deleteAvatar_whenNoAvatar_shouldSucceed() {
    // Deleting when there's no avatar should still return 200
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/users/me/avatar")
        .then()
        .statusCode(200);
  }
}
