package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob.Options;
import fr.pedalons.util.NetworkEdgesSeeder;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The statements of the nightly pass (docs/LEDGER_*.md API-198, lot 3b): one for the list of teams,
 * one per team for its digest and one per deposit for the streamed tracks, whatever the number of
 * tracks. Not one per track, not one per team entity.
 */
@QuarkusTest
class RouteGeneratorOverlayQueryCountTest extends AbstractQueryCountTest {

  @Inject RouteGeneratorOverlayJob job;
  @Inject NetworkEdgesSeeder seeder;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    FakeRouteGeneratorGateway.reset();
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  @AfterEach
  void restore() {
    FakeRouteGeneratorGateway.reset();
  }

  private QueryStats.Counters forcedPass(String label) {
    return queryStats.measureAll(
        label, () -> job.runOnce(Instant.now(), new Options(null, true, false)));
  }

  @Test
  void aPassCostsTheSameForTwoTracksOrTwenty() {
    seeder.seedGrid(team1, user1, 1);
    forcedPass("warm up");
    QueryStats.Counters few = forcedPass("pass, 2 tracks");
    for (int i = 0; i < 18; i++) {
      seeder.seedRow(team1, user1, "Again " + i, 0, 2);
    }
    QueryStats.Counters many = forcedPass("pass, 20 tracks");
    assertEquals(few.statements(), many.statements(), queryStats.queryBreakdown(30));
    assertEquals(few.entityLoads(), many.entityLoads());
    assertTrue(few.statements() > 0);
  }

  @Test
  void aPassWithNothingToDepositCostsOnePerTeamPlusTheList() {
    seeder.seedGrid(team1, user1, 3);
    job.runOnce(Instant.now(), Options.nightly());
    QueryStats.Counters idle =
        queryStats.measureAll("idle pass", () -> job.runOnce(Instant.now(), Options.nightly()));
    // the list of teams, the digest of the one served team: nothing streamed
    assertEquals(2, idle.statements(), queryStats.queryBreakdown(30));
  }
}
