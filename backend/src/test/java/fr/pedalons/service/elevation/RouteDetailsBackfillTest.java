package fr.pedalons.service.elevation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TrackSurfaceState;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository.BackfillBudget;
import fr.pedalons.repository.route.ElevationRefreshRepository.BackfillRemaining;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.surface.SurfaceRefreshService;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.InputStream;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.CompletableFuture;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-150, phase D: the recomputation of the fleet. The "old" tracks are saved now,
 * then lose their request and go back to what an old track looks like: HD, behind the pipeline.
 * Ported from the catch-up it replaces, on the fake of osm-route-details. The surface being off in
 * the test profile, each test turns it on ({@link #on}): the catch-up stops without it.
 */
@QuarkusTest
class RouteDetailsBackfillTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();
  private static final Short PIPELINE = (short) GpxPipeline.VERSION;

  @InjectMock MapThumbnailRenderer renderer;

  @Inject RouteService routeService;
  @Inject GpxPreviewService previewService;
  @Inject GpxPreviewRepository previewRepository;
  @Inject RouteRepository routeRepository;
  @Inject AssetRepository assetRepository;
  @Inject SurfaceRefreshService surfaceService;
  @Inject ElevationRefreshService service;
  @Inject ElevationRefreshWorker worker;
  @Inject RouteDetailsBackfill backfill;
  @Inject ElevationRefreshRepository refreshRepository;
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
    service.setAsyncHdEnabledForTest(true);
  }

  @AfterEach
  void restoreSwitches() {
    surfaceService.setEnabledForTest(false);
    backfill.setForTest(false, 60);
    service.setAsyncHdEnabledForTest(true);
  }

  // ------------------------------------------------------------------ helpers

  private void on(int perHour) {
    surfaceService.setEnabledForTest(true);
    backfill.setForTest(true, perHour);
  }

  private static Instant now() {
    return Instant.now().truncatedTo(ChronoUnit.MILLIS);
  }

  private static RouteRequest request(String name) {
    return new RouteRequest(
        name,
        MediaDto.builder().markdown("Parcours").build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null,
        null,
        null);
  }

  private RouteDto createRoute(String prefix) {
    queryContext.setUserForTest(user1);
    routeCount++;
    return routeService.createRoute(team1Slug, request(prefix + " " + routeCount), EXAMPLE);
  }

  /** A route of an earlier pipeline, nothing queued. {@code ageDays} sets its created_at. */
  private Long oldRoute(int ageDays) {
    return oldRoute(ageDays, null);
  }

  private Long oldRoute(int ageDays, Integer pipeline) {
    Long id = TsidUtils.toLong(createRoute("Ancien").id());
    sql("delete from elevation_refresh where route_id = ?1", id);
    sql(
        "update team_entities set created_at = ?1, elevation_state = 'HD' where id = ?2",
        Instant.now().minus(ageDays, ChronoUnit.DAYS),
        id);
    if (pipeline != null) {
      sql("update team_entities set elevation_pipeline = ?1 where id = ?2", pipeline, id);
    }
    return id;
  }

  private Long oldPreview() {
    Long id = previewService.create(EXAMPLE, "example.gpx").getId();
    sql("delete from elevation_refresh where preview_id = ?1", id);
    sql(
        "update gpx_previews set elevation_state = 'HD', elevation_pipeline = null where id = ?1",
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
              List<Row> out = new ArrayList<>();
              for (ElevationRefresh r : refreshRepository.list("order by dueAt, id")) {
                Long target =
                    "route_id".equals(column)
                        ? (r.getRoute() == null ? null : r.getRoute().getId())
                        : (r.getPreview() == null ? null : r.getPreview().getId());
                if (target != null) {
                  out.add(
                      new Row(
                          target,
                          r.isBackfill(),
                          r.getAttempts(),
                          r.getDueAt(),
                          r.getSourceRevision()));
                }
              }
              return out;
            });
  }

  private List<Row> routeRows() {
    return rows("route_id");
  }

  private List<Row> previewRows() {
    return rows("preview_id");
  }

  private long refreshCount() {
    return QuarkusTransaction.requiringNew().call(() -> refreshRepository.count());
  }

  private long originalFileId(Long routeId) {
    return QuarkusTransaction.requiringNew()
        .call(() -> assetRepository.findCurrentFileId(routeId, AssetType.ROUTE_ORIGINAL_GPX));
  }

  /** What a done recompute leaves: the current pipeline, the request deleted. */
  private void done(Long routeId) {
    sql(
        "update team_entities set elevation_pipeline = ?1 where id = ?2",
        (int) GpxPipeline.VERSION,
        routeId);
    sql("delete from elevation_refresh where route_id = ?1", routeId);
  }

  private void makeDue() {
    sql("update elevation_refresh set due_at = ?1", Instant.now().minusSeconds(5));
  }

  private void failAll() {
    for (int i = 0; i < ElevationRefreshService.MAX_ATTEMPTS; i++) {
      makeDue();
      worker.processDue();
    }
  }

  private Route route(Long id) {
    return QuarkusTransaction.requiringNew().call(() -> routeRepository.findById(id));
  }

  private GpxPreview preview(Long id) {
    return QuarkusTransaction.requiringNew().call(() -> previewRepository.findById(id));
  }

  private double[] elevationRange(Long id) {
    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              double min = Double.MAX_VALUE;
              double max = -Double.MAX_VALUE;
              for (GpxTrack track : routeRepository.findById(id).getTracks()) {
                for (GpxTrack.TrackPoint p : track.getTrackPoints()) {
                  min = Math.min(min, p.ele());
                  max = Math.max(max, p.ele());
                }
              }
              return new double[] {min, max};
            });
  }

  /** A document of osm-surface, as a track recomputed before this pipeline carries it. */
  private void withV1Document(Long routeId) {
    TrackSurfaceDocument document =
        new TrackSurfaceDocument(
            TrackSurfaceDocument.VERSION,
            TrackSurfaceDocument.STATUS_OK,
            null,
            null,
            Instant.now(),
            "bicycle",
            1000,
            List.of(new TrackSurfaceDocument.SurfaceRange(0, 1000, "asphalt")),
            List.of());
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              for (Long trackId :
                  trackRepository
                      .findIdsByRouteIds(List.of(routeId))
                      .getOrDefault(routeId, List.of())) {
                trackRepository.updateSurfaces(trackId, document);
              }
            });
  }

  private TrackSurfaceDocument document(Long routeId) {
    Map<Long, TrackSurfaceDocument> found =
        QuarkusTransaction.requiringNew().call(() -> trackRepository.findSurfaces(routeId));
    return found.isEmpty() ? null : found.values().iterator().next();
  }

  private record BudgetView(int pending, Instant nextFree) {}

  private BudgetView budget() {
    BackfillBudget budget =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    refreshRepository.backfillBudget(
                        60, RouteDetailsBackfill.CALL_M, ElevationRefreshService.MAX_ATTEMPTS));
    return new BudgetView(budget.pending(), budget.nextFree());
  }

  private void assertClose(Instant expected, Instant actual) {
    assertTrue(
        Math.abs(Duration.between(expected, actual).toMillis()) < 1500,
        "expected " + expected + " but was " + actual);
  }

  // ------------------------------------------------------------------ the switches

  /** Deploying must never start it: the profile of the tests hides the real default. */
  @Test
  void offByDefault_inEveryProfile() throws Exception {
    Properties properties = new Properties();
    // The source file: on the test classpath, the name resolves to another one
    try (InputStream in =
        java.nio.file.Files.newInputStream(
            java.nio.file.Path.of("src/main/resources/application.properties"))) {
      properties.load(in);
    }
    assertEquals(
        "${ROUTE_DETAILS_BACKFILL_ENABLED:false}",
        properties.getProperty("pedalons.route-details.backfill.enabled"));
  }

  @Test
  void offSwitches_queueNothing() {
    oldRoute(1);

    surfaceService.setEnabledForTest(true);
    backfill.setForTest(false, 60);
    assertEquals(0, backfill.enqueue(Instant.now()));

    surfaceService.setEnabledForTest(false);
    backfill.setForTest(true, 60);
    assertEquals(0, backfill.enqueue(Instant.now()));

    on(0);
    assertEquals(0, backfill.enqueue(Instant.now()));
    assertEquals(0, refreshCount());
  }

  // ------------------------------------------------------------------ what is queued

  @Test
  void anOldRoute_isQueuedAsBackfill_onItsCurrentRevision() {
    Long id = oldRoute(1);
    long revision = originalFileId(id);
    on(60);
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
    assertEquals(ElevationState.HD, route(id).getElevationState(), "nothing reads as pending");
  }

  @Test
  void pipelineTwoAndNull_areCandidates_pipelineThreeIsNot() {
    Long none = oldRoute(1);
    Long two = oldRoute(2, 2);
    Long current = oldRoute(3, GpxPipeline.VERSION);
    on(60);

    assertEquals(2, backfill.enqueue(now()));

    assertEquals(List.of(none, two), routeRows().stream().map(Row::target).toList());
    assertNull(
        QuarkusTransaction.requiringNew()
            .call(() -> refreshRepository.findByRouteId(current).orElse(null)));
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
    assertEquals(0, previewRows().size(), "the preview waits for a free place");

    for (Long id : List.of(newest, middle, oldest)) {
      done(id);
    }
    assertEquals(1, backfill.enqueue(now));
    assertEquals(List.of(preview), previewRows().stream().map(Row::target).toList());
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

    Long d = oldRoute(9);
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
      done(id);
    }
    assertEquals(
        2, backfill.enqueue(now), "only the 2 left over, the done ones are on the version");
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
  void aDeletedTeam_isLeftAlone() {
    oldRoute(1);
    on(60);
    sql("update teams set deleted = true where id = ?1", team1.getId());

    assertEquals(0, backfill.enqueue(Instant.now()));

    sql("update teams set deleted = false where id = ?1", team1.getId());
    assertEquals(1, backfill.enqueue(Instant.now()));
  }

  @Test
  void aDeletedRoute_isNoCandidate_andDoesNotHoldASlot() {
    Long newer = oldRoute(1);
    Long older = oldRoute(2);
    Long deleted = oldRoute(3);
    sql("update team_entities set deleted = true where id = ?1", deleted);
    on(6); // maxPending = 1
    Instant now = now();

    assertEquals(1, backfill.enqueue(now));
    assertEquals(newer, routeRows().getFirst().target());
    assertEquals(0, backfill.enqueue(now));

    sql("update team_entities set deleted = true where id = ?1", newer);
    assertEquals(1, backfill.enqueue(now));
    assertTrue(routeRows().stream().anyMatch(r -> r.target().equals(older)));
    assertTrue(routeRows().stream().noneMatch(r -> r.target().equals(deleted)));
  }

  @Test
  void aRouteWithoutOriginal_orWithoutTrack_isNoCandidate() {
    Long noOriginal = oldRoute(1);
    Long noTrack = oldRoute(2);
    sql("delete from assets where team_entity_id = ?1 and type = 'ROUTE_ORIGINAL_GPX'", noOriginal);
    sql("delete from gpx_tracks where route_id = ?1", noTrack);
    on(60);

    assertEquals(0, backfill.enqueue(Instant.now()));
    assertEquals(0, refreshCount());
  }

  @Test
  void previews_onlyCurrentOnes() {
    Long flat = oldPreview();
    Long expired = oldPreview();
    Long onTheVersion = oldPreview();
    Long two = oldPreview();
    Long none = oldPreview();
    sql("update gpx_previews set files_revision = null where id = ?1", flat);
    sql(
        "update gpx_previews set created_at = ?1 where id = ?2",
        Instant.now().minus(40, ChronoUnit.DAYS),
        expired);
    sql(
        "update gpx_previews set elevation_pipeline = ?1 where id = ?2",
        (int) GpxPipeline.VERSION,
        onTheVersion);
    sql("update gpx_previews set elevation_pipeline = 2 where id = ?1", two);
    on(60);

    assertEquals(2, backfill.enqueue(Instant.now()));

    assertEquals(
        List.of(two, none).stream().sorted().toList(),
        previewRows().stream().map(Row::target).sorted().toList());
    assertTrue(previewRows().stream().allMatch(Row::backfill));
    assertEquals(
        preview(none).getFilesRevision(),
        previewRows().stream()
            .filter(r -> r.target().equals(none))
            .findFirst()
            .orElseThrow()
            .revision());
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
      sql(
          "update elevation_refresh set attempts = ?1 where route_id = ?2",
          i,
          rows.get(i).target());
    }

    BudgetView view = budget();

    assertEquals(5, view.pending());
    assertClose(rows.getFirst().dueAt().plusSeconds(60), view.nextFree());
  }

  // ------------------------------------------------------------------ with the other requests

  /** A bulk import (biketeam) saves routes the same way: their own catch-up, under no cap. */
  @Test
  void aFastSave_isNoCandidate_itHasItsRequest() {
    Long route = TsidUtils.toLong(createRoute("Neuf").id());
    Long preview = previewService.create(EXAMPLE, "example.gpx").getId();
    on(60);

    assertEquals(0, backfill.enqueue(Instant.now()));

    assertEquals(2, refreshCount());
    assertFalse(routeRows().getFirst().backfill());
    assertEquals(route, routeRows().getFirst().target());
    assertFalse(previewRows().getFirst().backfill());
    assertEquals(preview, previewRows().getFirst().target());
  }

  @Test
  void aNormalSave_turnsABackfillRowNormal_andForgetsItsAttempts() {
    RouteDto dto = createRoute("Ancien");
    Long id = TsidUtils.toLong(dto.id());
    sql("delete from elevation_refresh where route_id = ?1", id);
    sql("update team_entities set elevation_state = 'HD' where id = ?1", id);
    on(60);
    assertEquals(1, backfill.enqueue(now()));
    Row queued = routeRows().getFirst();
    assertTrue(queued.backfill());
    sql("update elevation_refresh set attempts = 2, last_error = 'boom' where route_id = ?1", id);

    queryContext.setUserForTest(user1);
    routeService.updateRoute(team1Slug, dto.slug(), request(dto.name()), EXAMPLE);

    Row saved = routeRows().getFirst();
    assertEquals(id, saved.target());
    assertFalse(saved.backfill(), "the save's track waits behind nothing");
    assertEquals(0, saved.attempts());
    assertNotEquals(queued.revision(), saved.revision());
    assertEquals(1, service.claimNext(saved.dueAt().plusSeconds(1), false).stream().count());
  }

  @Test
  void theWorker_servesNormalRequestsFirst() {
    Long routeId = oldRoute(1);
    on(60);
    Long previewId = previewService.create(EXAMPLE, "example.gpx").getId();
    assertEquals(1, backfill.enqueue(now()));
    makeDue();

    Instant now = Instant.now();
    assertTrue(service.claimNext(now, false).isEmpty());
    var preview = service.claimNextPreview(now, false);
    assertTrue(preview.isPresent());
    assertEquals(previewId, preview.get().previewId());
    assertTrue(service.claimNextPreview(now, true).isEmpty());
    var route = service.claimNext(now, true);
    assertTrue(route.isPresent());
    assertEquals(routeId, route.get().routeId());
  }

  @Test
  void theWorker_processesBoth_normalFirst() {
    Long routeId = oldRoute(1);
    on(60);
    Long previewId = previewService.create(EXAMPLE, "example.gpx").getId();
    assertEquals(1, backfill.enqueue(now()));
    makeDue();

    assertEquals(2, worker.processDue());

    assertEquals(0, refreshCount());
    Instant routeAt = document(routeId).computedAt();
    Instant previewAt =
        QuarkusTransaction.requiringNew()
            .call(() -> previewRepository.findSurfaces(previewId).tracks().getFirst().computedAt());
    assertFalse(routeAt.isBefore(previewAt), "the catch-up's route comes after the normal preview");
  }

  // ------------------------------------------------------------------ the recompute

  @Test
  void aBackfillRecompute_writesProfileSurfaceAndPipeline_andLeavesTheStateAlone() {
    Long id = oldRoute(1, 2);
    withV1Document(id);
    double[] before = elevationRange(id);
    assertEquals(FakeRouteDetailsClient.FAST_ELEVATION, before[0], 0.01, "the fast profile");
    on(60);
    assertEquals(1, backfill.enqueue(now()));
    assertEquals(ElevationState.HD, route(id).getElevationState());
    makeDue();

    assertEquals(1, worker.processDue());

    assertEquals(PIPELINE, route(id).getElevationPipeline());
    assertEquals(ElevationState.HD, route(id).getElevationState());
    double[] after = elevationRange(id);
    assertEquals(FakeRouteDetailsClient.FULL_ELEVATION, after[0], 0.01);
    assertEquals(FakeRouteDetailsClient.FULL_ELEVATION, after[1], 0.01);
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, document(id).version());
    assertEquals(0, refreshCount());

    assertEquals(0, backfill.enqueue(Instant.now()), "done: no candidate any more");
  }

  @Test
  void aBackfillRecompute_ofAPreview_stampsIt() {
    Long id = oldPreview();
    on(60);
    assertEquals(1, backfill.enqueue(now()));
    makeDue();

    assertEquals(1, worker.processDue());

    GpxPreview after = preview(id);
    assertEquals(PIPELINE, after.getElevationPipeline());
    assertEquals(ElevationState.HD, after.getElevationState());
    assertEquals(0, backfill.enqueue(Instant.now()));
  }

  /** Five failures: nothing changes for the members, and the loop ends there. */
  @Test
  void anAbandonedTarget_isNotQueuedAgain() {
    Long id = oldRoute(1, 2);
    withV1Document(id);
    double[] before = elevationRange(id);
    on(60);
    assertEquals(1, backfill.enqueue(now()));
    FakeRouteDetailsClient.failFull = true;

    failAll();

    Row row = routeRows().getFirst();
    assertEquals(ElevationRefreshService.MAX_ATTEMPTS, row.attempts());
    assertEquals(ElevationState.HD, route(id).getElevationState(), "not FAST: its profile is HD");
    assertEquals(Short.valueOf((short) 2), route(id).getElevationPipeline());
    assertEquals(before[0], elevationRange(id)[0], 0.01);
    assertEquals(TrackSurfaceDocument.VERSION, document(id).version());

    FakeRouteDetailsClient.failFull = false;
    assertEquals(0, backfill.enqueue(Instant.now()));
    assertEquals(List.of(row), routeRows(), "left as it is");
    assertEquals(0, budget().pending(), "and it holds no slot any more");
  }

  /** Without the switch a recompute would not stamp the track, and a pass would queue it for ever. */
  @Test
  void withTheSurfaceOff_nothingIsQueued_andTheTrackIsPickedUpOnceOn() {
    Long id = oldRoute(1);
    on(60);
    assertEquals(1, backfill.enqueue(now()));
    makeDue();
    // Switched off with a request in the queue: the worker serves it, without a surface
    surfaceService.setEnabledForTest(false);

    assertEquals(1, worker.processDue());

    assertEquals(0, refreshCount());
    assertNull(route(id).getElevationPipeline(), "no surface was asked for: not on the version");
    assertNull(document(id));
    assertEquals(0, backfill.enqueue(Instant.now()), "and it is not queued while off");
    assertEquals(0, refreshCount());

    surfaceService.setEnabledForTest(true);
    assertEquals(1, backfill.enqueue(now()));
    makeDue();
    assertEquals(1, worker.processDue());

    assertEquals(PIPELINE, route(id).getElevationPipeline());
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, document(id).version());
  }

  @Test
  void anOldRouteNeverRecomputed_keepsReadingItsV1Document() {
    RouteDto dto = createRoute("Ancien");
    Long id = TsidUtils.toLong(dto.id());
    sql("delete from elevation_refresh where route_id = ?1", id);
    sql(
        "update team_entities set elevation_state = 'HD', elevation_pipeline = 2 where id = ?1",
        id);
    withV1Document(id);
    surfaceService.setEnabledForTest(true);
    double[] before = elevationRange(id);

    var read =
        QuarkusTransaction.requiringNew().call(() -> routeService.getDto(team1Slug, dto.slug()));

    assertEquals(TrackSurfaceState.READY, read.tracks().getFirst().surfaceState());
    assertEquals(before[0], elevationRange(id)[0], 0.01);
    assertEquals(Short.valueOf((short) 2), route(id).getElevationPipeline());
    assertEquals(0, refreshCount());
  }

  // ------------------------------------------------------------------ what is left

  @Test
  void backfillRemaining_countsLeftAndGivenUp() {
    Long waiting = oldRoute(1);
    Long queued = oldRoute(2);
    Long givenUp = oldRoute(3);
    oldRoute(4, GpxPipeline.VERSION);
    Long deleted = oldRoute(5);
    createRoute("Neuf");
    oldPreview();
    Long givenUpPreview = oldPreview();
    sql("update team_entities set deleted = true where id = ?1", deleted);
    sql("update team_entities set distance = 1000 where id in (?1, ?2)", waiting, queued);
    on(60);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Instant now = Instant.now();
              refreshRepository.insertBackfillRoute(
                  new ElevationRefreshRepository.BackfillCandidate(queued, 1000, 1L), now, now);
              refreshRepository.insertBackfillRoute(
                  new ElevationRefreshRepository.BackfillCandidate(givenUp, 1000, 1L), now, now);
              refreshRepository.insertBackfillPreview(
                  new ElevationRefreshRepository.BackfillCandidate(givenUpPreview, 1000, 1L),
                  now,
                  now);
            });
    sql(
        "update elevation_refresh set attempts = ?1 where route_id = ?2 or preview_id = ?3",
        ElevationRefreshService.MAX_ATTEMPTS,
        givenUp,
        givenUpPreview);

    BackfillRemaining left =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    refreshRepository.backfillRemaining(
                        Instant.now().minus(29, ChronoUnit.DAYS),
                        ElevationRefreshService.MAX_ATTEMPTS));

    assertEquals(2, left.routes(), "the queued one still is to do, the saved one is not ours");
    assertEquals(2000, left.routeMetres(), 0.01);
    assertEquals(1, left.previews());
    assertEquals(2, left.givenUp());
  }
}
