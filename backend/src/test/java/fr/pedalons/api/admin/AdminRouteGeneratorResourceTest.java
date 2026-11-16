package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway;
import fr.pedalons.util.NetworkEdgesSeeder;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code POST /api/admin/route-generator/overlays/refresh} (docs/LEDGER_*.md API-198, lot 3b plan
 * §6.5): platform admin only; a dry run answers 200 with the table of what would be done, a real
 * run 202 and works in the background.
 */
@QuarkusTest
class AdminRouteGeneratorResourceTest extends AbstractResourceTest {

  private static final String URL = "/api/admin/route-generator/overlays/refresh";

  @Inject NetworkEdgesSeeder seeder;

  private User platformAdmin;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    FakeRouteGeneratorGateway.reset();
    platformAdmin = dataService.createPlatformAdminUser("admin@example.com", "Platform Admin");
    dataService.setTeamEnableRoutePlanner(team1, true);
    seeder.seedGrid(team1, user1, 2);
  }

  @AfterEach
  void restore() {
    FakeRouteGeneratorGateway.reset();
  }

  private ValidatableResponse refresh(String token, boolean dryRun, boolean force, String teamId) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("dryRun", dryRun);
    body.put("force", force);
    if (teamId != null) {
      body.put("teamId", teamId);
    }
    var spec = given().contentType(ContentType.JSON).body(body);
    if (token != null) {
      spec = spec.auth().oauth2(token);
    }
    return spec.when().post(URL).then();
  }

  private String adminToken() {
    return jwtService.generateAccessToken(platformAdmin);
  }

  @Test
  void onlyAPlatformAdminMayAsk() {
    refresh(null, true, false, null).statusCode(401);
    refresh(getAccessToken(USER1), true, false, null).statusCode(403);
    assertEquals(0, FakeRouteGeneratorGateway.CALLS.size());
  }

  @Test
  void aDryRunListsWhatWouldBeDoneAndSendsNothing() {
    refresh(adminToken(), true, false, null)
        .statusCode(200)
        .body("started", equalTo(true))
        .body("graphId", equalTo("graph-test"))
        .body("items.teamId", hasItem(TsidUtils.toString(team1.getId())))
        .body("items.find { it.teamSlug == '" + team1Slug + "' }.action", equalTo("DEPOSIT"))
        .body("items.find { it.teamSlug == '" + team1Slug + "' }.reason", equalTo("ABSENT"))
        .body("items.find { it.teamSlug == '" + team1Slug + "' }.state", equalTo("absent"));
    assertEquals(0, FakeRouteGeneratorGateway.calls("PUT", "/v1/generator/overlay"));
  }

  @Test
  void aRealRunAnswers202AndDepositsInTheBackground() throws Exception {
    refresh(adminToken(), false, false, TsidUtils.toString(team1.getId()))
        .statusCode(202)
        .body("started", equalTo(true))
        .body("graphId", nullValue());
    String ref = TsidUtils.toString(team1.getId());
    long deadline = System.currentTimeMillis() + 20_000;
    while (FakeRouteGeneratorGateway.overlayOf(ref) == null
        && System.currentTimeMillis() < deadline) {
      Thread.sleep(100);
    }
    assertNotNull(FakeRouteGeneratorGateway.overlayOf(ref));
  }

  @Test
  void aDryRunWithForceShowsTheDepositAgain() {
    FakeRouteGeneratorGateway.markReady(TsidUtils.toString(team1.getId()), "whatever");
    refresh(adminToken(), true, true, TsidUtils.toString(team1.getId()))
        .statusCode(200)
        .body("items[0].reason", equalTo("FORCED"));
  }

  @Test
  void anEngineThatIsOffStartsNothing() {
    FakeRouteGeneratorGateway.generatorEnabled = false;
    refresh(adminToken(), true, false, null).statusCode(200).body("started", equalTo(false));
  }

  @Test
  void aRealRunOnAnEngineThatIsOffStartsNothing() {
    FakeRouteGeneratorGateway.generatorEnabled = false;
    refresh(adminToken(), false, false, null).statusCode(202).body("started", equalTo(false));
    assertEquals(0, FakeRouteGeneratorGateway.calls("PUT", "/v1/generator/overlay"));
  }
}
