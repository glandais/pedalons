package fr.pedalons.service.elevation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * {@code NetworkEdgesBackfill} (docs/LEDGER_*.md API-198, lot 1): which routes it queues, how it
 * spaces them, and that it leaves the rest alone.
 */
@QuarkusTest
class NetworkEdgesBackfillTest extends NetworkEdgesTestSupport {

  @Test
  void offByDefault_nothingIsQueued() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    backfill.setForTest(false, 30, true);

    assertEquals(0, backfill.enqueue(Instant.now()));

    assertNull(refresh(route));
  }

  private static void assertNull(Object value) {
    org.junit.jupiter.api.Assertions.assertNull(value);
  }

  @Test
  void onAnOlderService_nothingIsQueued() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    FakeRouteDetailsClient.apiVersion = "1.6";

    assertEquals(0, backfill.enqueue(Instant.now()));

    assertNull(refresh(route));
  }

  @Test
  void withTheEdgesSwitchedOff_nothingIsQueued() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    backfill.setForTest(true, 30, false);

    assertEquals(0, backfill.enqueue(Instant.now()));

    assertNull(refresh(route));
  }

  @Test
  void anHdRouteWithoutEdges_isQueuedAsABackfillRequest_onItsOriginal() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    assertTrue(edges(route).isEmpty());
    assertNull(refresh(route));

    assertEquals(1, backfill.enqueue(Instant.now()));

    ElevationRefresh request = refresh(route);
    assertNotNull(request);
    assertTrue(request.isBackfill());
    assertEquals(originalOf(route), request.getSourceRevision());
    assertEquals(0, request.getAttempts());
  }

  @Test
  void onlyTheRoutesThatNeedIt_areQueued() {
    RouteDto eligible = hdRouteWithoutEdges("Eligible");

    // Already has its edges
    RouteDto done = createRoute("Done");
    makeDue(done);
    worker.processDue();
    assertFalse(edges(done).isEmpty());

    // Still on the fast profile, with its own request
    RouteDto pending = createRoute("Pending");
    assertEquals(ElevationState.PENDING, storedState(pending));

    // HD, but behind the pipeline
    RouteDto behind = hdRouteWithoutEdges("Behind");
    QuarkusTransaction.requiringNew()
        .run(() -> routeRepository.update("elevationPipeline = null where id = ?1", id(behind)));

    // Deleted
    RouteDto deleted = hdRouteWithoutEdges("Deleted");
    QuarkusTransaction.requiringNew()
        .run(() -> routeRepository.update("deleted = true where id = ?1", id(deleted)));

    assertEquals(1, backfill.enqueue(Instant.now()));

    assertEquals(
        List.of(id(eligible)), backfillRows().stream().map(r -> r.getRoute().getId()).toList());
  }

  @Test
  void aRouteWithAnyRequest_isNotQueued_aGivenUpOneIncluded() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    QuarkusTransaction.requiringNew()
        .run(() ->
            backfillRepository.insert(
                new fr.pedalons.repository.route.NetworkEdgesBackfillRepository.Candidate(
                    id(route), 1000, originalOf(route)),
                Instant.now(),
                Instant.now()));
    QuarkusTransaction.requiringNew()
        .run(() ->
            refreshRepository.update(
                "attempts = ?1 where route.id = ?2",
                ElevationRefreshService.MAX_ATTEMPTS,
                id(route)));

    assertEquals(0, backfill.enqueue(Instant.now()));

    assertEquals(ElevationRefreshService.MAX_ATTEMPTS, refresh(route).getAttempts());
  }

  @Test
  void theDueTimes_areSpacedByTheCap_andASecondPassQueuesNothingNew() {
    RouteDto a = hdRouteWithoutEdges("A");
    RouteDto b = hdRouteWithoutEdges("B");
    RouteDto c = hdRouteWithoutEdges("C");
    Instant now = Instant.now();

    assertEquals(3, backfill.enqueue(now));

    // 30 calls an hour: one every two minutes; the most recent route first
    List<Instant> due = backfillRows().stream().map(ElevationRefresh::getDueAt).sorted().toList();
    assertEquals(3, due.size());
    assertEquals(120, Duration.between(due.get(0), due.get(1)).toSeconds(), 1);
    assertEquals(120, Duration.between(due.get(1), due.get(2)).toSeconds(), 1);
    assertEquals(
        id(c),
        backfillRows().stream()
            .min((x, y) -> x.getDueAt().compareTo(y.getDueAt()))
            .orElseThrow()
            .getRoute()
            .getId());
    assertNotNull(refresh(a));
    assertNotNull(refresh(b));

    assertEquals(0, backfill.enqueue(now.plusSeconds(1)), "idempotent");
    assertEquals(3, backfillRows().size());
  }

  @Test
  void theQueue_neverHoldsMoreThanTheWindow() {
    // 6 calls an hour: a 10 minutes window holds one
    backfill.setForTest(true, 6, true);
    hdRouteWithoutEdges("A");
    hdRouteWithoutEdges("B");

    assertEquals(1, backfill.enqueue(Instant.now()));
    assertEquals(0, backfill.enqueue(Instant.now()), "the window is full");
  }

  @Test
  void aSaveOfAQueuedRoute_makesItsRequestANormalOne() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    backfill.enqueue(Instant.now());
    assertTrue(refresh(route).isBackfill());

    updateRoute(route);

    ElevationRefresh request = refresh(route);
    assertFalse(request.isBackfill());
    assertEquals(ElevationState.PENDING, storedState(route));
  }
}
