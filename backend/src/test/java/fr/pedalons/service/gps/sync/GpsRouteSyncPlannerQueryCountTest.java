package fr.pedalons.service.gps.sync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.util.GpsSyncTestData;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The planner reads a domain in a fixed number of queries, whatever the number of registrations —
 * no query per registration, per route or per connection (docs/LEDGER_*.md API-120 §3.4, and the
 * per-page lookup rule of CLAUDE.md). Writes do grow with the rows that change, one upsert each,
 * and only on the first pass: a replay writes nothing. Same for the per-route state lookup.
 */
@QuarkusTest
class GpsRouteSyncPlannerQueryCountTest extends AbstractQueryCountTest {

  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsRouteSyncService syncService;
  @Inject GpsSyncTestData sync;

  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  /**
   * {@code count} rides within the horizon, user3 registered in each, with a GPX route; numbered
   * from {@code first} so that a second call does not reuse the slugs of the first.
   */
  private List<Long> seed(int first, int count, Instant now) {
    List<Long> routeIds = new ArrayList<>();
    for (int i = first; i < first + count; i++) {
      Ride ride =
          dataService.createRide(
              team1,
              user1,
              "Sortie " + i,
              "sortie-" + i,
              now.plus(1, ChronoUnit.DAYS).plusSeconds(i));
      Route route = sync.routeWithGpx(ride, user1, "Route " + i);
      dataService.setRideRoute(ride, route);
      RideGroup group = dataService.createRideGroup(user1, ride, "Groupe", 0);
      dataService.createParticipation(group, user3);
      routeIds.add(route.getId());
    }
    return routeIds;
  }

  private QueryStats.Counters measurePlan(String label, Instant now) {
    return queryStats.measureAll(label, () -> planner.plan(now));
  }

  @Test
  void planning_readsInConstantQueries() {
    Instant now = Instant.now();
    GpsServiceConnection small = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    seed(0, SMALL_PAGE, now);
    QueryStats.Counters smallFirst = measurePlan("planner first pass [" + SMALL_PAGE + "]", now);
    QueryStats.Counters smallReplay = measurePlan("planner replay [" + SMALL_PAGE + "]", now);
    assertEquals(SMALL_PAGE, sync.rows(small.getId()).size());

    seed(SMALL_PAGE, LARGE_PAGE - SMALL_PAGE, now);
    QueryStats.Counters largeFirst = measurePlan("planner first pass [" + LARGE_PAGE + "]", now);
    QueryStats.Counters largeReplay = measurePlan("planner replay [" + LARGE_PAGE + "]", now);
    assertEquals(LARGE_PAGE, sync.rows(small.getId()).size());

    long replayGrowth = largeReplay.statements() - smallReplay.statements();
    assertTrue(
        replayGrowth <= MAX_STATEMENT_GROWTH,
        () ->
            "The planner's replay cost "
                + smallReplay.statements()
                + " statements for "
                + SMALL_PAGE
                + " registrations and "
                + largeReplay.statements()
                + " for "
                + LARGE_PAGE
                + ": something is read per registration.\n"
                + queryStats.queryBreakdown(15));
    // The large first pass upserts the (LARGE - SMALL) new rows, one statement each, and nothing
    // more per row.
    long firstGrowth = largeFirst.statements() - smallFirst.statements();
    assertTrue(
        firstGrowth <= (LARGE_PAGE - SMALL_PAGE) + MAX_STATEMENT_GROWTH,
        () ->
            "The planner's first pass grew by "
                + firstGrowth
                + " statements for "
                + (LARGE_PAGE - SMALL_PAGE)
                + " new rows: more than one write each.\n"
                + queryStats.queryBreakdown(15));
  }

  @Test
  void routeStatuses_resolveInOneQueryWhateverTheNumberOfRoutes() {
    Instant now = Instant.now();
    sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    List<Long> routeIds = seed(0, LARGE_PAGE, now);
    planner.plan(now);

    long small =
        queryStats.measure(
            "route statuses [" + SMALL_PAGE + "]",
            () ->
                syncService.findRouteStatuses(
                    domain.getId(), user3.getId(), routeIds.subList(0, SMALL_PAGE)));
    long large =
        queryStats.measure(
            "route statuses [" + LARGE_PAGE + "]",
            () -> syncService.findRouteStatuses(domain.getId(), user3.getId(), routeIds));

    assertEquals(small, large);
    assertEquals(1, small);
    assertEquals(
        LARGE_PAGE, syncService.findRouteStatuses(domain.getId(), user3.getId(), routeIds).size());
  }
}
