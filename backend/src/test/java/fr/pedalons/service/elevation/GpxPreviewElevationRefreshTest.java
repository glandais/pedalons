package fr.pedalons.service.elevation;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.gpx.response.GpxPreviewDto;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.infrastructure.gpx.FakeElevationProducer;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository.PreviewClaim;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.planner.PlannerStateFixtures;
import fr.pedalons.service.route.planner.PlannerStates;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.StoredObjects;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.github.glandais.engine.gpx.GpxDocument;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-131, plan §4.6: a GPX-tool preview is saved on the fast elevation source and
 * queued, under a track-files revision of its own; the worker writes the HD profile under a new
 * revision and switches to it, or writes nothing when the preview moved meanwhile. The test
 * producer gives FAST a flat 100 m and HD a flat 200 m; no test reaches IGN.
 */
@QuarkusTest
class GpxPreviewElevationRefreshTest extends fr.pedalons.AbstractBaseTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();
  private static final Path TWO_TRACKS = new File("src/test/resources/two_tracks.gpx").toPath();
  private static final String THUMBNAIL = "thumbnail-light.png";

  @Inject GpxPreviewService previewService;
  @Inject GpxPreviewRepository previewRepository;
  @Inject ElevationRefreshService service;
  @Inject ElevationRefreshWorker worker;
  @Inject ElevationRefreshRepository refreshRepository;
  @Inject StorageService storageService;
  @Inject StoredObjects stored;
  @Inject PedalonsQueryContext context;
  @Inject DomainResolver domainResolver;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;

  private Domain domain;
  private User user;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createUser("owner@example.com", "Owner");
    context.setUserForTest(user);
    service.setAsyncHdEnabledForTest(true);
  }

  @AfterEach
  void restoreSwitch() {
    service.setAsyncHdEnabledForTest(true);
    FakeElevationProducer.failHd = false;
  }

  // ------------------------------------------------------------------ helpers

  private GpxPreview reload(GpxPreview preview) {
    return QuarkusTransaction.requiringNew()
        .call(() -> previewRepository.findById(preview.getId()));
  }

  /** The raw lines as readers see them, read in a transaction: the column is lazy. */
  private List<String> readableRawLines(GpxPreview preview) {
    return QuarkusTransaction.requiringNew()
        .call(() -> previewRepository.findById(preview.getId()).readableRawLines());
  }

  private ElevationRefresh refresh(GpxPreview preview) {
    return QuarkusTransaction.requiringNew()
        .call(() -> refreshRepository.findByPreviewId(preview.getId()).orElse(null));
  }

  private long refreshCount() {
    return QuarkusTransaction.requiringNew().call(() -> refreshRepository.count());
  }

  private void makeDue(GpxPreview preview) {
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                refreshRepository.update(
                    "dueAt = ?1 where preview.id = ?2",
                    Instant.now().minusSeconds(1),
                    preview.getId()));
  }

  /** The keys of the three track files, in whatever layout, thumbnail left out. */
  private Set<String> trackKeys(GpxPreview preview) {
    Set<String> keys = new TreeSet<>(stored.previewKeys(preview.getPublicId()));
    keys.removeIf(k -> k.endsWith("/" + THUMBNAIL));
    return keys;
  }

  private static Set<String> keysOf(GpxPreview preview) {
    return new TreeSet<>(
        Set.of(
            GpxPreviewService.trackKey(preview, "original.gpx"),
            GpxPreviewService.trackKey(preview, "filtered.gpx"),
            GpxPreviewService.trackKey(preview, "route.fit")));
  }

  private byte[] read(String key) throws Exception {
    try (InputStream in = storageService.retrieve(key)) {
      return in.readAllBytes();
    }
  }

  private static void assertFlat(GpxPreview preview, double expected) {
    assertFalse(preview.getTracks().isEmpty());
    for (GpxPreview.PreviewTrack track : preview.getTracks()) {
      for (GpxTrack.TrackPoint p : track.trackPoints()) {
        assertEquals(expected, p.ele(), 1.0);
      }
    }
  }

  private static void assertWithin(Instant actual, Instant expected, Duration tolerance) {
    long drift = Math.abs(Duration.between(expected, actual).toMillis());
    assertTrue(
        drift <= tolerance.toMillis(),
        "expected " + expected + " ± " + tolerance + ", got " + actual);
  }

  /** What a preview of the previous release looks like: flat files, no revision, no quality. */
  private GpxPreview legacyPreview() throws Exception {
    GpxPreview source = previewService.create(EXAMPLE, "source.gpx");
    UUID publicId = UUID.randomUUID();
    GpxPreview legacy = dataService.createGpxPreview(domain, user, publicId);
    for (String file : new String[] {"original.gpx", "filtered.gpx", "route.fit"}) {
      byte[] bytes = read(GpxPreviewService.trackKey(source, file));
      storageService.store(
          GpxPreviewService.trackKey(publicId, null, file),
          new ByteArrayInputStream(bytes),
          "application/octet-stream",
          bytes.length);
    }
    previewService.delete(source.getPublicId().toString());
    return legacy;
  }

  // ------------------------------------------------------------------ save: FAST and the request

  @Test
  void create_isFast_underARevision_andQueuedOnce() {
    Instant before = Instant.now();

    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");

    GpxPreview preview = reload(created);
    assertEquals(ElevationState.PENDING, preview.getElevationState());
    assertNotNull(preview.getFilesRevision());
    assertFlat(preview, FakeElevationProducer.FAST_ELEVATION);
    assertEquals(
        ElevationState.PENDING, previewService.toDto(preview).elevationState(), "the DTO says so");

    assertEquals(keysOf(preview), trackKeys(preview), "the three files, under the revision only");
    assertTrue(
        GpxPreviewService.trackKey(preview, "original.gpx")
            .contains("/" + preview.getFilesRevision() + "/"));

    ElevationRefresh request = refresh(preview);
    assertNotNull(request);
    assertEquals(1, refreshCount());
    assertEquals(preview.getFilesRevision(), request.getSourceRevision());
    assertEquals(0, request.getAttempts());
    assertNull(request.getClaimedUntil());
    assertWithin(request.getDueAt(), before.plusSeconds(90), Duration.ofSeconds(15));
  }

  @Test
  void createFromPointsAndMerge_areFastAndQueuedToo() {
    GpxPreviewDto merged =
        previewService.createMergedPreview(
            java.util.List.of(
                new File("src/test/resources/merge_part_a.gpx").toPath(),
                new File("src/test/resources/merge_part_b.gpx").toPath()),
            java.util.List.of("a.gpx", "b.gpx"));

    assertEquals(ElevationState.PENDING, merged.elevationState());
    assertEquals(1, refreshCount());
  }

  @Test
  void rename_touchesNeitherRevisionNorQuality_norQueue() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    GpxPreview before = reload(created);
    ElevationRefresh requestBefore = refresh(created);
    Set<String> bucketBefore = stored.previewKeys(created.getPublicId());

    previewService.updatePreview(created.getPublicId().toString(), "Autre nom", null, null);

    GpxPreview after = reload(created);
    assertEquals("Autre nom", after.getName());
    assertEquals(before.getFilesRevision(), after.getFilesRevision());
    assertEquals(ElevationState.PENDING, after.getElevationState());
    ElevationRefresh requestAfter = refresh(created);
    assertEquals(requestBefore.getSourceRevision(), requestAfter.getSourceRevision());
    assertEquals(requestBefore.getDueAt(), requestAfter.getDueAt());
    assertEquals(1, refreshCount());
    assertEquals(bucketBefore, stored.previewKeys(created.getPublicId()));
  }

  @Test
  void renameOfAnHdPreview_staysHd_andQueuesNothing() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeDue(created);
    worker.processDue();
    assertEquals(ElevationState.HD, reload(created).getElevationState());

    previewService.updatePreview(created.getPublicId().toString(), "Autre nom", null, null);

    assertEquals(ElevationState.HD, reload(created).getElevationState());
    assertEquals(0, refreshCount());
  }

  @Test
  void updateWithATrack_writesANewRevision_deletesTheOldOne_andMovesTheRequest() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    GpxPreview first = reload(created);
    ElevationRefresh firstRequest = refresh(created);

    previewService.updatePreview(created.getPublicId().toString(), "Deux", TWO_TRACKS, null);

    GpxPreview second = reload(created);
    assertNotEquals(first.getFilesRevision(), second.getFilesRevision());
    assertEquals(2, second.getTracks().size());
    assertEquals(ElevationState.PENDING, second.getElevationState());
    assertEquals(keysOf(second), trackKeys(second), "the old revision is gone, nothing else");
    ElevationRefresh request = refresh(created);
    assertEquals(1, refreshCount());
    assertEquals(firstRequest.getId(), request.getId(), "one row per preview");
    assertEquals(second.getFilesRevision(), request.getSourceRevision());
    assertFalse(request.getDueAt().isBefore(firstRequest.getDueAt()));
    assertEquals(firstRequest.getFirstRequestedAt(), request.getFirstRequestedAt());
  }

  @Test
  void debounce_pushesTheDueTimeBack_butNeverBeyondMaxWait() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    Long previewId = created.getId();
    Instant t0 = Instant.parse("2026-10-17T10:00:00Z");
    Duration quiet = Duration.ofSeconds(90);
    Duration maxWait = Duration.ofMinutes(10);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              refreshRepository.delete("preview.id", previewId);
              refreshRepository.requestForPreview(previewId, 1L, t0, quiet, maxWait);
            });
    assertEquals(t0.plus(quiet), refresh(created).getDueAt());

    QuarkusTransaction.requiringNew()
        .run(
            () ->
                refreshRepository.requestForPreview(
                    previewId, 2L, t0.plusSeconds(60), quiet, maxWait));
    ElevationRefresh second = refresh(created);
    assertEquals(t0.plusSeconds(150), second.getDueAt());
    assertEquals(2L, second.getSourceRevision());
    assertEquals(t0, second.getFirstRequestedAt());

    QuarkusTransaction.requiringNew()
        .run(
            () ->
                refreshRepository.requestForPreview(
                    previewId, 3L, t0.plus(Duration.ofMinutes(9)), quiet, maxWait));
    assertEquals(t0.plus(maxWait), refresh(created).getDueAt());
  }

  @Test
  void switchOff_computesHdAtOnce_andQueuesNothing() {
    service.setAsyncHdEnabledForTest(false);

    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");

    GpxPreview preview = reload(created);
    assertEquals(ElevationState.HD, preview.getElevationState());
    assertFlat(preview, FakeElevationProducer.HD_ELEVATION);
    assertEquals(0, refreshCount());
    assertEquals(keysOf(preview), trackKeys(preview));

    previewService.updatePreview(created.getPublicId().toString(), "Deux", TWO_TRACKS, null);
    assertEquals(0, refreshCount());
    assertFlat(reload(created), FakeElevationProducer.HD_ELEVATION);
  }

  @Test
  void aPreviewWithNoStoredQuality_isHd() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    QuarkusTransaction.requiringNew()
        .run(
            () -> previewRepository.update("elevationState = null where id = ?1", created.getId()));

    assertEquals(ElevationState.HD, previewService.toDto(reload(created)).elevationState());
  }

  // ------------------------------------------------------------------ the worker

  @Test
  void worker_ignoresARequestThatIsNotDue() {
    previewService.create(EXAMPLE, "example.gpx");

    assertEquals(0, worker.processDue());
    assertEquals(1, refreshCount());
  }

  @Test
  void worker_switchesToANewHdRevision_andServesItByPublicId() throws Exception {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    GpxPreview before = reload(created);
    byte[] originalBefore = read(GpxPreviewService.trackKey(before, "original.gpx"));
    byte[] filteredBefore = read(GpxPreviewService.trackKey(before, "filtered.gpx"));
    byte[] fitBefore = read(GpxPreviewService.trackKey(before, "route.fit"));
    List<String> rawLinesBefore = readableRawLines(created);
    assertNotNull(rawLinesBefore, "an uploaded preview keeps its raw lines");
    makeDue(created);

    assertEquals(1, worker.processDue());

    GpxPreview after = reload(created);
    assertEquals(ElevationState.HD, after.getElevationState());
    assertNotEquals(before.getFilesRevision(), after.getFilesRevision());
    assertFlat(after, FakeElevationProducer.HD_ELEVATION);
    assertEquals(before.getName(), after.getName());
    assertEquals(before.getTracks().size(), after.getTracks().size());
    assertEquals(
        before.getTracks().getFirst().trackPoints().size(),
        after.getTracks().getFirst().trackPoints().size(),
        "same 2D track");
    assertNull(refresh(created), "request removed");
    // The raw lines follow the track onto its new revision, unchanged (docs/LEDGER_*.md API-147)
    assertEquals(rawLinesBefore, readableRawLines(created), "same raw lines, on the HD revision");
    assertEquals(
        keysOf(after), trackKeys(after), "the old revision is deleted, the new one complete");

    assertArrayEquals(
        originalBefore, read(GpxPreviewService.trackKey(after, "original.gpx")), "same original");
    assertFalse(
        java.util.Arrays.equals(
            filteredBefore, read(GpxPreviewService.trackKey(after, "filtered.gpx"))));
    assertFalse(
        java.util.Arrays.equals(fitBefore, read(GpxPreviewService.trackKey(after, "route.fit"))));

    // The links go through the publicId: they now serve the HD files
    assertArrayEquals(
        read(GpxPreviewService.trackKey(after, "filtered.gpx")),
        previewService.getFilteredGpxContent(after));
    assertArrayEquals(
        read(GpxPreviewService.trackKey(after, "route.fit")), previewService.getFitContent(after));
    assertEquals(
        ElevationState.HD,
        previewService.getPreview(created.getPublicId().toString()).elevationState());

    // The promotion to a route reads the same original
    Path downloaded = previewService.downloadOriginalGpx(after);
    try {
      assertArrayEquals(originalBefore, Files.readAllBytes(downloaded));
    } finally {
      Files.deleteIfExists(downloaded);
    }

    assertEquals(0, worker.processDue(), "nothing left to do");
  }

  @Test
  void worker_updatesTheFiguresOfTheSecondTrackToo() {
    GpxPreview created = previewService.create(TWO_TRACKS, "two.gpx");
    assertEquals(2, reload(created).getTracks().size());
    makeDue(created);

    worker.processDue();

    GpxPreview after = reload(created);
    assertEquals(2, after.getTracks().size());
    assertFlat(after, FakeElevationProducer.HD_ELEVATION);
    assertEquals(ElevationState.HD, after.getElevationState());
    assertTrue(after.getDistance() > 0);
  }

  @Test
  void
      trackSavedDuringTheCompute_nothingIsWritten_theNewRevisionIsDeleted_andTheRequestRealigned() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeDue(created);

    PreviewClaim claim = service.claimNextPreview(Instant.now()).orElseThrow();
    ElevationRefreshService.PreviewRecomputed recomputed;
    try {
      recomputed = service.computePreview(claim);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
    String hdKey =
        GpxPreviewService.trackKey(created.getPublicId(), recomputed.revision(), "filtered.gpx");
    assertTrue(storageService.exists(hdKey), "uploaded before the write");

    // The user saves a new track while the HD profile was being computed
    previewService.updatePreview(created.getPublicId().toString(), "Deux", TWO_TRACKS, null);
    GpxPreview afterSave = reload(created);

    ElevationRefreshService.Outcome outcome = service.writePreview(claim, recomputed);

    assertEquals(ElevationRefreshService.Outcome.REALIGNED, outcome);
    GpxPreview after = reload(created);
    assertEquals(afterSave.getFilesRevision(), after.getFilesRevision(), "revision untouched");
    assertEquals(ElevationState.PENDING, after.getElevationState());
    assertFlat(after, FakeElevationProducer.FAST_ELEVATION);
    assertEquals(2, after.getTracks().size(), "the new track, not the abandoned one");
    assertFalse(storageService.exists(hdKey), "the revision computed for the old track is gone");
    assertEquals(keysOf(afterSave), trackKeys(afterSave));
    ElevationRefresh request = refresh(created);
    assertNotNull(request, "the request is kept, not deleted");
    assertEquals(afterSave.getFilesRevision(), request.getSourceRevision());
    assertNull(request.getClaimedUntil());
    assertEquals(0, request.getAttempts());
    assertTrue(request.getDueAt().isAfter(Instant.now().plusSeconds(60)), "a fresh quiet period");
  }

  @Test
  void aFailure_countsAnAttempt_backsOff_andLeavesThePreviewFast() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    GpxPreview before = reload(created);
    // The original cannot be read any more: the attempt fails whatever the provider does
    storageService.delete(GpxPreviewService.trackKey(before, "original.gpx"));
    Set<String> bucketBefore = stored.previewKeys(created.getPublicId());

    Duration[] expected = {Duration.ofMinutes(2), Duration.ofMinutes(10), Duration.ofHours(1)};
    for (int attempt = 1; attempt <= expected.length; attempt++) {
      makeDue(created);
      Instant now = Instant.now();
      assertEquals(1, worker.processDue());

      ElevationRefresh request = refresh(created);
      assertEquals(attempt, request.getAttempts());
      assertNotNull(request.getLastError());
      assertNull(request.getClaimedUntil(), "lease released");
      assertWithin(request.getDueAt(), now.plus(expected[attempt - 1]), Duration.ofSeconds(30));
      GpxPreview preview = reload(created);
      assertEquals(ElevationState.PENDING, preview.getElevationState());
      assertEquals(before.getFilesRevision(), preview.getFilesRevision());
      assertEquals(0, worker.processDue(), "not due again before the backoff");
    }
    assertEquals(bucketBefore, stored.previewKeys(created.getPublicId()), "no stray file");
  }

  @Test
  void aPartialHdResult_countsAsAFailure_andWritesNothing() throws Exception {
    // Far from every other test's tiles: the HD provider caches what it already read
    Path southern = Files.createTempFile("southern-", ".gpx");
    try {
      Files.writeString(
          southern,
          """
          <?xml version="1.0" encoding="UTF-8"?>
          <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
            <trk><name>Sud</name><trkseg>
              <trkpt lat="-33.9000" lon="151.3000"><ele>10</ele></trkpt>
              <trkpt lat="-33.9100" lon="151.3100"><ele>12</ele></trkpt>
              <trkpt lat="-33.9200" lon="151.3200"><ele>14</ele></trkpt>
            </trkseg></trk>
          </gpx>
          """);
      GpxPreview created = previewService.create(southern, "sud.gpx");
      GpxPreview before = reload(created);
      Set<String> bucketBefore = stored.previewKeys(created.getPublicId());
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
      GpxPreview after = reload(created);
      assertEquals(ElevationState.PENDING, after.getElevationState());
      assertEquals(before.getFilesRevision(), after.getFilesRevision());
      assertEquals(bucketBefore, stored.previewKeys(created.getPublicId()), "no HD file kept");
    } finally {
      Files.deleteIfExists(southern);
    }
  }

  @Test
  void aSaveRestartsTheAttempts_ofAFailedRequest() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    storageService.delete(GpxPreviewService.trackKey(reload(created), "original.gpx"));
    makeDue(created);
    worker.processDue();
    assertEquals(1, refresh(created).getAttempts());

    previewService.updatePreview(created.getPublicId().toString(), "Deux", TWO_TRACKS, null);

    ElevationRefresh request = refresh(created);
    assertEquals(0, request.getAttempts());
    assertNull(request.getLastError());
    makeDue(created);
    assertEquals(1, worker.processDue());
    assertEquals(ElevationState.HD, reload(created).getElevationState());
  }

  @Test
  void aRevisionReplacedByAnHdSave_dropsTheRequest_insteadOfRecomputingHdFromHd() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    // What a save of the switched-off build does: a new revision, in HD, no request
    service.setAsyncHdEnabledForTest(false);
    previewService.updatePreview(created.getPublicId().toString(), "Deux", TWO_TRACKS, null);
    service.setAsyncHdEnabledForTest(true);
    GpxPreview current = reload(created);
    assertNotEquals(current.getFilesRevision(), refresh(created).getSourceRevision());
    makeDue(created);

    assertEquals(1, worker.processDue());

    assertNull(refresh(created), "nothing left to catch up on");
    assertEquals(keysOf(current), trackKeys(current), "no IGN round trip, no new revision");
  }

  // ------------------------------------------------------------------ planner state (WEB-100, C4a)

  @Inject GpxProcessingService processing;
  @Inject PlannerStates plannerStates;

  private GpxPreview createWithState(PlannerState state) {
    GpxDocument gpx = processing.fromPoints("Drawn", plannerStates.validateAndDerive(state));
    return previewService.create(gpx, "Drawn", state.drawn(), state);
  }

  private PlannerStateDocument storedState(GpxPreview preview) {
    return QuarkusTransaction.requiringNew()
        .call(() -> previewRepository.findById(preview.getId()).getPlannerState());
  }

  @Test
  void aPlannerState_isNotReadableAcrossDomains() {
    GpxPreview created = createWithState(PlannerStateFixtures.example());
    Domain other =
        dataService.createDomain("other.example.org", "Other", "https://other.example.org");
    domainResolver.setDomainForTest(other);

    org.junit.jupiter.api.Assertions.assertThrows(
        fr.pedalons.common.exception.NotFoundException.class,
        () -> previewService.getPlannerState(created.getPublicId().toString()));
  }

  @Test
  void theHdCatchUp_carriesThePlannerState_toTheNewRevision() {
    GpxPreview created = createWithState(PlannerStateFixtures.example());
    Long fastRevision = reload(created).getFilesRevision();
    assertEquals(fastRevision, storedState(created).trackRevision());
    makeDue(created);

    assertEquals(1, worker.processDue());

    GpxPreview after = reload(created);
    assertNotEquals(fastRevision, after.getFilesRevision());
    assertEquals(after.getFilesRevision(), storedState(created).trackRevision());
    assertNotNull(
        previewService.getPlannerState(created.getPublicId().toString()).state(),
        "still readable after the catch-up");
  }

  @Test
  void aTrackSavedDuringTheCompute_carriesNothing() {
    GpxPreview created = createWithState(PlannerStateFixtures.example());
    makeDue(created);
    PreviewClaim claim = service.claimNextPreview(Instant.now()).orElseThrow();
    ElevationRefreshService.PreviewRecomputed recomputed;
    try {
      recomputed = service.computePreview(claim);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
    // Saved again meanwhile, by a path that carries no state
    previewService.updatePreview(created.getPublicId().toString(), "Deux", TWO_TRACKS, null);
    Long current = reload(created).getFilesRevision();

    assertEquals(
        ElevationRefreshService.Outcome.REALIGNED, service.writePreview(claim, recomputed));

    assertNull(storedState(created), "cleared by the save, not rewritten by the catch-up");
    assertEquals(current, reload(created).getFilesRevision());
  }

  // ------------------------------------------------------------------ removal

  @Test
  void deletingThePreview_removesItsRequest_andItsFiles() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    assertEquals(1, refreshCount());

    previewService.delete(created.getPublicId().toString());

    assertEquals(0, refreshCount(), "the cascade took the request");
    assertTrue(stored.previewKeys(created.getPublicId()).isEmpty(), "every file, thumbnail too");
  }

  @Test
  void aDeletedPreview_isNotRecomputed() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeDue(created);
    previewService.delete(created.getPublicId().toString());

    assertEquals(0, worker.processDue());
  }

  @Test
  void purgingExpiredPreviews_removesTheirRequestsAndRevisionFiles() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    dataService.backdateGpxPreview(created, GpxPreviewService.RETENTION_DAYS + 1);

    assertEquals(1, previewService.purgeExpired());

    assertEquals(0, refreshCount());
    assertTrue(stored.previewKeys(created.getPublicId()).isEmpty());
  }

  @Test
  void purgingAnHdPreview_removesTheSwitchedRevision() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeDue(created);
    worker.processDue();
    dataService.backdateGpxPreview(created, GpxPreviewService.RETENTION_DAYS + 1);

    assertEquals(1, previewService.purgeExpired());

    assertTrue(stored.previewKeys(created.getPublicId()).isEmpty());
  }

  // ------------------------------------------------------------------ the flat layout

  @Test
  void aFlatPreview_staysReadable_exportable_andDeletable() throws Exception {
    GpxPreview legacy = legacyPreview();
    assertNull(legacy.getFilesRevision());
    assertEquals(
        ElevationState.HD, previewService.toDto(reload(legacy)).elevationState(), "null is HD");

    GpxPreview preview = reload(legacy);
    assertTrue(previewService.getFilteredGpxContent(preview).length > 0);
    assertTrue(previewService.getFitContent(preview).length > 0);
    Path downloaded = previewService.downloadOriginalGpx(preview);
    try {
      assertTrue(Files.size(downloaded) > 0);
    } finally {
      Files.deleteIfExists(downloaded);
    }
    Map<String, String> keys = previewService.exportKeys(preview);
    String prefix = "gpx-previews/" + preview.getPublicId() + "/";
    assertEquals(prefix + "original.gpx", keys.get("original.gpx"));
    assertEquals(prefix + "filtered.gpx", keys.get("filtered.gpx"));
    assertEquals(prefix + "route.fit", keys.get("route.fit"));
    for (String key : keys.values()) {
      assertTrue(storageService.exists(key), key);
    }
    // Rename: nothing to move
    previewService.updatePreview(preview.getPublicId().toString(), "Renommé", null, null);
    assertEquals(0, refreshCount());

    previewService.delete(preview.getPublicId().toString());

    for (String key : keys.values()) {
      assertFalse(storageService.exists(key), key);
    }
  }

  @Test
  void updatingAFlatPreviewWithATrack_movesItToARevision_andDeletesTheFlatFiles() throws Exception {
    GpxPreview legacy = legacyPreview();
    Set<String> flat = keysOf(legacy);

    previewService.updatePreview(legacy.getPublicId().toString(), "Deux", TWO_TRACKS, null);

    GpxPreview after = reload(legacy);
    assertNotNull(after.getFilesRevision());
    assertEquals(ElevationState.PENDING, after.getElevationState());
    assertEquals(1, refreshCount());
    for (String key : flat) {
      assertFalse(storageService.exists(key), "flat file deleted: " + key);
    }
    assertEquals(keysOf(after), trackKeys(after));
  }

  @Test
  void aRequestOnAPreviewBackOnTheFlatLayout_isDropped() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    QuarkusTransaction.requiringNew()
        .run(() -> previewRepository.update("filesRevision = null where id = ?1", created.getId()));
    makeDue(created);

    assertEquals(1, worker.processDue());

    assertEquals(0, refreshCount(), "nothing to catch up on");
    assertEquals(
        ElevationState.HD,
        reload(created).getElevationState(),
        "rewritten flat by the previous release, in HD: not left PENDING for ever");
  }

  @Test
  void aPreviewRewrittenFlatDuringTheCompute_isHd_andItsRequestDropped() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeDue(created);
    PreviewClaim claim = service.claimNextPreview(Instant.now()).orElseThrow();
    ElevationRefreshService.PreviewRecomputed recomputed;
    try {
      recomputed = service.computePreview(claim);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }

    // The previous release of a rolling deploy rewrites the preview flat, in HD
    QuarkusTransaction.requiringNew()
        .run(() -> previewRepository.update("filesRevision = null where id = ?1", created.getId()));

    assertEquals(ElevationRefreshService.Outcome.GONE, service.writePreview(claim, recomputed));

    assertEquals(0, refreshCount());
    assertEquals(ElevationState.HD, reload(created).getElevationState());
  }

  @Test
  void aGivenUpPreview_isFast_andASaveMakesItPendingAgain() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    storageService.delete(GpxPreviewService.trackKey(reload(created), "original.gpx"));
    for (int attempt = 1; attempt <= ElevationRefreshService.MAX_ATTEMPTS; attempt++) {
      makeDue(created);
      assertEquals(1, worker.processDue());
    }
    assertEquals(ElevationState.FAST, reload(created).getElevationState());
    assertEquals(
        ElevationState.FAST,
        previewService.getPreview(created.getPublicId().toString()).elevationState());

    previewService.updatePreview(created.getPublicId().toString(), "Deux", TWO_TRACKS, null);

    assertEquals(ElevationState.PENDING, reload(created).getElevationState());
    assertEquals(0, refresh(created).getAttempts());
    makeDue(created);
    assertEquals(1, worker.processDue());
    assertEquals(ElevationState.HD, reload(created).getElevationState());
  }

  @Test
  void aPreviewIsNotReadableAcrossDomains() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    Domain other =
        dataService.createDomain("other.example.org", "Other", "https://other.example.org");
    domainResolver.setDomainForTest(other);

    org.junit.jupiter.api.Assertions.assertThrows(
        fr.pedalons.common.exception.NotFoundException.class,
        () -> previewService.getPreview(created.getPublicId().toString()));
  }

  // ==================== waypoints (docs/LEDGER_*.md WEB-100, C3c) ====================

  private static final Path WAYPOINTS = new File("src/test/resources/waypoints.gpx").toPath();

  @Test
  void hdCatchUp_keepsWaypoints_updatesTheirDistances() {
    GpxPreview created = previewService.create(WAYPOINTS, "waypoints.gpx");
    GpxPreview before = reload(created);
    assertEquals(3, before.readableWaypoints().size());
    makeDue(created);

    worker.processDue();

    GpxPreview after = reload(created);
    assertNotEquals(before.getFilesRevision(), after.getFilesRevision());
    var waypoints = after.readableWaypoints();
    assertEquals(3, waypoints.size(), "read from the document of the new revision");
    assertEquals(after.getFilesRevision(), after.getWaypointDetails().trackRevision());
    assertTrue(waypoints.stream().anyMatch(w -> "WATER".equals(w.type())), "typed");
    assertTrue(waypoints.stream().allMatch(w -> w.distance() != null));
    assertEquals(3, after.getWaypoints().size(), "the historical column follows");
  }

  @Test
  void hdCatchUp_waypointsEditedDuringCompute_realigns_andWritesNothing() {
    GpxPreview created = previewService.create(WAYPOINTS, "waypoints.gpx");
    makeDue(created);
    PreviewClaim claim = service.claimNextPreview(Instant.now()).orElseThrow();
    ElevationRefreshService.PreviewRecomputed recomputed;
    try {
      recomputed = service.computePreview(claim);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
    String hdKey =
        GpxPreviewService.trackKey(created.getPublicId(), recomputed.revision(), "filtered.gpx");

    // The creator edits the waypoints (the track stays) while the HD profile was being computed
    previewService.updatePreview(
        created.getPublicId().toString(),
        "waypoints.gpx",
        null,
        null,
        null,
        java.util.List.of(
            new fr.pedalons.dto.routes.request.WaypointRequest(
                null,
                new fr.pedalons.common.GeoPoint(-1.5456685, 47.2024271),
                fr.pedalons.enums.WaypointType.CAFE,
                "Nouveau",
                null,
                null,
                null)));
    GpxPreview afterEdit = reload(created);

    ElevationRefreshService.Outcome outcome = service.writePreview(claim, recomputed);

    assertEquals(ElevationRefreshService.Outcome.REALIGNED, outcome);
    GpxPreview after = reload(created);
    assertEquals(afterEdit.getFilesRevision(), after.getFilesRevision(), "revision untouched");
    assertEquals(ElevationState.PENDING, after.getElevationState());
    assertEquals(1, after.readableWaypoints().size());
    assertFalse(storageService.exists(hdKey), "the revision computed meanwhile is gone");
    assertNotNull(refresh(created), "the request is kept");
  }
}
