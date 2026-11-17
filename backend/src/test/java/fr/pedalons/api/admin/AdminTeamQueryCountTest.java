package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.specification.RequestSpecification;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Database-cost budget for the platform admin's team list: the member count of each row comes from
 * one grouped query for the page, never one count per team (docs/LEDGER_*.md API-139).
 *
 * <p>See {@link AbstractQueryCountTest}.
 */
@QuarkusTest
class AdminTeamQueryCountTest extends AbstractQueryCountTest {

  private User platformAdmin;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    platformAdmin = dataService.createPlatformAdminUser("admin@example.com", "Platform Admin");
  }

  private Supplier<RequestSpecification> asPlatformAdmin() {
    String token = jwtService.generateAccessToken(platformAdmin);
    return () -> given().auth().oauth2(token);
  }

  @Test
  void listTeams_costDoesNotScaleWithRowCount() {
    for (int i = 0; i < LARGE_PAGE; i++) {
      Team team =
          dataService.createTeam(user1, "Budget Team " + i, "budget-team-" + i, Visibility.PUBLIC);
      dataService.addUserToTeam(user2, team, TeamRole.MEMBER);
    }
    assertFlatQueryCount("GET /api/admin/teams", asPlatformAdmin(), "/api/admin/teams");
  }

  @Test
  void listTeams_stillCountsEachTeamsMembers() {
    Team team = dataService.createTeam(user1, "Counted Team", "counted-team", Visibility.PUBLIC);
    dataService.addUserToTeam(user2, team, TeamRole.MEMBER);
    String teamId = TsidUtils.toString(team.getId());

    asPlatformAdmin()
        .get()
        .when()
        .get("/api/admin/teams?size=100")
        .then()
        .statusCode(200)
        .body("teams.id", hasItem(teamId))
        .body("teams.find { it.id == '" + teamId + "' }.memberCount", equalTo(2));
  }
}
