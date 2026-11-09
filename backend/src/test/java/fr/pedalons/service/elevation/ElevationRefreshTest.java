package fr.pedalons.service.elevation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDetailDto;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.dto.routes.response.TrackDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TrackSurfaceState;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.infrastructure.routedetails.RouteDetailsOptions;
import fr.pedalons.infrastructure.routedetails.RouteDetailsProfile;
import fr.pedalons.infrastructure.routedetails.RouteDetailsSection;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository.Claim;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.gps.sync.GpsSyncNames;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.route.planner.PlannerStateFixtures;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.surface.SurfaceRefreshService;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import fr.pedalons.util.StoredObjects;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.InputStream;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-131: a route is saved on the fast elevation source and queued, then the
 * worker swaps in the HD profile without changing any asset row — or writes nothing when the track
 * moved meanwhile. The test producer gives FAST a flat 100 m and HD a flat 200 m, so the tier that
 * computed a profile can be read from it; no test reaches IGN.
 */
@QuarkusTest
class ElevationRefreshTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();
  private static final Path TWO_TRACKS = new File("src/test/resources/two_tracks.gpx").toPath();

  @InjectMock MapThumbnailRenderer renderer;

  @Inject RouteService routeService;
  @Inject ElevationRefreshService service;
  @Inject ElevationRefreshWorker worker;
  @Inject ElevationRefreshRepository refreshRepository;
  @Inject RouteRepository routeRepository;
  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;
  @Inject StoredObjects stored;
  @Inject EntityManager entityManager;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  /** An asset row as the tests compare it before and after the catch-up. */
  private record Snap(Long id, AssetType type, long fileId, Long revision) {}

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
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
  void restoreSwitch() {
    service.setAsyncHdEnabledForTest(true);
    surfaceService.setEnabledForTest(false);
  }

  private static RouteRequest request(String name) {
    return new RouteRequest(
        name,
        MediaDto.builder().markdown("Parcours").build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null);
  }

  private RouteDto createRoute(Path gpx) {
    queryContext.setUserForTest(user1);
    return routeService.createRoute(team1Slug, request("Boucle"), gpx);
  }

  private RouteDto updateRoute(RouteDto route, String name, Path gpx) {
    queryContext.setUserForTest(user1);
    return routeService.updateRoute(team1Slug, route.slug(), request(name), gpx);
  }

  private static Long id(RouteDto route) {
    return TsidUtils.toLong(route.id());
  }

  private ElevationRefresh refresh(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> refreshRepository.findByRouteId(id(route)).orElse(null));
  }

  private long refreshCount() {
    return QuarkusTransaction.requiringNew().call(() -> refreshRepository.count());
  }

  private ElevationState storedState(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> routeRepository.findById(id(route)).getElevationState());
  }

  private List<Snap> snaps(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            assetRepository.list("teamEntity.id = ?1", id(route)).stream()
                .map(a -> new Snap(a.getId(), a.getType(), a.getFileId(), a.getContentRevision()))
                .toList());
  }

  private static Map<AssetType, Snap> byType(List<Snap> snaps) {
    return snaps.stream().collect(Collectors.toMap(Snap::type, Function.identity()));
  }

  private Set<String> keysOf(List<Snap> snaps) {
    return snaps.stream()
        .map(s -> assetService.getAssetKey(team1, s.fileId()))
        .collect(Collectors.toSet());
  }

  /** The elevation of every point of every track, min and max. */
  private double[] elevationRange(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> {
          Route r = routeRepository.findById(id(route));
          double min = Double.MAX_VALUE;
          double max = -Double.MAX_VALUE;
          for (GpxTrack track : r.getTracks()) {
            for (GpxTrack.TrackPoint p : track.getTrackPoints()) {
              min = Math.min(min, p.ele());
              max = Math.max(max, p.ele());
            }
          }
          return new double[] {min, max};
        });
  }

  private void assertFlat(RouteDto route, double expected) {
    double[] range = elevationRange(route);
    assertEquals(expected, range[0], 1.0);
    assertEquals(expected, range[1], 1.0);
  }

  private void makeDue(RouteDto route) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            refreshRepository.update(
                "dueAt = ?1 where route.id = ?2", Instant.now().minusSeconds(1), id(route)));
  }

  private byte[] read(long fileId) throws Exception {
    try (InputStream in = storageService.retrieve(assetService.getAssetKey(team1, fileId))) {
      return in.readAllBytes();
    }
  }

  // ==================== save: FAST and the request ====================

  @Test
  void create_withTrack_isFast_andQueuedOnce() {
    Instant before = Instant.now();
    RouteDto created = createRoute(EXAMPLE);

    assertEquals(ElevationState.PENDING, created.elevationState());
    assertEquals(ElevationState.PENDING, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FAST_ELEVATION);

    ElevationRefresh request = refresh(created);
    assertNotNull(request);
    assertEquals(1, refreshCount());
    Long original = byType(snaps(created)).get(AssetType.ROUTE_ORIGINAL_GPX).fileId();
    assertEquals(original, request.getSourceRevision());
    assertEquals(0, request.getAttempts());
    assertNull(request.getClaimedUntil());
    assertWithin(request.getDueAt(), before.plusSeconds(90), Duration.ofSeconds(15));
    assertEquals(
        ElevationState.PENDING,
        QuarkusTransaction.requiringNew()
            .call(() -> routeService.getDto(team1Slug, created.slug()))
            .elevationState());
  }

  @Test
  void update_withTrack_staysPending_andMovesTheRequestToTheNewOriginal() {
    RouteDto created = createRoute(EXAMPLE);
    ElevationRefresh first = refresh(created);

    updateRoute(created, "Boucle", TWO_TRACKS);

    ElevationRefresh second = refresh(created);
    assertEquals(1, refreshCount());
    assertEquals(first.getId(), second.getId(), "one row per route");
    assertEquals(
        byType(snaps(created)).get(AssetType.ROUTE_ORIGINAL_GPX).fileId(),
        second.getSourceRevision());
    assertNotEquals(first.getSourceRevision(), second.getSourceRevision());
    assertFalse(second.getDueAt().isBefore(first.getDueAt()));
    assertEquals(first.getFirstRequestedAt(), second.getFirstRequestedAt());
    assertEquals(ElevationState.PENDING, storedState(created));
  }

  @Test
  void update_withoutTrack_touchesNeitherQualityNorQueue() {
    RouteDto created = createRoute(EXAMPLE);
    ElevationRefresh before = refresh(created);

    updateRoute(created, "Nouveau titre", null);

    ElevationRefresh after = refresh(created);
    assertEquals(before.getSourceRevision(), after.getSourceRevision());
    assertEquals(before.getDueAt(), after.getDueAt());
    assertEquals(1, refreshCount());
    assertEquals(ElevationState.PENDING, storedState(created));
  }

  @Test
  void update_withoutTrack_leavesAnHdRouteHd() throws Exception {
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);
    worker.processDue();
    assertEquals(ElevationState.HD, storedState(created));

    updateRoute(created, "Nouveau titre", null);

    assertEquals(ElevationState.HD, storedState(created));
    assertEquals(0, refreshCount());
  }

  @Test
  void debounce_pushesTheDueTimeBack_butNeverBeyondMaxWait() {
    RouteDto created = createRoute(EXAMPLE);
    Long routeId = id(created);
    Instant t0 = Instant.parse("2026-10-17T10:00:00Z");
    Duration quiet = Duration.ofSeconds(90);
    Duration maxWait = Duration.ofMinutes(10);
    QuarkusTransaction.requiringNew()
        .run(() -> {
          refreshRepository.delete("route.id", routeId);
          refreshRepository.requestForRoute(routeId, 1L, t0, quiet, maxWait);
        });
    assertEquals(t0.plus(quiet), refresh(created).getDueAt());

    // Close together: each save pushes the due time back from the quiet period
    QuarkusTransaction.requiringNew()
        .run(() ->
            refreshRepository.requestForRoute(routeId, 2L, t0.plusSeconds(60), quiet, maxWait));
    ElevationRefresh second = refresh(created);
    assertEquals(t0.plusSeconds(150), second.getDueAt());
    assertEquals(2L, second.getSourceRevision());
    assertEquals(t0, second.getFirstRequestedAt());

    // Near the cap: the quiet period would go past first request + maxWait
    QuarkusTransaction.requiringNew()
        .run(() ->
            refreshRepository.requestForRoute(
                routeId, 3L, t0.plus(Duration.ofMinutes(9)), quiet, maxWait));
    assertEquals(t0.plus(maxWait), refresh(created).getDueAt());

    // Once the window is over, a save opens a new one rather than inheriting a cap in the past
    Instant later = t0.plus(Duration.ofMinutes(20));
    QuarkusTransaction.requiringNew()
        .run(() -> refreshRepository.requestForRoute(routeId, 4L, later, quiet, maxWait));
    ElevationRefresh reopened = refresh(created);
    assertEquals(later.plus(quiet), reopened.getDueAt());
    assertEquals(later, reopened.getFirstRequestedAt());
  }

  @Test
  void switchOff_computesHdAtOnce_andQueuesNothing() {
    service.setAsyncHdEnabledForTest(false);

    RouteDto created = createRoute(EXAMPLE);

    assertEquals(ElevationState.HD, created.elevationState());
    assertEquals(ElevationState.HD, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FULL_ELEVATION);
    assertEquals(0, refreshCount());

    updateRoute(created, "Boucle", TWO_TRACKS);
    assertEquals(0, refreshCount());
    assertFlat(created, FakeRouteDetailsClient.FULL_ELEVATION);
  }

  @Test
  void aRouteWithNoStoredQuality_isHd() {
    RouteDto created = createRoute(EXAMPLE);
    QuarkusTransaction.requiringNew()
        .run(() -> routeRepository.update("elevationState = null where id = ?1", id(created)));

    RouteDetailDto detail =
        QuarkusTransaction.requiringNew()
            .call(() -> routeService.getDto(team1Slug, created.slug()));
    assertEquals(ElevationState.HD, detail.elevationState());
  }

  // ==================== the worker ====================

  @Test
  void worker_ignoresARequestThatIsNotDue() {
    createRoute(EXAMPLE);

    assertEquals(0, worker.processDue());
    assertEquals(1, refreshCount());
  }

  @Test
  void worker_replacesTheProfile_andKeepsEveryAssetRow() throws Exception {
    RouteDto created = createRoute(EXAMPLE);
    List<Snap> before = snaps(created);
    Map<AssetType, Snap> beforeByType = byType(before);
    assertEquals(5, before.size());
    byte[] oldFiltered = read(beforeByType.get(AssetType.ROUTE_FILTERED_GPX).fileId());
    Set<String> bucketBefore = stored.assetKeys(team1);
    Long filteredAssetId = beforeByType.get(AssetType.ROUTE_FILTERED_GPX).id();
    Long contentKeyBefore =
        GpsSyncNames.contentKey(
            filteredAssetId, beforeByType.get(AssetType.ROUTE_FILTERED_GPX).revision());
    makeDue(created);

    assertEquals(1, worker.processDue());

    List<Snap> after = snaps(created);
    Map<AssetType, Snap> afterByType = byType(after);
    assertEquals(5, after.size());
    for (Snap old : before) {
      Snap now = afterByType.get(old.type());
      assertEquals(old.id(), now.id(), "same row: " + old.type());
      switch (old.type()) {
        case ROUTE_FILTERED_GPX, ROUTE_FIT -> {
          assertNotEquals(old.fileId(), now.fileId(), "new file: " + old.type());
          assertEquals(now.fileId(), now.revision(), "new content revision: " + old.type());
        }
        default -> {
          assertEquals(old.fileId(), now.fileId(), "untouched: " + old.type());
          assertEquals(old.revision(), now.revision(), "untouched: " + old.type());
        }
      }
    }
    // The GPS sync fingerprint moves, so the planner pushes the route again
    Snap filtered = afterByType.get(AssetType.ROUTE_FILTERED_GPX);
    assertNotEquals(contentKeyBefore, GpsSyncNames.contentKey(filtered.id(), filtered.revision()));

    assertEquals(ElevationState.HD, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FULL_ELEVATION);
    assertNull(refresh(created), "request removed");
    assertFalse(java.util.Arrays.equals(oldFiltered, read(filtered.fileId())));

    // Old filtered and FIT keys deleted after commit, nothing else moved
    Set<String> expected = new HashSet<>(bucketBefore);
    expected.removeAll(keysOf(before));
    expected.addAll(keysOf(after));
    assertEquals(expected, stored.assetKeys(team1));

    // Nothing left to do
    assertEquals(0, worker.processDue());
    RouteDetailDto detail =
        QuarkusTransaction.requiringNew()
            .call(() -> routeService.getDto(team1Slug, created.slug()));
    assertEquals(ElevationState.HD, detail.elevationState());
  }

  @Test
  void worker_updatesTheTracksInPlace_sameCountAndRows() {
    RouteDto created = createRoute(TWO_TRACKS);
    List<Long> trackIds =
        QuarkusTransaction.requiringNew()
            .call(() ->
                routeRepository.findById(id(created)).getTracks().stream()
                    .map(GpxTrack::getId)
                    .sorted()
                    .toList());
    assertEquals(2, trackIds.size());
    // The source 2D track, written by the save (docs/LEDGER_*.md API-149)
    List<TestDataService.RawGeometry> raw = dataService.rawGeometries(id(created));
    assertEquals(2, raw.size());
    assertTrue(raw.stream().allMatch(r -> r.ewkb() != null), raw.toString());
    makeDue(created);

    worker.processDue();

    List<Long> after =
        QuarkusTransaction.requiringNew()
            .call(() ->
                routeRepository.findById(id(created)).getTracks().stream()
                    .map(GpxTrack::getId)
                    .sorted()
                    .toList());
    assertEquals(trackIds, after);
    // The catch-up changes the elevations, never the raw geometry
    assertEquals(raw, dataService.rawGeometries(id(created)));
    assertFlat(created, FakeRouteDetailsClient.FULL_ELEVATION);
    assertEquals(ElevationState.HD, storedState(created));
  }

  @Test
  void worker_keepsThePlannerState_andItsRevisionStaysValid() {
    dataService.setTeamEnableRoutePlanner(team1, true);
    queryContext.setUserForTest(user1);
    PlannerState state = PlannerStateFixtures.example();
    RouteDto created =
        routeService.createRoute(
            team1Slug,
            new RouteRequest(
                "Boucle",
                MediaDto.builder().build(),
                SurfaceType.ROAD,
                Visibility.PUBLIC,
                null,
                null,
                state),
            null);
    assertEquals(
        state.pieces().size(),
        QuarkusTransaction.requiringNew()
            .call(() -> routeService.getPlannerState(team1Slug, created.slug()))
            .state()
            .pieces()
            .size());
    Long original = byType(snaps(created)).get(AssetType.ROUTE_ORIGINAL_GPX).fileId();
    makeDue(created);

    worker.processDue();

    assertEquals(ElevationState.HD, storedState(created));
    assertEquals(
        original,
        byType(snaps(created)).get(AssetType.ROUTE_ORIGINAL_GPX).fileId(),
        "the original is not rewritten");
    assertNotNull(
        QuarkusTransaction.requiringNew()
            .call(() -> routeService.getPlannerState(team1Slug, created.slug()))
            .state(),
        "still readable");
  }

  @Test
  void aPlannerState_isNotReadableAcrossDomains() {
    dataService.setTeamEnableRoutePlanner(team1, true);
    queryContext.setUserForTest(user1);
    RouteDto created =
        routeService.createRoute(
            team1Slug,
            new RouteRequest(
                "Boucle",
                MediaDto.builder().build(),
                SurfaceType.ROAD,
                Visibility.PUBLIC,
                null,
                null,
                PlannerStateFixtures.example()),
            null);
    fr.pedalons.domain.platform.Domain other =
        dataService.createDomain("other.example.org", "Other", "https://other.example.org");
    domainResolver.setDomainForTest(other);

    org.junit.jupiter.api.Assertions.assertThrows(
        fr.pedalons.infrastructure.exception.NotFoundException.class,
        () -> routeService.getPlannerState(team1Slug, created.slug()));
  }

  @Test
  void trackSavedDuringTheCompute_nothingIsWritten_andTheRequestIsRealigned() {
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);

    Claim claim = service.claimNext(Instant.now(), false).orElseThrow();
    ElevationRefreshService.Recomputed recomputed;
    try {
      recomputed = service.compute(claim);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
    Set<String> bucketWithUploads = stored.assetKeys(team1);

    // The user saves a new track while the HD profile was being computed
    updateRoute(created, "Boucle", TWO_TRACKS);
    List<Snap> afterSave = snaps(created);
    Long newOriginal = byType(afterSave).get(AssetType.ROUTE_ORIGINAL_GPX).fileId();

    ElevationRefreshService.Outcome outcome = service.write(claim, recomputed);

    assertEquals(ElevationRefreshService.Outcome.REALIGNED, outcome);
    assertEquals(afterSave, snaps(created), "no asset touched");
    assertEquals(ElevationState.PENDING, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FAST_ELEVATION);
    ElevationRefresh request = refresh(created);
    assertNotNull(request, "the request is kept, not deleted");
    assertEquals(newOriginal, request.getSourceRevision());
    assertNull(request.getClaimedUntil());
    assertEquals(0, request.getAttempts());
    assertTrue(request.getDueAt().isAfter(Instant.now().plusSeconds(60)), "a fresh quiet period");
    // The HD files uploaded for the abandoned track are gone: the bucket holds the current assets
    assertEquals(keysOf(afterSave), stored.assetKeys(team1));
    assertEquals(
        2,
        QuarkusTransaction.requiringNew()
            .call(() -> routeRepository.findById(id(created)).getTracks().size()));
    assertFalse(bucketWithUploads.isEmpty());
  }

  @Test
  void aFailure_countsAnAttempt_backsOff_andLeavesTheRouteFast() {
    RouteDto created = createRoute(EXAMPLE);
    long original = byType(snaps(created)).get(AssetType.ROUTE_ORIGINAL_GPX).fileId();
    // The original cannot be read any more: the attempt fails whatever the provider does
    storageService.delete(assetService.getAssetKey(team1, original));

    Duration[] expected = {
      Duration.ofMinutes(2), Duration.ofMinutes(10), Duration.ofHours(1), Duration.ofHours(6)
    };
    for (int attempt = 1; attempt <= 4; attempt++) {
      makeDue(created);
      Instant before = Instant.now();
      assertEquals(1, worker.processDue());

      ElevationRefresh request = refresh(created);
      assertEquals(attempt, request.getAttempts());
      assertNotNull(request.getLastError());
      assertNull(request.getClaimedUntil(), "lease released");
      assertWithin(request.getDueAt(), before.plus(expected[attempt - 1]), Duration.ofSeconds(30));
      assertEquals(ElevationState.PENDING, storedState(created));
      assertFlat(created, FakeRouteDetailsClient.FAST_ELEVATION);
      // Not due again before the backoff
      assertEquals(0, worker.processDue());
    }

    // The fifth attempt is the last: the row stays for diagnosis and is never taken again
    makeDue(created);
    assertEquals(1, worker.processDue());
    assertEquals(5, refresh(created).getAttempts());
    makeDue(created);
    assertEquals(0, worker.processDue());
    assertNotNull(refresh(created));
    assertEquals(ElevationState.FAST, storedState(created), "given up: the fast profile is kept");
    assertEquals(
        ElevationState.FAST,
        QuarkusTransaction.requiringNew()
            .call(() -> routeService.getDto(team1Slug, created.slug()))
            .elevationState(),
        "the DTO says so");
  }

  @Test
  void aSaveOfAnAbandonedRoute_isPendingAgain_withARestartedRequest() {
    RouteDto created = createRoute(EXAMPLE);
    long original = byType(snaps(created)).get(AssetType.ROUTE_ORIGINAL_GPX).fileId();
    storageService.delete(assetService.getAssetKey(team1, original));
    for (int attempt = 1; attempt <= ElevationRefreshService.MAX_ATTEMPTS; attempt++) {
      makeDue(created);
      assertEquals(1, worker.processDue());
    }
    assertEquals(ElevationState.FAST, storedState(created));

    updateRoute(created, "Boucle", TWO_TRACKS);

    assertEquals(ElevationState.PENDING, storedState(created));
    assertEquals(0, refresh(created).getAttempts());
    makeDue(created);
    assertEquals(1, worker.processDue());
    assertEquals(ElevationState.HD, storedState(created));
  }

  @Test
  void aSaveRestartsTheAttempts_ofAFailedRequest() {
    RouteDto created = createRoute(EXAMPLE);
    long original = byType(snaps(created)).get(AssetType.ROUTE_ORIGINAL_GPX).fileId();
    storageService.delete(assetService.getAssetKey(team1, original));
    makeDue(created);
    worker.processDue();
    assertEquals(1, refresh(created).getAttempts());

    updateRoute(created, "Boucle", TWO_TRACKS);

    ElevationRefresh request = refresh(created);
    assertEquals(0, request.getAttempts());
    assertNull(request.getLastError());
    makeDue(created);
    assertEquals(1, worker.processDue());
    assertEquals(ElevationState.HD, storedState(created));
  }

  @Test
  void aTrackReplacedByAnHdSave_dropsTheRequest_insteadOfRecomputingHdFromHd() {
    RouteDto created = createRoute(EXAMPLE);
    // A save with the switch off: replaces the track in HD, queues nothing
    service.setAsyncHdEnabledForTest(false);
    updateRoute(created, "Boucle", TWO_TRACKS);
    service.setAsyncHdEnabledForTest(true);
    long newOriginal = byType(snaps(created)).get(AssetType.ROUTE_ORIGINAL_GPX).fileId();
    assertNotEquals(newOriginal, refresh(created).getSourceRevision());
    makeDue(created);

    assertEquals(1, worker.processDue());

    assertNull(refresh(created), "nothing left to catch up on");
  }

  @Test
  void aNewRequest_afterAFailureOrAFinishedWindow_startsANewWindow() {
    RouteDto created = createRoute(EXAMPLE);
    Long routeId = id(created);
    Instant t0 = Instant.parse("2026-10-17T10:00:00Z");
    Duration quiet = Duration.ofSeconds(90);
    Duration maxWait = Duration.ofMinutes(10);
    QuarkusTransaction.requiringNew()
        .run(() -> {
          refreshRepository.delete("route.id", routeId);
          refreshRepository.requestForRoute(routeId, 1L, t0, quiet, maxWait);
          refreshRepository.update("attempts = 5 where route.id = ?1", routeId);
        });

    // Given up long ago: the next save is a first one
    Instant later = t0.plus(Duration.ofDays(2));
    QuarkusTransaction.requiringNew()
        .run(() -> refreshRepository.requestForRoute(routeId, 2L, later, quiet, maxWait));
    ElevationRefresh request = refresh(created);
    assertEquals(later, request.getFirstRequestedAt());
    assertEquals(later.plus(quiet), request.getDueAt());
    assertEquals(0, request.getAttempts());

    // Same for a window older than maxWait, with no failure
    Instant muchLater = later.plus(Duration.ofMinutes(30));
    QuarkusTransaction.requiringNew()
        .run(() -> refreshRepository.requestForRoute(routeId, 3L, muchLater, quiet, maxWait));
    request = refresh(created);
    assertEquals(muchLater, request.getFirstRequestedAt());
    assertEquals(muchLater.plus(quiet), request.getDueAt());
  }

  @Test
  void aDeletedRoute_isNotRecomputed() {
    RouteDto created = createRoute(EXAMPLE);
    QuarkusTransaction.requiringNew()
        .run(() -> routeRepository.update("deleted = true where id = ?1", id(created)));
    makeDue(created);

    assertEquals(0, worker.processDue());
    assertEquals(ElevationState.PENDING, storedState(created));
  }

  @Test
  void aPartialHdResult_countsAsAFailure_andWritesNothing() throws Exception {
    Path southern = java.nio.file.Files.createTempFile("southern-", ".gpx");
    try {
      java.nio.file.Files.writeString(
          southern,
          """
          <?xml version="1.0" encoding="UTF-8"?>
          <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
            <trk><name>Sud</name><trkseg>
              <trkpt lat="-33.8000" lon="151.2000"><ele>10</ele></trkpt>
              <trkpt lat="-33.8100" lon="151.2100"><ele>12</ele></trkpt>
              <trkpt lat="-33.8200" lon="151.2200"><ele>14</ele></trkpt>
            </trkseg></trk>
          </gpx>
          """);
      RouteDto created = createRoute(southern);
      Set<String> bucketBefore = stored.assetKeys(team1);
      List<Snap> before = snaps(created);
      makeDue(created);

      FakeRouteDetailsClient.failFull = true;
      try {
        assertEquals(1, worker.processDue());
      } finally {
        FakeRouteDetailsClient.failFull = false;
      }

      ElevationRefresh request = refresh(created);
      assertEquals(1, request.getAttempts());
      assertNotNull(request.getLastError());
      assertEquals(ElevationState.PENDING, storedState(created));
      assertEquals(before, snaps(created));
      assertEquals(bucketBefore, stored.assetKeys(team1), "no HD file kept");
    } finally {
      java.nio.file.Files.deleteIfExists(southern);
    }
  }

  /** A 200 whose terrain fell back after an IGN error is no HD result: asked again, not kept. */
  @Test
  void aTerrainFallback_countsAsAFailure_andWritesNothing() {
    RouteDto created = createRoute(EXAMPLE);
    Set<String> bucketBefore = stored.assetKeys(team1);
    List<Snap> before = snaps(created);
    makeDue(created);

    FakeRouteDetailsClient.fallbackAfterError = true;
    try {
      assertEquals(1, worker.processDue());
    } finally {
      FakeRouteDetailsClient.fallbackAfterError = false;
    }

    ElevationRefresh request = refresh(created);
    assertEquals(1, request.getAttempts());
    assertNotNull(request.getLastError());
    assertEquals(ElevationState.PENDING, storedState(created));
    assertEquals(before, snaps(created));
    assertEquals(bucketBefore, stored.assetKeys(team1), "no HD file kept");
  }

  /** {@code elevation_missing} is out of coverage, permanent: retrying could never end better. */
  @Test
  void aRangeOutOfCoverage_isNoFailure_andTheHdProfileIsWritten() {
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);

    FakeRouteDetailsClient.partial = true;
    try {
      assertEquals(1, worker.processDue());
    } finally {
      FakeRouteDetailsClient.partial = false;
    }

    assertEquals(ElevationState.HD, storedState(created));
    assertEquals(0, refreshCount());
    assertFlat(created, FakeRouteDetailsClient.FULL_ELEVATION);
  }

  @Test
  void deletingTheRoute_removesItsRequest() {
    Route route = dataService.createRoute(team1, user1, "À supprimer", Visibility.PUBLIC);
    QuarkusTransaction.requiringNew()
        .run(() ->
            refreshRepository.requestForRoute(
                route.getId(), 1L, Instant.now(), Duration.ofSeconds(90), Duration.ofMinutes(10)));
    assertEquals(1, refreshCount());

    QuarkusTransaction.requiringNew()
        .run(() -> {
          // What the foreign keys of the route's other children would refuse
          entityManager
              .createNativeQuery("delete from gpx_tracks where route_id = :id")
              .setParameter("id", route.getId())
              .executeUpdate();
          entityManager
              .createNativeQuery("delete from team_entities where id = :id")
              .setParameter("id", route.getId())
              .executeUpdate();
        });

    assertEquals(0, refreshCount());
  }

  private static void assertWithin(Instant actual, Instant expected, Duration tolerance) {
    long drift = Math.abs(Duration.between(expected, actual).toMillis());
    assertTrue(
        drift <= tolerance.toMillis(),
        "expected " + expected + " ± " + tolerance + ", got " + actual);
  }

  // ==================== waypoints (docs/LEDGER_*.md WEB-100, C3c) ====================

  private static final Path WAYPOINTS = new File("src/test/resources/waypoints.gpx").toPath();

  private record WaypointSnap(
      Long id, String name, fr.pedalons.enums.WaypointType type, Double distance) {}

  private List<WaypointSnap> waypointSnaps(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            entityManager
                .createQuery(
                    "select w from fr.pedalons.domain.route.GpxWaypoint w where w.route.id ="
                        + " :id order by w.id",
                    fr.pedalons.domain.route.GpxWaypoint.class)
                .setParameter("id", id(route))
                .getResultList()
                .stream()
                .map(
                    w -> new WaypointSnap(w.getId(), w.getName(), w.typeOrInfo(), w.getDistanceM()))
                .toList());
  }

  @Test
  void hdCatchUp_keepsWaypoints_updatesTheirDistances() throws Exception {
    RouteDto created = createRoute(WAYPOINTS);
    List<WaypointSnap> before = waypointSnaps(created);
    assertEquals(3, before.size());
    makeDue(created);

    assertEquals(1, worker.processDue());

    assertEquals(ElevationState.HD, storedState(created));
    List<WaypointSnap> after = waypointSnaps(created);
    assertEquals(
        before.stream().map(WaypointSnap::id).toList(),
        after.stream().map(WaypointSnap::id).toList(),
        "the rows are updated in place");
    assertEquals(
        before.stream().map(WaypointSnap::type).toList(),
        after.stream().map(WaypointSnap::type).toList(),
        "and keep their type, which the original GPX does not carry");
    assertTrue(after.stream().allMatch(w -> w.distance() != null));
    String filtered =
        new String(
            read(byType(snaps(created)).get(AssetType.ROUTE_FILTERED_GPX).fileId()),
            java.nio.charset.StandardCharsets.UTF_8);
    assertTrue(filtered.contains("Drinking Water"), "the HD filtered GPX is typed");
  }

  @Test
  void hdCatchUp_waypointsEditedDuringCompute_realigns_andWritesNothing() {
    RouteDto created = createRoute(WAYPOINTS);
    makeDue(created);
    Claim claim = service.claimNext(Instant.now(), false).orElseThrow();
    ElevationRefreshService.Recomputed recomputed;
    try {
      recomputed = service.compute(claim);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }

    // The author edits the waypoints (the track stays) while the HD profile was being computed
    queryContext.setUserForTest(user1);
    routeService.updateRoute(
        team1Slug,
        created.slug(),
        new RouteRequest(
            "Boucle",
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null,
            null,
            null,
            List.of(
                new fr.pedalons.dto.routes.request.WaypointRequest(
                    null,
                    new fr.pedalons.common.GeoPoint(-1.5456685, 47.2024271),
                    fr.pedalons.enums.WaypointType.CAFE,
                    "Nouveau",
                    null,
                    null,
                    null))),
        null);
    List<Snap> afterEdit = snaps(created);

    ElevationRefreshService.Outcome outcome = service.write(claim, recomputed);

    assertEquals(ElevationRefreshService.Outcome.REALIGNED, outcome);
    assertEquals(afterEdit, snaps(created), "no asset touched");
    assertEquals(ElevationState.PENDING, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FAST_ELEVATION);
    assertEquals(1, waypointSnaps(created).size());
    assertNotNull(refresh(created), "the request is kept, due at once");
    assertEquals(keysOf(afterEdit), stored.assetKeys(team1), "the HD files are gone");
  }

  // ==================== the surface, from the same answer (docs/LEDGER_*.md API-150)
  // ====================

  private static final Short PIPELINE = (short) GpxPipeline.VERSION;

  @Inject SurfaceRefreshService surfaceService;
  @Inject GpxTrackRepository trackRepository;

  /** The stored document of each track, in the order of the tracks; null for one without. */
  private List<TrackSurfaceDocument> documents(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> {
          Map<Long, TrackSurfaceDocument> found = trackRepository.findSurfaces(id(route));
          return trackRepository.findPoints(id(route)).stream()
              .map(t -> found.get(t.trackId()))
              .toList();
        });
  }

  private TrackSurfaceDocument document(RouteDto route) {
    return documents(route).getFirst();
  }

  private void assertNoDocument(RouteDto route) {
    assertTrue(documents(route).stream().allMatch(java.util.Objects::isNull));
  }

  /** The stored length of each track. */
  private List<Double> lengths(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            trackRepository.findPoints(id(route)).stream()
                .map(t -> t.points().getLast().dist())
                .toList());
  }

  private Short pipeline(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> routeRepository.findById(id(route)).getElevationPipeline());
  }

  private TrackDto track(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> routeService.getDto(team1Slug, route.slug()))
        .tracks()
        .getFirst();
  }

  private static List<RouteDetailsOptions> fullCalls() {
    return FakeRouteDetailsClient.REQUESTS.stream()
        .map(fr.pedalons.infrastructure.routedetails.RouteDetailsRequest::options)
        .filter(o -> o.effectiveProfile() == RouteDetailsProfile.FULL)
        .toList();
  }

  private static final List<RouteDetailsSection> ALL_SECTIONS =
      List.of(
          RouteDetailsSection.ELEVATION, RouteDetailsSection.TYPOLOGY, RouteDetailsSection.SUMMARY);

  private static final List<RouteDetailsSection> NO_TYPOLOGY =
      List.of(RouteDetailsSection.ELEVATION, RouteDetailsSection.SUMMARY);

  /** Four stretches of a quarter each: asphalt, setts, fine gravel, an unpaved path. */
  private static void fourSurfaces() {
    FakeRouteDetailsClient.segmentsOf =
        length ->
            List.of(
                FakeRouteDetailsClient.segment(0, length / 4, "paved", "asphalt", "minor_road"),
                FakeRouteDetailsClient.segment(length / 4, length / 2, "paved", "sett", "street"),
                FakeRouteDetailsClient.segment(
                    length / 2, length * 3 / 4, "unpaved", "fine_gravel", "track"),
                FakeRouteDetailsClient.segment(length * 3 / 4, length, "unpaved", null, "path"));
  }

  @Test
  void onePass_writesProfileSurfaceAndPipeline_fromOneFullCall() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    assertNoDocument(created);
    assertNull(pipeline(created), "a fast save says nothing of the pipeline");
    assertTrue(fullCalls().isEmpty(), "a save asks for fast only");
    makeDue(created);

    assertEquals(1, worker.processDue());

    assertEquals(1, fullCalls().size());
    assertEquals(ALL_SECTIONS, fullCalls().getFirst().sections());
    assertEquals(ElevationState.HD, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FULL_ELEVATION);
    assertEquals(PIPELINE, pipeline(created));
    assertNull(refresh(created));

    TrackSurfaceDocument doc = document(created);
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, doc.version());
    assertTrue(doc.ok());
    assertEquals("bicycle", doc.costing());
    assertEquals(lengths(created).getFirst(), doc.distance(), 1e-6);
    assertEquals(FakeRouteDetailsClient.DATA_VERSIONS, doc.dataVersions());
    assertEquals(1, doc.surfaces().size());
    assertEquals("paved", doc.surfaces().getFirst().code());
    assertEquals(doc.distance(), doc.surfaces().getFirst().to(), 0.06);
    TrackSurfaceDocument.WayRange way = doc.ways().getFirst();
    assertEquals("minor_road", way.use());
    assertEquals("ground", way.structure());
    assertEquals(Boolean.TRUE, way.matched());
    assertEquals("paved", way.surfaceClass());
    assertEquals("asphalt", way.detail());

    TrackDto track = track(created);
    assertEquals(TrackSurfaceState.READY, track.surfaceState());
    assertEquals("PAVED", track.surfaces().getFirst().surface().name());
  }

  @Test
  void severalSurfaces_areProjected_onTheStoredAxis_andTheirRawValuesKept() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    fourSurfaces();
    makeDue(created);

    assertEquals(1, worker.processDue());

    TrackSurfaceDocument doc = document(created);
    double length = lengths(created).getFirst();
    assertEquals(
        List.of("paved", "paved_rough", "gravel", "path"),
        doc.surfaces().stream().map(TrackSurfaceDocument.SurfaceRange::code).toList());
    assertEquals(0, doc.surfaces().getFirst().from());
    assertEquals(length, doc.surfaces().getLast().to(), 0.06);
    for (int i = 1; i < 4; i++) {
      assertEquals(doc.surfaces().get(i - 1).to(), doc.surfaces().get(i).from(), "contiguous");
      assertEquals(length * i / 4, doc.surfaces().get(i).from(), length * 0.02, "boundary " + i);
    }
    assertEquals(
        java.util.Arrays.asList("asphalt", "sett", "fine_gravel", null),
        doc.ways().stream().map(TrackSurfaceDocument.WayRange::detail).toList());
    assertEquals(
        List.of("minor_road", "street", "track", "path"),
        doc.ways().stream().map(TrackSurfaceDocument.WayRange::use).toList());
    assertEquals(
        List.of("PAVED", "PAVED_ROUGH", "GRAVEL", "PATH"),
        track(created).surfaces().stream().map(r -> r.surface().name()).toList());
  }

  @Test
  void nothingKnownOfTheWholeTrack_isUnavailable_andTheProfileIsWritten() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    FakeRouteDetailsClient.segmentsOf =
        length -> List.of(FakeRouteDetailsClient.segment(0, length, "unknown", null, null));
    makeDue(created);

    assertEquals(1, worker.processDue());

    TrackSurfaceDocument doc = document(created);
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, doc.version());
    assertFalse(doc.ok());
    assertEquals(ElevationState.HD, storedState(created));
    assertEquals(PIPELINE, pipeline(created));
    assertEquals(TrackSurfaceState.UNAVAILABLE, track(created).surfaceState());
  }

  /** The surface is good, only the elevation needs the retry: plan §4.3. */
  @Test
  void aTerrainFallback_keepsTheFastProfile_writesTheSurfaceAlone_andTheRetryTheRest() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    Set<String> bucketBefore = stored.assetKeys(team1);
    List<Snap> before = snaps(created);
    makeDue(created);

    FakeRouteDetailsClient.fallbackAfterError = true;
    assertEquals(1, worker.processDue());
    FakeRouteDetailsClient.fallbackAfterError = false;

    ElevationRefresh request = refresh(created);
    assertEquals(1, request.getAttempts());
    assertNotNull(request.getLastError());
    assertEquals(ElevationState.PENDING, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FAST_ELEVATION);
    assertEquals(before, snaps(created));
    assertEquals(bucketBefore, stored.assetKeys(team1), "no HD file kept");
    assertNull(pipeline(created), "the profile is not what the version describes");

    TrackSurfaceDocument first = document(created);
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, first.version());
    assertTrue(first.ok());
    TrackDto track = track(created);
    assertEquals(TrackSurfaceState.READY, track.surfaceState());
    // The ranges are on the HD axis: they rescale on reading onto the fast track
    assertEquals(lengths(created).getFirst(), track.surfaces().getLast().to(), 0.2);

    makeDue(created);
    assertEquals(1, worker.processDue());

    assertEquals(ElevationState.HD, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FULL_ELEVATION);
    assertEquals(PIPELINE, pipeline(created));
    assertNull(refresh(created));
    assertTrue(document(created).ok());
  }

  @Test
  void aFallbackGivenUp_keepsTheFastProfile_andItsSurface() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    FakeRouteDetailsClient.fallbackAfterError = true;
    for (int attempt = 1; attempt <= ElevationRefreshService.MAX_ATTEMPTS; attempt++) {
      makeDue(created);
      assertEquals(1, worker.processDue());
    }

    assertEquals(ElevationState.FAST, storedState(created));
    assertNull(pipeline(created));
    assertEquals(TrackSurfaceState.READY, track(created).surfaceState());
  }

  /** A partial answer may be missing the typology too: nothing to keep, the retry settles it. */
  @Test
  void aTerrainFallbackOnAPartialAnswer_writesNothing() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);

    FakeRouteDetailsClient.fallbackAfterError = true;
    FakeRouteDetailsClient.partial = true;
    assertEquals(1, worker.processDue());

    assertEquals(1, refresh(created).getAttempts());
    assertEquals(ElevationState.PENDING, storedState(created));
    assertNoDocument(created);
    assertNull(pipeline(created));
  }

  /** {@code elevation_missing} is permanent: the profile is interpolated, all of it is written. */
  @Test
  void aRangeOutOfCoverage_writesProfileSurfaceAndPipeline() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);

    FakeRouteDetailsClient.partial = true;
    assertEquals(1, worker.processDue());

    assertEquals(ElevationState.HD, storedState(created));
    assertEquals(PIPELINE, pipeline(created));
    assertTrue(document(created).ok());
    assertNull(refresh(created));
  }

  @Test
  void aFullCallThatFails_writesNothing() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);

    FakeRouteDetailsClient.failFull = true;
    assertEquals(1, worker.processDue());

    assertEquals(1, refresh(created).getAttempts());
    assertEquals(ElevationState.PENDING, storedState(created));
    assertFlat(created, FakeRouteDetailsClient.FAST_ELEVATION);
    assertNoDocument(created);
    assertNull(pipeline(created));
    assertEquals(TrackSurfaceState.PENDING, track(created).surfaceState());
  }

  @Test
  void withTheSurfaceOff_theCatchUpLeavesItOut() {
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);

    assertEquals(1, worker.processDue());

    assertEquals(NO_TYPOLOGY, fullCalls().getFirst().sections());
    assertEquals(ElevationState.HD, storedState(created));
    assertNoDocument(created);
    assertNull(pipeline(created), "stays behind: recomputed once the surface is back on");
    assertNull(track(created).surfaceState());
  }

  /** A request carrying a track drawn with a straight end. */
  private static RouteRequest drawnRequest() {
    PlannerState state =
        new PlannerState(
            1,
            RouterProfile.BIKE,
            List.of(),
            List.of(
                PlannerStateFixtures.control(4.8300, 45.7600),
                PlannerStateFixtures.control(4.8340, 45.7620),
                PlannerStateFixtures.control(4.8400, 45.7650)),
            List.of(
                PlannerStateFixtures.routed(new double[][] {{4.8320, 45.7610}}),
                PlannerStateFixtures.direct()));
    return new RouteRequest(
        "Tracé",
        MediaDto.builder().build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null,
        null,
        state);
  }

  private RouteDto createDrawnRoute() {
    dataService.setTeamEnableRoutePlanner(team1, true);
    queryContext.setUserForTest(user1);
    return routeService.createRoute(team1Slug, drawnRequest(), null);
  }

  private static List<String> codes(TrackSurfaceDocument document) {
    return document.surfaces().stream().map(TrackSurfaceDocument.SurfaceRange::code).toList();
  }

  @Test
  void aStraightPiece_isLaidOverTheAnswer() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createDrawnRoute();
    makeDue(created);

    assertEquals(1, worker.processDue());

    TrackSurfaceDocument doc = document(created);
    assertEquals(List.of("paved", "off_network"), codes(doc));
    TrackSurfaceDocument.SurfaceRange off = doc.surfaces().getLast();
    assertEquals(doc.distance(), off.to(), 1.0);
    // The joint is at about 40 % of the line
    double ratio = off.from() / doc.distance();
    assertTrue(ratio > 0.25 && ratio < 0.6, "ratio " + ratio);
    assertEquals("off_network", doc.ways().getLast().use());
    assertEquals("OFF_NETWORK", track(created).surfaces().getLast().surface().name());
  }

  @Test
  void twoTracks_getADocumentEach_onTheirOwnLength() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(TWO_TRACKS);
    makeDue(created);

    assertEquals(1, worker.processDue());

    List<TrackSurfaceDocument> docs = documents(created);
    List<Double> lengths = lengths(created);
    assertEquals(2, docs.size());
    assertTrue(lengths.get(0) > lengths.get(1) * 2, "their ranges would not fit each other");
    for (int i = 0; i < 2; i++) {
      assertTrue(docs.get(i).ok());
      assertEquals(lengths.get(i), docs.get(i).distance(), 1e-6, "track " + i);
      assertEquals(lengths.get(i), docs.get(i).surfaces().getLast().to(), 0.06, "track " + i);
    }
    assertEquals(PIPELINE, pipeline(created));
  }

  @Test
  void aSaveWithAsyncOff_writesTheSurfaceFromItsOwnAnswer_andQueuesNothing() {
    surfaceService.setEnabledForTest(true);
    service.setAsyncHdEnabledForTest(false);

    RouteDto created = createRoute(EXAMPLE);

    assertEquals(1, fullCalls().size());
    assertEquals(ALL_SECTIONS, fullCalls().getFirst().sections());
    assertEquals(ElevationState.HD, storedState(created));
    assertEquals(PIPELINE, pipeline(created));
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, document(created).version());
    assertEquals(lengths(created).getFirst(), document(created).distance(), 1e-6);
    assertEquals(0, refreshCount());
    assertEquals(TrackSurfaceState.READY, track(created).surfaceState());

    updateRoute(created, "Boucle", TWO_TRACKS);

    List<TrackSurfaceDocument> docs = documents(created);
    assertEquals(2, docs.size());
    assertTrue(docs.stream().allMatch(TrackSurfaceDocument::ok));
    assertEquals(lengths(created).get(1), docs.get(1).distance(), 1e-6);
    assertEquals(PIPELINE, pipeline(created));
    assertEquals(0, refreshCount());
  }

  @Test
  void aSaveWithAsyncOffThatFallsBack_clearsThePipeline() {
    surfaceService.setEnabledForTest(true);
    service.setAsyncHdEnabledForTest(false);
    RouteDto created = createRoute(EXAMPLE);
    assertEquals(PIPELINE, pipeline(created));

    FakeRouteDetailsClient.fallbackAfterError = true;
    updateRoute(created, "Boucle", EXAMPLE);

    assertNull(pipeline(created), "its profile is to recompute");
    assertTrue(document(created).ok(), "the surface of the answer is good");
    FakeRouteDetailsClient.fallbackAfterError = false;

    updateRoute(created, "Boucle", EXAMPLE);
    assertEquals(PIPELINE, pipeline(created));

    FakeRouteDetailsClient.failFull = true;
    updateRoute(created, "Boucle", TWO_TRACKS);

    assertNull(pipeline(created));
    assertNoDocument(created);
    assertEquals(0, refreshCount());
  }

  @Test
  void aSaveWithAsyncOff_ofADrawnTrack_laysItsStraightPiecesOver() {
    surfaceService.setEnabledForTest(true);
    service.setAsyncHdEnabledForTest(false);

    RouteDto created = createDrawnRoute();

    assertEquals(List.of("paved", "off_network"), codes(document(created)));
  }

  @Test
  void anUpdateWithAsyncOff_ofADrawnTrack_laysItsStraightPiecesOver() {
    surfaceService.setEnabledForTest(true);
    service.setAsyncHdEnabledForTest(false);
    dataService.setTeamEnableRoutePlanner(team1, true);
    queryContext.setUserForTest(user1);
    RouteDto created = createRoute(EXAMPLE);
    assertEquals(List.of("paved"), codes(document(created)));

    routeService.updateRoute(team1Slug, created.slug(), drawnRequest(), null);

    assertEquals(List.of("paved", "off_network"), codes(document(created)));
  }

  @Test
  void aFastSave_clearsThePipeline_andLeavesTheSurfaceToTheCatchUp() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);
    assertEquals(1, worker.processDue());
    assertEquals(PIPELINE, pipeline(created));

    updateRoute(created, "Boucle", TWO_TRACKS);

    assertNull(pipeline(created), "this profile is no pipeline's HD one");
    assertEquals(ElevationState.PENDING, storedState(created));
    assertNoDocument(created);
    assertEquals(TrackSurfaceState.PENDING, track(created).surfaceState());

    makeDue(created);
    assertEquals(1, worker.processDue());
    assertEquals(PIPELINE, pipeline(created));
  }

  @Test
  void aNewTrackWhoseCatchUpGivesUp_staysToRecompute() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);
    assertEquals(1, worker.processDue());
    assertEquals(PIPELINE, pipeline(created));

    updateRoute(created, "Boucle", TWO_TRACKS);
    FakeRouteDetailsClient.failFull = true;
    for (int attempt = 1; attempt <= ElevationRefreshService.MAX_ATTEMPTS; attempt++) {
      makeDue(created);
      assertEquals(1, worker.processDue());
    }

    assertEquals(ElevationState.FAST, storedState(created));
    assertNull(pipeline(created));
  }

  @Test
  void aTrackSavedDuringTheCompute_getsNeitherTheSurfaceNorThePipeline() throws Exception {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);
    Claim claim = service.claimNext(Instant.now(), false).orElseThrow();
    ElevationRefreshService.Recomputed recomputed = service.compute(claim);

    updateRoute(created, "Boucle", TWO_TRACKS);

    assertEquals(ElevationRefreshService.Outcome.REALIGNED, service.write(claim, recomputed));
    assertNoDocument(created);
    assertNull(pipeline(created));
  }

  private TrackSurfaceDocument aDocument() {
    return TrackSurfaceDocument.unavailable(
        TrackSurfaceDocument.VERSION_ROUTE_DETAILS, "no-typology", 1000, "bicycle", Instant.now());
  }

  @Test
  void aSurfaceAlone_isNotWritten_onATrackSavedMeanwhile() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);
    Claim claim = service.claimNext(Instant.now(), false).orElseThrow();

    updateRoute(created, "Boucle", EXAMPLE);
    service.writeSurfaceOnly(claim, List.of(aDocument()));

    assertNoDocument(created);
  }

  @Test
  void aSurfaceAlone_isNotWritten_onAnotherNumberOfTracks() {
    surfaceService.setEnabledForTest(true);
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);
    Claim claim = service.claimNext(Instant.now(), false).orElseThrow();

    service.writeSurfaceOnly(claim, List.of(aDocument(), aDocument()));

    assertNoDocument(created);
  }
}
