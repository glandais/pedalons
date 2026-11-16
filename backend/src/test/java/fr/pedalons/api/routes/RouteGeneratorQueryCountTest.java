package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway;
import fr.pedalons.service.route.network.RouteGeneratorGuard;
import fr.pedalons.util.NetworkEdgesSeeder;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The statements of a generation (docs/LEDGER_*.md API-198, lot 3b): the engine reads nothing of the
 * team's routes, so a generation costs the same whatever the number of routes the team rides and
 * the number of routes rendered.
 */
@QuarkusTest
class RouteGeneratorQueryCountTest extends AbstractQueryCountTest {

  @Inject NetworkEdgesSeeder seeder;
  @Inject RouteGeneratorGuard guard;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    guard.clear();
    FakeRouteGeneratorGateway.reset();
    FakeRouteDetailsClient.reset();
    dataService.setTeamEnableRoutePlanner(team1, true);
    FakeRouteGeneratorGateway.markReady(TsidUtils.toString(team1.getId()), "digest");
  }

  @AfterEach
  void restore() {
    FakeRouteGeneratorGateway.reset();
    FakeRouteDetailsClient.reset();
  }

  private void generate(int seed) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(ContentType.JSON)
        .body(Map.of("start", Map.of("lng", -1.5, "lat", 47.2), "distanceKm", 40, "seed", seed))
        .when()
        .post("/api/teams/" + team1Slug + "/route-generator")
        .then()
        .statusCode(200);
  }

  private QueryStats.Counters measure(String label, int seed) {
    return queryStats.measureAll(label, () -> generate(seed));
  }

  @Test
  void aGenerationCostsTheSameForOneRouteOrThree() {
    generate(1); // warms what a first request loads
    FakeRouteGeneratorGateway.routeCount = 1;
    QueryStats.Counters one = measure("generator, 1 route", 1);
    FakeRouteGeneratorGateway.routeCount = 3;
    QueryStats.Counters three = measure("generator, 3 routes", 1);
    assertEquals(one.statements(), three.statements(), queryStats.queryBreakdown(30));
    assertTrue(one.statements() > 0);
  }

  @Test
  void aGenerationCostsTheSameForTwoRoutesOrTwenty() {
    seeder.seedGrid(team1, user1, 2);
    generate(1);
    QueryStats.Counters few = measure("generator, few team routes", 1);
    for (int i = 0; i < 20; i++) {
      seeder.seedRow(team1, user1, "Again " + i, i % 2, 2);
    }
    QueryStats.Counters many = measure("generator, many team routes", 1);
    assertEquals(few.statements(), many.statements(), queryStats.queryBreakdown(30));
    assertEquals(few.entityLoads(), many.entityLoads());
  }
}
