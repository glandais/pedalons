package fr.pedalons.api.teams;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code GET /api/teams/{teamSlug}/members?sortBy=&sortDir=}: the name order every roster reads in
 * by default (RL5, 12 November 2026), and {@code JOINED_AT}, the « Nouveaux membres » of the
 * administration panel. Fixture order of arrival on team1: user1, user2, user3, then user4 and user5
 * added here.
 */
@QuarkusTest
class TeamMemberSortResourceTest extends AbstractResourceTest {

  @Inject EntityManager em;

  private String members() {
    return "/api/teams/" + team1Slug + "/members";
  }

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.addUserToTeam(user4, team1, TeamRole.MEMBER);
    dataService.addUserToTeam(user5, team1, TeamRole.MEMBER);
  }

  @Test
  void joinedAt_desc_orOmittedDirection_shouldListNewestFirst() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("sortBy", "JOINED_AT")
        .queryParam("size", 3)
        .when()
        .get(members())
        .then()
        .statusCode(200)
        .body("members.user.displayName", contains("Test User 5", "Test User 4", "Test User 3"))
        .body("total", equalTo(5));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("sortBy", "JOINED_AT")
        .queryParam("sortDir", "DESC")
        .queryParam("size", 2)
        .when()
        .get(members())
        .then()
        .statusCode(200)
        .body("members.user.displayName", contains("Test User 5", "Test User 4"));
  }

  @Test
  void joinedAt_asc_shouldListOldestFirst() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("sortBy", "JOINED_AT")
        .queryParam("sortDir", "ASC")
        .queryParam("size", 2)
        .when()
        .get(members())
        .then()
        .statusCode(200)
        .body("members.user.displayName", contains("Test User 1", "Test User 2"));
  }

  /** The order would hand back the join dates the response hides from an organizer. */
  @Test
  void joinedAt_asOrganizerOfAClosedDirectory_shouldBeRefused() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .queryParam("sortBy", "JOINED_AT")
        .when()
        .get(members())
        .then()
        .statusCode(403);
  }

  @Test
  void joinedAt_asMemberOfAnOpenDirectory_shouldBeAllowed() {
    dataService.setTeamEnableMemberDirectory(team1, true);
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .queryParam("sortBy", "JOINED_AT")
        .queryParam("size", 1)
        .when()
        .get(members())
        .then()
        .statusCode(200)
        .body("members.user.displayName", contains("Test User 5"));
  }

  // ------------------------------------------------------------------ name order

  /**
   * A team whose members' names go against both their order of arrival and their ids: user1
   * ("Test User 1", the admin, first in) then « Zoé », « bruno », « alice », « Bruno » and « Chloé ».
   * The two Brunos tie regardless of case; the membership id settles them.
   */
  private record NamedTeam(String slug, UserTeam lowerBruno, UserTeam upperBruno) {}

  private NamedTeam namedTeam() {
    Team team = dataService.createTeam(user1, "Tri Noms", "tri-noms", Visibility.PUBLIC);
    add(team, "zoe@example.com", "Zoé");
    UserTeam lowerBruno = add(team, "bruno@example.com", "bruno");
    add(team, "alice@example.com", "alice");
    UserTeam upperBruno = add(team, "bruno2@example.com", "Bruno");
    add(team, "chloe@example.com", "Chloé");
    return new NamedTeam(team.getSlug(), lowerBruno, upperBruno);
  }

  private UserTeam add(Team team, String email, String name) {
    return dataService.addUserToTeam(
        dataService.createUser(domain, email, name), team, TeamRole.MEMBER);
  }

  private static final List<String> BY_NAME =
      List.of("alice", "bruno", "Bruno", "Chloé", "Test User 1", "Zoé");

  private List<String> pageByPage(String slug, String sortBy, String sortDir) {
    List<String> names = new ArrayList<>();
    for (int page = 0; page < BY_NAME.size(); page++) {
      var request = given().auth().oauth2(getAccessToken(USER1)).queryParam("page", page);
      if (sortBy != null) {
        request = request.queryParam("sortBy", sortBy);
      }
      if (sortDir != null) {
        request = request.queryParam("sortDir", sortDir);
      }
      names.addAll(
          request
              .queryParam("size", 1)
              .when()
              .get("/api/teams/" + slug + "/members")
              .then()
              .statusCode(200)
              .body("total", equalTo(BY_NAME.size()))
              .extract()
              .jsonPath()
              .getList("members.user.displayName", String.class));
    }
    return names;
  }

  /**
   * Without sortBy the roster reads by name, regardless of case, A to Z — and the two names that
   * tie stay in one order from one page to the next. The lower-id Bruno is rewritten first so that
   * PostgreSQL meets it after the other: only the id at the end of the key puts it back first.
   */
  @Test
  void omittedSortBy_shouldListByName_totalAcrossPages() {
    NamedTeam team = namedTeam();
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery("update user_teams set id = id where id = :id")
                .setParameter("id", team.lowerBruno().getId())
                .executeUpdate());

    assertTrue(team.lowerBruno().getId() < team.upperBruno().getId());
    assertEquals(BY_NAME, pageByPage(team.slug(), null, null));
  }

  @Test
  void sortByName_omittedOrAscDirection_isAToZ_descIsZToA() {
    NamedTeam team = namedTeam();

    assertEquals(BY_NAME, pageByPage(team.slug(), "NAME", null));
    assertEquals(BY_NAME, pageByPage(team.slug(), "NAME", "ASC"));
    assertEquals(BY_NAME.reversed(), pageByPage(team.slug(), "NAME", "DESC"));
  }

  /**
   * An organiser of a closed directory gets the names and nothing else; the name order is made of
   * those names, so it is theirs too — unlike JOINED_AT, refused above.
   */
  @Test
  void sortByName_asOrganizerOfAClosedDirectory_shouldBeAllowed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .queryParam("sortBy", "NAME")
        .when()
        .get(members())
        .then()
        .statusCode(200)
        .body(
            "members.user.displayName",
            contains("Test User 1", "Test User 2", "Test User 3", "Test User 4", "Test User 5"))
        .body("members.joinedAt", everyItem(nullValue()));
  }
}
