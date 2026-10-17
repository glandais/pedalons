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
import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDetailDto;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.gpx.FakeElevationProducer;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository.Claim;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.gps.sync.GpsSyncNames;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import fr.pedalons.util.StoredObjects;
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
        .call(
            () ->
                assetRepository.list("teamEntity.id = ?1", id(route)).stream()
                    .map(
                        a ->
                            new Snap(a.getId(), a.getType(), a.getFileId(), a.getContentRevision()))
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
        .call(
            () -> {
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
        .run(
            () ->
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
    assertFlat(created, FakeElevationProducer.FAST_ELEVATION);

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
        .run(
            () -> {
              refreshRepository.delete("route.id", routeId);
              refreshRepository.requestForRoute(routeId, 1L, t0, quiet, maxWait);
            });
    assertEquals(t0.plus(quiet), refresh(created).getDueAt());

    // Close together: each save pushes the due time back from the quiet period
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                refreshRepository.requestForRoute(routeId, 2L, t0.plusSeconds(60), quiet, maxWait));
    ElevationRefresh second = refresh(created);
    assertEquals(t0.plusSeconds(150), second.getDueAt());
    assertEquals(2L, second.getSourceRevision());
    assertEquals(t0, second.getFirstRequestedAt());

    // Near the cap: the quiet period would go past first request + maxWait
    QuarkusTransaction.requiringNew()
        .run(
            () ->
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
    assertFlat(created, FakeElevationProducer.HD_ELEVATION);
    assertEquals(0, refreshCount());

    updateRoute(created, "Boucle", TWO_TRACKS);
    assertEquals(0, refreshCount());
    assertFlat(created, FakeElevationProducer.HD_ELEVATION);
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
    assertFlat(created, FakeElevationProducer.HD_ELEVATION);
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
            .call(
                () ->
                    routeRepository.findById(id(created)).getTracks().stream()
                        .map(GpxTrack::getId)
                        .sorted()
                        .toList());
    assertEquals(2, trackIds.size());
    makeDue(created);

    worker.processDue();

    List<Long> after =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    routeRepository.findById(id(created)).getTracks().stream()
                        .map(GpxTrack::getId)
                        .sorted()
                        .toList());
    assertEquals(trackIds, after);
    assertFlat(created, FakeElevationProducer.HD_ELEVATION);
    assertEquals(ElevationState.HD, storedState(created));
  }

  @Test
  void trackSavedDuringTheCompute_nothingIsWritten_andTheRequestIsRealigned() {
    RouteDto created = createRoute(EXAMPLE);
    makeDue(created);

    Claim claim = service.claimNext(Instant.now()).orElseThrow();
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
    assertFlat(created, FakeElevationProducer.FAST_ELEVATION);
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
      assertFlat(created, FakeElevationProducer.FAST_ELEVATION);
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
        .run(
            () -> {
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
    // Far from every other test's tiles: the HD provider caches what it already read
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

      FakeElevationProducer.failHd = true;
      try {
        assertEquals(1, worker.processDue());
      } finally {
        FakeElevationProducer.failHd = false;
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

  @Test
  void deletingTheRoute_removesItsRequest() {
    Route route = dataService.createRoute(team1, user1, "À supprimer", Visibility.PUBLIC);
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                refreshRepository.requestForRoute(
                    route.getId(),
                    1L,
                    Instant.now(),
                    Duration.ofSeconds(90),
                    Duration.ofMinutes(10)));
    assertEquals(1, refreshCount());

    QuarkusTransaction.requiringNew()
        .run(
            () -> {
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
}
