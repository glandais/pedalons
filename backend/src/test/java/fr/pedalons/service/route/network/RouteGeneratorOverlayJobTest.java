package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway.Deposit;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway.Problem;
import fr.pedalons.repository.route.GeneratorSourceRepository;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob.Action;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob.Item;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob.Options;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob.Reason;
import fr.pedalons.service.route.network.RouteGeneratorOverlayJob.Report;
import fr.pedalons.util.NetworkEdgesSeeder;
import io.agroal.api.AgroalDataSource;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.sql.Connection;
import java.sql.ResultSet;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The nightly deposit of the teams' roads (docs/LEDGER_*.md API-198, lot 3b plan §6): what the
 * engine receives, when it receives nothing, and what each failure does. The engine is faked at the
 * HTTP message ({@link FakeRouteGeneratorGateway}); the clock is the {@code now} of the pass.
 */
@QuarkusTest
class RouteGeneratorOverlayJobTest extends AbstractResourceTest {

  private static final ObjectMapper JSON = new ObjectMapper();

  @Inject RouteGeneratorOverlayJob job;
  @Inject NetworkEdgesSeeder seeder;
  @Inject GeneratorSourceRepository repository;
  @Inject AgroalDataSource dataSource;

  private final List<Duration> slept = new ArrayList<>();
  private String ref1;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    FakeRouteGeneratorGateway.reset();
    slept.clear();
    job.setSleeperForTest(slept::add);
    dataService.setTeamEnableRoutePlanner(team1, true);
    seeder.seedGrid(team1, user1, 3);
    ref1 = TsidUtils.toString(team1.getId());
  }

  @AfterEach
  void restore() {
    job.setSleeperForTest(null);
    FakeRouteGeneratorGateway.reset();
  }

  private Report pass() {
    return job.runOnce(Instant.now(), Options.nightly());
  }

  private static Item itemOf(Report report, long teamId) {
    return report.items().stream().filter(i -> i.teamId() == teamId).findFirst().orElse(null);
  }

  private String digestNow() {
    return OverlayDigest.of(
        QuarkusTransaction.requiringNew()
            .call(() -> repository.fingerprint(team1.getId(), domain.getId())));
  }

  private List<Deposit> depositsOf(String ref) {
    return FakeRouteGeneratorGateway.DEPOSITS.stream().filter(d -> d.team().equals(ref)).toList();
  }

  // ---------------------------------------------------------------- what is deposited

  @Test
  void aTeamIsDepositedAsOneLinePerTrackAndAnEndLine() throws Exception {
    Report report = pass();
    assertTrue(report.ran());
    assertEquals("graph-test", report.graphId());
    assertEquals(Action.DEPOSIT, itemOf(report, team1.getId()).action());
    assertEquals(Reason.ABSENT, itemOf(report, team1.getId()).reason());

    List<Deposit> deposits = depositsOf(ref1);
    assertEquals(1, deposits.size());
    Deposit deposit = deposits.getFirst();
    assertEquals(digestNow(), deposit.digest());
    List<String> lines = deposit.lines();
    // a 3 x 3 grid: three rows and three columns, one track each, then the end line
    assertEquals(7, lines.size());
    for (int i = 0; i < 6; i++) {
      JsonNode line = JSON.readTree(lines.get(i));
      assertTrue(line.has("type"), lines.get(i));
      assertEquals(false, line.get("excluded").asBoolean());
      assertTrue(line.get("network_edges").isObject());
      assertTrue(line.get("network_edges").has("edges"));
    }
    assertEquals(6, JSON.readTree(lines.get(6)).get("end").get("tracks").asInt());
    assertNotNull(FakeRouteGeneratorGateway.overlayOf(ref1));
  }

  @Test
  void theStoredTextGoesInAsItIs() throws Exception {
    pass();
    String stored =
        (String)
            QuarkusTransaction.requiringNew()
                .call(() ->
                    em().createNativeQuery(
                            "select t.network_edges::text from gpx_tracks t order by t.id limit 1")
                        .getSingleResult());
    assertTrue(
        depositsOf(ref1)
            .getFirst()
            .lines()
            .getFirst()
            .contains("\"network_edges\":" + stored + "}"));
  }

  @Test
  void aDocumentThatIsNotCurrentGoesAsNullAndAnExcludedRouteIsFlagged() throws Exception {
    seeder.sql(
        "update team_entities set excluded_from_generator = true"
            + " where team_id = ?1 and entity_type = 2 and name = 'Row 0'",
        team1.getId());
    // a document computed from another original: not current
    seeder.sql(
        "update gpx_tracks set network_edges = jsonb_set(network_edges, '{rev}', '1')"
            + " where id = (select max(t.id) from gpx_tracks t"
            + " join team_entities te on te.id = t.route_id where te.team_id = ?1)",
        team1.getId());
    pass();
    List<String> lines = depositsOf(ref1).getFirst().lines();
    int excluded = 0;
    int nulls = 0;
    for (int i = 0; i < lines.size() - 1; i++) {
      JsonNode line = JSON.readTree(lines.get(i));
      excluded += line.get("excluded").asBoolean() ? 1 : 0;
      nulls += line.get("network_edges").isNull() ? 1 : 0;
    }
    assertEquals(1, excluded);
    assertEquals(1, nulls);
  }

  // ---------------------------------------------------------------- when nothing is sent

  @Test
  void aSecondPassWithoutChangeSendsNothing() {
    pass();
    assertEquals(1, depositsOf(ref1).size());
    Report second = pass();
    assertEquals(1, depositsOf(ref1).size());
    Item item = itemOf(second, team1.getId());
    assertEquals(Action.KEEP, item.action());
    assertEquals(Reason.CURRENT, item.reason());
  }

  @Test
  void aChangeOfTheTracksDepositsAgain() {
    pass();
    seeder.sql(
        "update team_entities set excluded_from_generator = true, version = version + 1"
            + " where team_id = ?1 and entity_type = 2 and name = 'Row 0'",
        team1.getId());
    assertEquals(Reason.CHANGED, itemOf(pass(), team1.getId()).reason());
    assertEquals(2, depositsOf(ref1).size());
    // and a new track too
    seeder.seedRow(team1, user1, "A new row", 1, 3);
    assertEquals(Reason.CHANGED, itemOf(pass(), team1.getId()).reason());
    assertEquals(3, depositsOf(ref1).size());
    assertEquals(Action.KEEP, itemOf(pass(), team1.getId()).action());
  }

  @Test
  void aStaleOverlayIsDepositedAgain() {
    pass();
    FakeRouteGeneratorGateway.overlayOf(ref1).state = "stale";
    assertEquals(Reason.STALE, itemOf(pass(), team1.getId()).reason());
    assertEquals(2, depositsOf(ref1).size());
    assertEquals("ready", FakeRouteGeneratorGateway.overlayOf(ref1).state);
  }

  @Test
  void anOverlayThatExpiresWithinSevenDaysIsDepositedAgain() {
    pass();
    // eight days later: it expires in six
    Instant later = Instant.now().plus(Duration.ofDays(8));
    assertEquals(
        Reason.EXPIRING, itemOf(job.runOnce(later, Options.nightly()), team1.getId()).reason());
    assertEquals(2, depositsOf(ref1).size());
    // six days later it still has eight days
    FakeRouteGeneratorGateway.reset();
    pass();
    Report early = job.runOnce(Instant.now().plus(Duration.ofDays(6)), Options.nightly());
    assertEquals(Reason.CURRENT, itemOf(early, team1.getId()).reason());
  }

  @Test
  void forceDepositsEveryServedTeam() {
    pass();
    Report report = job.runOnce(Instant.now(), new Options(null, true, false));
    assertEquals(Reason.FORCED, itemOf(report, team1.getId()).reason());
    assertEquals(2, depositsOf(ref1).size());
  }

  @Test
  void aDryRunSendsAndDeletesNothing() {
    Report report = job.runOnce(Instant.now(), new Options(null, false, true));
    assertTrue(report.ran());
    assertEquals(Action.DEPOSIT, itemOf(report, team1.getId()).action());
    assertEquals(0, FakeRouteGeneratorGateway.DEPOSITS.size());
    assertEquals(0, FakeRouteGeneratorGateway.calls("PUT", "/v1/generator/overlay"));
    assertEquals(0, FakeRouteGeneratorGateway.calls("DELETE", "/v1/generator/overlay"));
  }

  @Test
  void aSingleTeamCanBeTargeted() {
    dataService.setTeamEnableRoutePlanner(team2, true);
    Report report = job.runOnce(Instant.now(), new Options(team1.getId(), false, false));
    assertEquals(1, report.items().size());
    assertEquals(1, FakeRouteGeneratorGateway.DEPOSITS.size());
  }

  // ---------------------------------------------------------------- what is deleted

  @Test
  void aDeletedTeamAndATeamWithoutThePlannerLoseTheirOverlay() {
    dataService.setTeamEnableRoutePlanner(team2, true);
    seeder.seedGrid(team2, user1, 2);
    pass();
    String ref2 = TsidUtils.toString(team2.getId());
    assertNotNull(FakeRouteGeneratorGateway.overlayOf(ref1));
    assertNotNull(FakeRouteGeneratorGateway.overlayOf(ref2));

    dataService.setTeamEnableRoutePlanner(team1, false);
    seeder.sql("update teams set deleted = true where id = ?1", team2.getId());
    Report report = pass();

    assertEquals(Reason.PLANNER_OFF, itemOf(report, team1.getId()).reason());
    assertEquals(Action.DELETE, itemOf(report, team1.getId()).action());
    assertEquals(Reason.TEAM_GONE, itemOf(report, team2.getId()).reason());
    assertNull(FakeRouteGeneratorGateway.overlayOf(ref1));
    assertNull(FakeRouteGeneratorGateway.overlayOf(ref2));
    // a second pass has nothing left to delete
    assertEquals(0, pass().counts().deleted());
  }

  @Test
  void aTeamWithoutOverlayAndWithoutThePlannerIsNotEvenListed() {
    Report report = pass();
    // team2 has its planner off and never had an overlay
    assertNull(itemOf(report, team2.getId()));
    assertEquals(0, FakeRouteGeneratorGateway.calls("DELETE", "/v1/generator/overlay"));
  }

  // ---------------------------------------------------------------- failures

  @Test
  void anOverloadedEngineIsWaitedForThenSucceeds() {
    FakeRouteGeneratorGateway.DEPOSIT_PROBLEMS.add(new Problem(503, "overloaded", null, null, 4));
    Report report = pass();
    assertEquals(List.of(Duration.ofSeconds(4)), slept);
    assertEquals(1, report.counts().deposited());
    assertEquals(0, report.counts().failed());
    assertNotNull(FakeRouteGeneratorGateway.overlayOf(ref1));
  }

  @Test
  void anEngineThatStaysOverloadedSkipsTheTeamAfterThreeTries() {
    for (int i = 0; i < 3; i++) {
      FakeRouteGeneratorGateway.DEPOSIT_PROBLEMS.add(new Problem(503, "overloaded", null, null, 1));
    }
    Report report = pass();
    assertEquals(2, slept.size());
    assertEquals(1, report.counts().failed());
    assertNull(FakeRouteGeneratorGateway.overlayOf(ref1));
  }

  @Test
  void aDepositInProgressOrATimeoutMovesOnToTheNextTeam() {
    dataService.setTeamEnableRoutePlanner(team2, true);
    seeder.seedGrid(team2, user1, 2);
    FakeRouteGeneratorGateway.DEPOSIT_PROBLEMS.add(
        new Problem(409, "deposit_in_progress", null, null, null));
    Report report = pass();
    assertEquals(1, report.counts().failed());
    assertEquals(1, report.counts().deposited());
    assertNull(FakeRouteGeneratorGateway.overlayOf(ref1));
    assertNotNull(FakeRouteGeneratorGateway.overlayOf(TsidUtils.toString(team2.getId())));
  }

  @Test
  void aRefusedDepositIsLoggedAsAnErrorAndTheNextTeamStillRuns() {
    dataService.setTeamEnableRoutePlanner(team2, true);
    seeder.seedGrid(team2, user1, 2);
    FakeRouteGeneratorGateway.DEPOSIT_PROBLEMS.add(
        new Problem(413, "route_too_large", null, null, null));
    Report report = pass();
    assertEquals(1, report.counts().failed());
    assertEquals(1, report.counts().deposited());
  }

  @Test
  void anEngineWithoutItsDataEndsThePassAndNothingIsDeleted() {
    dataService.setTeamEnableRoutePlanner(team2, true);
    seeder.seedGrid(team2, user1, 2);
    FakeRouteGeneratorGateway.markReady(ref1, "an old digest");
    FakeRouteGeneratorGateway.DEPOSIT_PROBLEMS.add(
        new Problem(503, "data_unavailable", "x", null, null));
    Report report = pass();
    // the first team's deposit failed and ended the pass: the second was never tried
    assertEquals(0, report.counts().deposited());
    assertEquals(1, FakeRouteGeneratorGateway.calls("PUT", "/v1/generator/overlay"));
    assertNotNull(FakeRouteGeneratorGateway.overlayOf(ref1));
    assertEquals("an old digest", FakeRouteGeneratorGateway.overlayOf(ref1).digest);
    assertEquals(0, FakeRouteGeneratorGateway.calls("DELETE", "/v1/generator/overlay"));
  }

  @Test
  void aFullStorageEndsThePass() {
    FakeRouteGeneratorGateway.DEPOSIT_PROBLEMS.add(
        new Problem(507, "insufficient_storage", null, null, null));
    Report report = pass();
    assertEquals(0, report.counts().deposited());
  }

  // ---------------------------------------------------------------- when the pass does not start

  @Test
  void aSwitchedOffEngineGetsNothing() {
    FakeRouteGeneratorGateway.generatorEnabled = false;
    Report report = pass();
    assertFalse(report.ran());
    assertEquals(0, FakeRouteGeneratorGateway.CALLS.size());
  }

  @Test
  void anEngineBelowApi19GetsNothing() {
    FakeRouteGeneratorGateway.apiVersion = "1.8";
    assertFalse(pass().ran());
    assertEquals(0, FakeRouteGeneratorGateway.CALLS.size());
  }

  @Test
  void aPassHeldByAnotherBackendIsSkipped() throws Exception {
    try (Connection other = dataSource.getConnection();
        var statement =
            other.prepareStatement(
                "select pg_try_advisory_lock(hashtextextended('route-generator-overlays', 0))");
        ResultSet rs = statement.executeQuery()) {
      assertTrue(rs.next() && rs.getBoolean(1));
      Report report = pass();
      assertFalse(report.ran());
      assertEquals(0, FakeRouteGeneratorGateway.CALLS.size());
      try (var unlock =
          other.prepareStatement(
              "select pg_advisory_unlock(hashtextextended('route-generator-overlays', 0))")) {
        unlock.executeQuery().close();
      }
    }
    assertTrue(pass().ran());
  }

  // ---------------------------------------------------------------- the key never leaves

  @Test
  void theKeyAndTheDigestAreNeverInTheReport() {
    Report report = pass();
    String text = report.toString();
    assertFalse(text.contains(FakeRouteGeneratorGateway.TEST_KEY));
    assertFalse(text.contains(digestNow()));
  }

  private jakarta.persistence.EntityManager em() {
    return emHolder;
  }

  @Inject jakarta.persistence.EntityManager emHolder;
}
