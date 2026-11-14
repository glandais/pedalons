package fr.pedalons.api.routes;

import static fr.pedalons.util.NetworkEdgesFixtures.lat;
import static fr.pedalons.util.NetworkEdgesFixtures.lon;
import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.service.route.network.RouteGeneratorGuard;
import fr.pedalons.service.route.network.TeamNetworkCache;
import fr.pedalons.util.NetworkEdgesSeeder;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The generator's statements (docs/LEDGER_*.md API-198, lot 3): a graph build is one statement
 * whatever the size of the team's network, and the engine reads nothing per candidate.
 */
@QuarkusTest
class RouteGeneratorQueryCountTest extends AbstractQueryCountTest {

  private static final int SIZE = 5;

  @Inject NetworkEdgesSeeder seeder;
  @Inject RouteGeneratorGuard guard;
  @Inject TeamNetworkCache cache;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    guard.clear();
    cache.clearForTest();
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  private void generate(int seed, double distanceKm) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(ContentType.JSON)
        .body(
            Map.of(
                "start", Map.of("lng", lon(2), "lat", lat(2)),
                "distanceKm", distanceKm,
                "seed", seed))
        .when()
        .post("/api/teams/" + team1Slug + "/route-generator")
        .then()
        .statusCode(200);
  }

  private QueryStats.Counters measure(String label, int seed, double distanceKm) {
    return queryStats.measureAll(label, () -> generate(seed, distanceKm));
  }

  /** Makes the next lookup a miss: a route column the graph depends on moves, as a save would do. */
  private void touchARoute() {
    seeder.sql(
        "update team_entities set excluded_from_generator = not excluded_from_generator where id ="
            + " (select min(id) from team_entities where team_id = ?1 and entity_type = 2)",
        team1.getId());
  }

  @Test
  void aMiss_costsTwoStatementsMoreThanAHit() {
    seeder.seedGrid(team1, user1, SIZE);
    generate(1, 10); // builds
    QueryStats.Counters hit = measure("generator hit", 1, 10);
    touchARoute();
    QueryStats.Counters miss = measure("generator miss", 1, 10);
    // the fingerprint is read again under the lock, then the build itself
    assertEquals(hit.statements() + 2, miss.statements(), queryStats.queryBreakdown(30));
    // the build is a native projection: not one entity more
    assertEquals(hit.entityLoads(), miss.entityLoads());
  }

  @Test
  void aBuildIsOneStatement_whateverTheSizeOfTheNetwork() {
    seeder.seedGrid(team1, user1, SIZE);
    generate(1, 10);
    touchARoute();
    QueryStats.Counters few = measure("generator miss, 10 routes", 1, 10);
    // 20 more routes, the grid's rows again and again
    for (int i = 0; i < 20; i++) {
      seeder.seedRow(team1, user1, "Again " + i, i % SIZE, SIZE);
    }
    touchARoute();
    QueryStats.Counters many = measure("generator miss, 30 routes", 1, 10);
    assertEquals(few.statements(), many.statements(), queryStats.queryBreakdown(30));
  }

  @Test
  void aHit_costsNothingPerCandidate() {
    seeder.seedGrid(team1, user1, SIZE);
    generate(1, 10);
    QueryStats.Counters first = measure("generator hit, seed 1", 1, 10);
    QueryStats.Counters second = measure("generator hit, seed 2, 12 km", 2, 12);
    QueryStats.Counters third = measure("generator hit, seed 3, 8 km", 3, 11);
    assertEquals(first.statements(), second.statements());
    assertEquals(first.statements(), third.statements());
    assertTrue(first.statements() > 0);
  }
}
