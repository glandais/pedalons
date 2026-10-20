package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.valhalla.StadiaTraceAttributesClient;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.SurfaceRefreshRepository;
import fr.pedalons.repository.route.SurfaceRefreshRepository.BackfillBudget;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import javax.imageio.ImageIO;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md WEB-100 (C1c): the catch-up of the tracks saved before the surface existed. The
 * "old" tracks are created with the surface switched off (no request), then the catch-up is
 * switched on. No test reaches Stadia Maps.
 */
@QuarkusTest
class SurfaceBackfillTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();

  @InjectMock MapThumbnailRenderer renderer;
  @InjectMock @RestClient StadiaTraceAttributesClient client;

  @Inject RouteService routeService;
  @Inject GpxPreviewService previewService;
  @Inject GpxPreviewRepository previewRepository;
  @Inject SurfaceRefreshService service;
  @Inject SurfaceRefreshWorker worker;
  @Inject SurfaceBackfill backfill;
  @Inject SurfaceRefreshRepository refreshRepository;
  @Inject GpxTrackRepository trackRepository;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  private int routeCount;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    dataService.setTeamEnableRoutePlanner(team1, true);
    dataService.setDomainEnableGpxPlanner(domain, true);
    queryContext.setUserForTest(user1);
    routeCount = 0;
    try {
      doAnswer(
              invocation -> {
                File output = invocation.getArgument(0);
                ImageIO.write(new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB), "png", output);
                return null;
              })
          .when(renderer)
          .render(any(File.class), anyList(), anyString(), anyList());
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
    when(client.traceAttributes(any()))
        .thenAnswer(inv -> TraceFixtures.answer(inv.getArgument(0), i -> "paved"));
  }

  @AfterEach
  void restoreSwitches() {
    service.setEnabledForTest(false);
    backfill.setForTest(false, 300);
  }

  // ------------------------------------------------------------------ helpers

  private void on(int perHour) {
    service.setEnabledForTest(true);
    backfill.setForTest(true, perHour);
  }

  private static Instant now() {
    return Instant.now().truncatedTo(ChronoUnit.MILLIS);
  }

  private RouteDto createRoute(String prefix) {
    queryContext.setUserForTest(user1);
    routeCount++;
    return routeService.createRoute(
        team1Slug,
        new RouteRequest(
            prefix + " " + routeCount,
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null,
            null,
            null),
        EXAMPLE);
  }

  /** A route saved while the surface was off: no request. {@code ageDays} sets its created_at. */
  private Long oldRoute(int ageDays) {
    Long id = TsidUtils.toLong(createRoute("Ancien").id());
    sql(
        "update team_entities set created_at = ?1 where id = ?2",
        Instant.now().minus(ageDays, ChronoUnit.DAYS),
        id);
    return id;
  }

  private void sql(String statement, Object... params) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              var query = refreshRepository.getEntityManager().createNativeQuery(statement);
              for (int i = 0; i < params.length; i++) {
                Object p = params[i];
                query.setParameter(i + 1, p instanceof Instant t ? java.sql.Timestamp.from(t) : p);
              }
              query.executeUpdate();
            });
  }

  private record Row(Long target, boolean backfill, int attempts, Instant dueAt, long revision) {}

  /** Every request, by due time then id. */
  private List<Row> rows(String column) {
    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              @SuppressWarnings("unchecked")
              List<Object[]> found =
                  refreshRepository
                      .getEntityManager()
                      .createNativeQuery(
                          "select "
                              + column
                              + ", backfill, attempts, due_at, source_revision from surface_refresh"
                              + " where "
                              + column
                              + " is not null order by due_at, id")
                      .getResultList();
              List<Row> out = new ArrayList<>();
              for (Object[] r : found) {
                Object due = r[3];
                Instant dueAt =
                    due instanceof java.sql.Timestamp t
                        ? t.toInstant()
                        : due instanceof java.time.OffsetDateTime o ? o.toInstant() : (Instant) due;
                out.add(
                    new Row(
                        ((Number) r[0]).longValue(),
                        (Boolean) r[1],
                        ((Number) r[2]).intValue(),
                        dueAt,
                        ((Number) r[4]).longValue()));
              }
              return out;
            });
  }

  private List<Row> routeRows() {
    return rows("route_id");
  }

  private long refreshCount() {
    return QuarkusTransaction.requiringNew().call(() -> refreshRepository.count());
  }

  /** What a success leaves: a document on every track, the request deleted. */
  private void complete(Long routeId, TrackSurfaceDocument document) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              for (Long trackId :
                  trackRepository
                      .findIdsByRouteIds(List.of(routeId))
                      .getOrDefault(routeId, List.of())) {
                trackRepository.updateSurfaces(trackId, document);
              }
              refreshRepository.delete("route.id", routeId);
            });
  }

  private static TrackSurfaceDocument unavailable() {
    return TrackSurfaceDocument.unavailable("valhalla-444", 1000, "bicycle", Instant.now());
  }

  private Long oldPreview() {
    GpxPreview preview = previewService.create(EXAMPLE, "example.gpx");
    return preview.getId();
  }

  private void assertClose(Instant expected, Instant actual) {
    assertTrue(
        Math.abs(Duration.between(expected, actual).toMillis()) < 1500,
        "expected " + expected + " but was " + actual);
  }

  // ------------------------------------------------------------------ tests

  @Test
  void offSwitches_queueNothing() {
    oldRoute(1);

    service.setEnabledForTest(true);
    backfill.setForTest(false, 300);
    assertEquals(0, backfill.enqueue(Instant.now()));

    service.setEnabledForTest(false);
    backfill.setForTest(true, 300);
    assertEquals(0, backfill.enqueue(Instant.now()));

    on(0);
    assertEquals(0, backfill.enqueue(Instant.now()));
    assertEquals(0, refreshCount());
  }

  @Test
  void anOldRoute_isQueuedAsBackfill_onItsCurrentRevision() {
    Long id = oldRoute(1);
    Long revision =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    ((Number)
                            refreshRepository
                                .getEntityManager()
                                .createNativeQuery(
                                    "select file_id from assets where team_entity_id = ?1 and type"
                                        + " = 'ROUTE_ORIGINAL_GPX' order by id desc limit 1")
                                .setParameter(1, id)
                                .getSingleResult())
                        .longValue());
    on(300);
    Instant now = now();

    assertEquals(1, backfill.enqueue(now));

    List<Row> rows = routeRows();
    assertEquals(1, rows.size());
    Row row = rows.getFirst();
    assertEquals(id, row.target());
    assertTrue(row.backfill());
    assertEquals(0, row.attempts());
    assertEquals(revision, row.revision());
    assertEquals(now, row.dueAt());
  }

  @Test
  void mostRecentRoutesFirst_thenPreviews() {
    Long oldest = oldRoute(30);
    Long middle = oldRoute(20);
    Long newest = oldRoute(10);
    Long preview = oldPreview();
    on(18); // maxPending = 3
    Instant now = now();

    assertEquals(3, backfill.enqueue(now));

    List<Row> rows = routeRows();
    assertEquals(List.of(newest, middle, oldest), rows.stream().map(Row::target).toList());
    assertTrue(rows.get(0).dueAt().isBefore(rows.get(1).dueAt()));
    assertTrue(rows.get(1).dueAt().isBefore(rows.get(2).dueAt()));
    assertEquals(0, rows("preview_id").size(), "the preview waits for a free place");

    for (Long id : List.of(newest, middle, oldest)) {
      complete(id, unavailable());
    }
    assertEquals(1, backfill.enqueue(now));
    assertEquals(List.of(preview), rows("preview_id").stream().map(Row::target).toList());
  }

  @Test
  void dueTimesAreSpaced_byTheCap_andWeightedBySlices() {
    Long a = oldRoute(1);
    Long b = oldRoute(2);
    Long c = oldRoute(3);
    sql("update team_entities set distance = 400000 where id = ?1", b);
    on(60); // one call a minute
    Instant now = now();

    assertEquals(3, backfill.enqueue(now));

    List<Row> rows = routeRows();
    assertEquals(List.of(a, b, c), rows.stream().map(Row::target).toList());
    assertEquals(now, rows.get(0).dueAt());
    assertEquals(now.plusSeconds(60), rows.get(1).dueAt());
    // b is 400 km: three slices of 188 km, three calls
    assertEquals(now.plusSeconds(60 + 180), rows.get(2).dueAt());

    service.setEnabledForTest(false);
    Long d = oldRoute(9);
    service.setEnabledForTest(true);
    assertEquals(1, backfill.enqueue(now));
    Row last = routeRows().getLast();
    assertEquals(d, last.target());
    assertEquals(now.plusSeconds(60 + 180 + 60), last.dueAt(), "after the last slot, no overlap");
  }

  @Test
  void pendingIsCapped() {
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 12; i++) {
      ids.add(oldRoute(i + 1));
    }
    on(60); // maxPending = 10
    Instant now = now();

    assertEquals(10, backfill.enqueue(now));
    assertEquals(0, backfill.enqueue(now));

    for (Long id : ids.subList(0, 4)) {
      complete(id, unavailable());
    }
    assertEquals(2, backfill.enqueue(now), "only the 2 left over, the done ones have a surface");
    assertEquals(0, backfill.enqueue(now));
  }

  @Test
  void theRoom_isCountedInCalls_notInRequests() {
    List<Long> ids = new ArrayList<>();
    for (int i = 0; i < 4; i++) {
      Long id = oldRoute(i + 1);
      sql("update team_entities set distance = 400000 where id = ?1", id);
      ids.add(id);
    }
    on(60); // maxPending = 10 calls; a 400 km route is 3
    Instant now = now();

    assertEquals(3, backfill.enqueue(now), "9 calls queued, a fourth route would make 12");
    assertEquals(ids.subList(0, 3), routeRows().stream().map(Row::target).toList());
    assertEquals(9, budget().pending());
    assertEquals(0, backfill.enqueue(now));
    // The queue holds no more than the window: the last one is due within its ten minutes
    assertEquals(now.plusSeconds(2 * 180), routeRows().getLast().dueAt());
  }

  @Test
  void aTrackLongerThanTheWindow_isTaken_whenTheQueueIsEmpty() {
    Long longOne = oldRoute(1);
    sql("update team_entities set distance = 400000 where id = ?1", longOne);
    oldRoute(2);
    on(6); // maxPending = 1 call, the 400 km route is 3

    assertEquals(1, backfill.enqueue(now()), "never stuck behind a long track");
    assertEquals(List.of(longOne), routeRows().stream().map(Row::target).toList());
    assertEquals(0, backfill.enqueue(now()), "it holds the whole room until it is done");
  }

  @Test
  void nothingToRedo() {
    Long withDocument = oldRoute(1);
    complete(withDocument, unavailable());
    Long unavailableOne = oldRoute(2);
    complete(unavailableOne, unavailable());
    Long waiting = oldRoute(3);
    Long givenUp = oldRoute(4);
    Long deleted = oldRoute(5);
    Long noGpx = oldRoute(6);
    on(300);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Instant now = Instant.now();
              refreshRepository.requestForRoute(
                  waiting, 1L, now, Duration.ofSeconds(90), Duration.ofMinutes(10));
              refreshRepository.requestForRoute(
                  givenUp, 1L, now, Duration.ofSeconds(90), Duration.ofMinutes(10));
            });
    sql("update surface_refresh set attempts = 5 where route_id = ?1", givenUp);
    sql("update team_entities set deleted = true where id = ?1", deleted);
    sql("delete from assets where team_entity_id = ?1 and type = 'ROUTE_ORIGINAL_GPX'", noGpx);
    List<Row> before = routeRows();
    assertEquals(2, before.size());

    assertEquals(0, backfill.enqueue(Instant.now()));

    assertEquals(before, routeRows());
  }

  @Test
  void aDeletedTeam_isLeftAlone() {
    oldRoute(1);
    on(300);
    sql("update teams set deleted = true where id = ?1", team1.getId());

    assertEquals(0, backfill.enqueue(Instant.now()));

    sql("update teams set deleted = false where id = ?1", team1.getId());
    assertEquals(1, backfill.enqueue(Instant.now()));
  }

  @Test
  void aDeletedRoute_doesNotHoldASlot() {
    Long newer = oldRoute(1);
    Long older = oldRoute(2);
    on(6); // maxPending = 1
    Instant now = now();

    assertEquals(1, backfill.enqueue(now));
    assertEquals(newer, routeRows().getFirst().target());
    assertEquals(0, backfill.enqueue(now));

    sql("update team_entities set deleted = true where id = ?1", newer);
    assertEquals(1, backfill.enqueue(now));
    assertTrue(routeRows().stream().anyMatch(r -> r.target().equals(older)));
  }

  @Test
  void failingBackfillRequests_holdTheirSlots_butNotTheNextFreeTime() {
    for (int i = 0; i < 5; i++) {
      oldRoute(i + 1);
    }
    on(60);
    Instant now = now();
    assertEquals(5, backfill.enqueue(now));
    List<Row> rows = routeRows();
    // The first one is untried, the four others are in retry
    for (int i = 1; i < 5; i++) {
      sql("update surface_refresh set attempts = ?1 where route_id = ?2", i, rows.get(i).target());
    }

    BudgetView view = budget();

    assertEquals(5, view.pending());
    assertClose(rows.getFirst().dueAt().plusSeconds(60), view.nextFree());
  }

  private record BudgetView(int pending, Instant nextFree) {}

  private BudgetView budget() {
    BackfillBudget budget =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    refreshRepository.backfillBudget(
                        60, TraceSurfaceComputer.CORE_M, SurfaceRefreshService.MAX_ATTEMPTS));
    return new BudgetView(budget.pending(), budget.nextFree());
  }

  @Test
  void previews_onlyCurrentOnes() {
    Long noRevision = oldPreview();
    Long expired = oldPreview();
    Long current = oldPreview();
    Long otherRevision = oldPreview();
    Long bare = oldPreview();
    sql("update gpx_previews set files_revision = null where id = ?1", noRevision);
    sql(
        "update gpx_previews set created_at = ?1 where id = ?2",
        Instant.now().minus(40, ChronoUnit.DAYS),
        expired);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxPreview c = previewRepository.findById(current);
              c.setSurfaces(
                  new PreviewSurfacesDocument(c.getFilesRevision(), List.of(unavailable())));
              GpxPreview o = previewRepository.findById(otherRevision);
              o.setSurfaces(
                  new PreviewSurfacesDocument(o.getFilesRevision() + 1, List.of(unavailable())));
            });
    on(300);

    assertEquals(2, backfill.enqueue(Instant.now()));

    assertEquals(
        List.of(otherRevision, bare).stream().sorted().toList(),
        rows("preview_id").stream().map(Row::target).sorted().toList());
    assertTrue(rows("preview_id").stream().allMatch(Row::backfill));
  }

  @Test
  void twoPasses_neverDoubleARequest() throws Exception {
    for (int i = 0; i < 12; i++) {
      oldRoute(i + 1);
    }
    on(60); // maxPending = 10
    Instant now = now();

    CompletableFuture<Integer> first = CompletableFuture.supplyAsync(() -> backfill.enqueue(now));
    CompletableFuture<Integer> second = CompletableFuture.supplyAsync(() -> backfill.enqueue(now));

    int queued = first.get() + second.get();
    List<Row> rows = routeRows();
    assertEquals(queued, rows.size());
    assertEquals(10, rows.size());
    assertEquals(rows.size(), rows.stream().map(Row::target).distinct().count());
  }

  @Test
  void aSave_turnsABackfillRequestIntoANormalOne() {
    RouteDto dto = createRoute("Ancien");
    Long id = TsidUtils.toLong(dto.id());
    on(300);
    assertEquals(1, backfill.enqueue(now()));
    Row queued = routeRows().getFirst();
    assertTrue(queued.backfill());

    queryContext.setUserForTest(user1);
    routeService.updateRoute(
        team1Slug,
        dto.slug(),
        new RouteRequest(
            dto.name(),
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null,
            null,
            null),
        EXAMPLE);

    Row saved = routeRows().getFirst();
    assertEquals(id, saved.target());
    assertFalse(saved.backfill());
    assertNotEquals(queued.revision(), saved.revision());
    assertClose(Instant.now().plusSeconds(90), saved.dueAt());
  }

  @Test
  void theWorker_servesNormalRequestsFirst() {
    Long routeId = oldRoute(1);
    on(300);
    // A normal request for a preview, made by its save
    Long previewId = oldPreview();
    assertEquals(1, backfill.enqueue(now()));
    Instant past = Instant.now().minusSeconds(5);
    sql("update surface_refresh set due_at = ?1", past);

    Instant now = Instant.now();
    assertTrue(service.claimNext(now, false).isEmpty());
    var preview = service.claimNextPreview(now, false);
    assertTrue(preview.isPresent());
    assertEquals(previewId, preview.get().previewId());
    assertTrue(service.claimNextPreview(now, true).isEmpty());
    var route = service.claimNext(now, true);
    assertTrue(route.isPresent());
    assertEquals(routeId, route.get().routeId());
    assertEquals(SurfaceRefreshService.Outcome.REFRESHED, service.processPreview(preview.get()));
    assertEquals(SurfaceRefreshService.Outcome.REFRESHED, service.process(route.get()));
    assertEquals(0, refreshCount());
  }

  @Test
  void theWorker_processesBoth_normalFirst() {
    Long routeId = oldRoute(1);
    on(300);
    Long previewId = oldPreview();
    assertEquals(1, backfill.enqueue(now()));
    sql("update surface_refresh set due_at = ?1", Instant.now().minusSeconds(5));

    assertEquals(2, worker.processDue());

    assertEquals(0, refreshCount());
    Instant routeAt =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    trackRepository.findSurfaces(routeId).values().iterator().next().computedAt());
    Instant previewAt =
        QuarkusTransaction.requiringNew()
            .call(() -> previewRepository.findSurfaces(previewId).tracks().getFirst().computedAt());
    assertFalse(routeAt.isBefore(previewAt), "the catch-up's route comes after the normal preview");
  }

  @Test
  void leaveToBackfill_dropsOnlyTheNormalUntriedRequest() {
    on(300);
    // Normal requests, made by saves (surface on)
    Long untried = oldRouteWithRequest();
    Long retrying = oldRouteWithRequest();
    sql("update surface_refresh set attempts = 2 where route_id = ?1", retrying);
    // A catch-up request
    service.setEnabledForTest(false);
    Long queued = oldRoute(1);
    service.setEnabledForTest(true);
    assertEquals(1, backfill.enqueue(now()));
    assertEquals(3, refreshCount());

    for (Long id : List.of(untried, retrying, queued)) {
      QuarkusTransaction.requiringNew().run(() -> service.leaveToBackfill(id));
    }

    assertEquals(
        List.of(queued, retrying).stream().sorted().toList(),
        routeRows().stream().map(Row::target).sorted().toList());
    assertNotEquals(0, refreshCount());
  }

  private Long oldRouteWithRequest() {
    return TsidUtils.toLong(createRoute("Neuf").id());
  }
}
