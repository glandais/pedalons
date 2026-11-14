package fr.pedalons.service.elevation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.repository.route.ElevationRefreshRepository.Claim;
import fr.pedalons.repository.route.NetworkEdgesBackfillRepository.Candidate;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * A backfill request on a route whose profile is up to date is served by the edges-only path
 * (docs/LEDGER_*.md API-198, lot 1): the documents are written and nothing else moves.
 */
@QuarkusTest
class ElevationRefreshEdgesOnlyTest extends NetworkEdgesTestSupport {

  /** What a GPS service would see change, and the profile. */
  private record Snapshot(
      ElevationState state,
      Short pipeline,
      Float distance,
      int points,
      Map<AssetType, String> assets) {}

  private Snapshot snapshot(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> {
          var r = routeRepository.findById(id(route));
          int points = r.getTracks().stream().mapToInt(t -> t.getTrackPoints().size()).sum();
          Map<AssetType, String> assets =
              assetRepository.list("teamEntity.id = ?1", id(route)).stream()
                  .collect(
                      java.util.stream.Collectors.toMap(
                          a -> a.getType(), a -> a.getFileId() + "/" + a.getContentRevision()));
          return new Snapshot(
              r.getElevationState(), r.getElevationPipeline(), r.getDistance(), points, assets);
        });
  }

  private Claim claimBackfill() {
    return service.claimNext(Instant.now(), true).orElseThrow();
  }

  private void queued(RouteDto route) {
    assertEquals(1, backfill.enqueue(Instant.now()));
    makeDue(route);
  }

  @Test
  void aBackfillRow_isServedByTheEdgesOnlyPath_andNothingElseMoves() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    Snapshot before = snapshot(route);
    queued(route);

    Claim claim = claimBackfill();
    assertTrue(claim.backfill());
    assertEquals(ElevationRefreshService.Outcome.EDGES, service.process(claim));

    assertEquals(before, snapshot(route), "no new file, no profile, nothing a GPS service sees");
    Map<Long, NetworkEdgesDocument> documents = edges(route);
    assertFalse(documents.isEmpty());
    for (NetworkEdgesDocument d : documents.values()) {
      assertEquals(NetworkEdgesDocument.VERSION, d.v());
      assertEquals(originalOf(route), d.rev());
      assertEquals("full", d.profile());
      assertTrue(d.ok());
    }
    assertNull(refresh(route));
    var call = FakeRouteDetailsClient.REQUESTS.getLast().options();
    assertTrue(call.wantsEdges());
    assertEquals(
        documents.size(), FakeRouteDetailsClient.REQUESTS.size(), "one call per track, no more");
  }

  @Test
  void theWorker_servesBackfillRowsAfterTheNormalOnes() {
    RouteDto edgesOnly = hdRouteWithoutEdges("Boucle");
    queued(edgesOnly);
    RouteDto normal = createRoute("Neuve");
    makeDue(normal);

    assertEquals(2, worker.processDue());

    assertEquals(ElevationState.HD, storedState(normal));
    assertFalse(edges(edgesOnly).isEmpty());
    assertNull(refresh(edgesOnly));
    assertNull(refresh(normal));
  }

  @Test
  void documentsAlreadyAtTheRevision_deleteTheRow_withoutACall() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    queued(route);
    assertEquals(ElevationRefreshService.Outcome.EDGES, service.process(claimBackfill()));
    // Queued again by hand, as a race with a catch-up would leave it
    QuarkusTransaction.requiringNew()
        .run(() ->
            backfillRepository.insert(
                new Candidate(id(route), 1000, originalOf(route)), Instant.now(), Instant.now()));
    FakeRouteDetailsClient.REQUESTS.clear();

    assertEquals(ElevationRefreshService.Outcome.GONE, service.process(claimBackfill()));

    assertTrue(FakeRouteDetailsClient.REQUESTS.isEmpty());
    assertNull(refresh(route));
  }

  @Test
  void whenTheServiceAnnouncesNoEdges_theRowIsPutOffAnHour_withoutAnAttempt() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    queued(route);
    FakeRouteDetailsClient.apiVersion = "1.6";
    Instant now = Instant.now();

    Claim claim = claimBackfill();
    assertEquals(ElevationRefreshService.Outcome.POSTPONED, service.process(claim));

    ElevationRefresh row = refresh(route);
    assertNotNull(row);
    assertEquals(0, row.getAttempts());
    assertNull(row.getClaimedUntil());
    assertEquals(3600, Duration.between(now, row.getDueAt()).toSeconds(), 5);
    assertTrue(edges(route).isEmpty());
    assertTrue(FakeRouteDetailsClient.REQUESTS.isEmpty());
  }

  @Test
  void anAnswerWithoutEdges_isAFailure_giveUpAfterFive_theRouteStaysHd() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    queued(route);
    FakeRouteDetailsClient.noEdges = true;

    for (int attempt = 1; attempt <= ElevationRefreshService.MAX_ATTEMPTS; attempt++) {
      makeDue(route);
      assertEquals(ElevationRefreshService.Outcome.FAILED, service.process(claimBackfill()));
      assertEquals(attempt, refresh(route).getAttempts());
    }

    assertEquals(ElevationState.HD, storedState(route));
    assertTrue(edges(route).isEmpty());
    assertTrue(service.claimNext(Instant.now().plus(Duration.ofDays(1)), true).isEmpty());
    var abandoned =
        QuarkusTransaction.requiringNew()
            .call(() ->
                refreshRepository.findAbandoned(
                    domain.getId(), ElevationRefreshService.MAX_ATTEMPTS, 100, null));
    assertTrue(abandoned.stream().anyMatch(a -> a.targetId().equals(id(route))));
    // And a pass does not queue it again
    assertEquals(0, backfill.enqueue(Instant.now()));
  }

  @Test
  void theOriginalReplacedBeforeTheWrite_writesNothing() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    queued(route);
    Claim claim = claimBackfill();
    List<NetworkEdgesDocument> documents =
        List.of(NetworkEdgesDocument.tooShort(claim.sourceRevision(), Instant.now(), 0));

    updateRoute(route);

    assertEquals(
        ElevationRefreshService.Outcome.REALIGNED, service.writeEdgesOnly(claim, documents));
    assertTrue(edges(route).isEmpty());
    assertFalse(refresh(route).isBackfill(), "the save's request, not the backfill's");
  }

  @Test
  void aRouteBehindThePipeline_isServedByTheFullPath_asBefore() {
    RouteDto route = hdRouteWithoutEdges("Boucle");
    QuarkusTransaction.requiringNew()
        .run(() -> {
          backfillRepository.insert(
              new Candidate(id(route), 1000, originalOf(route)),
              Instant.now(),
              Instant.now().minusSeconds(1));
          routeRepository.update("elevationPipeline = null where id = ?1", id(route));
        });
    Snapshot before = snapshot(route);

    assertEquals(ElevationRefreshService.Outcome.REFRESHED, service.process(claimBackfill()));

    Snapshot after = snapshot(route);
    assertFalse(before.assets().equals(after.assets()), "a full recompute writes new files");
    assertFalse(edges(route).isEmpty(), "and its edges, from the same answer");
  }
}
