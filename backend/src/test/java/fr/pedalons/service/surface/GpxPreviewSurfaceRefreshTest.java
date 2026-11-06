package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.route.SurfaceRefresh;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.gpx.response.GpxPreviewDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TrackSurfaceState;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.infrastructure.valhalla.TraceAttributesClient;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.SurfaceRefreshRepository;
import fr.pedalons.service.elevation.ElevationRefreshWorker;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.planner.PlannerStateFixtures;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.File;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.hibernate.Hibernate;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md WEB-100 (C1b), previews of the GPX tools: the legacy request under the preview's
 * {@code files_revision}, the document of the HD catch-up, and the promotion to a route that takes
 * the surface along. Since docs/LEDGER_*.md API-150 (phase C) a save queues nothing: the tests of
 * the worker seed the request ({@link #queue}), as the previous release does. No test reaches
 * osm-surface.
 */
@QuarkusTest
class GpxPreviewSurfaceRefreshTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();

  @InjectMock @RestClient TraceAttributesClient client;

  @Inject GpxPreviewService previewService;
  @Inject GpxPreviewRepository previewRepository;
  @Inject SurfaceRefreshService service;
  @Inject SurfaceRefreshWorker worker;
  @Inject SurfaceRefreshRepository refreshRepository;
  @Inject ElevationRefreshWorker elevationWorker;
  @Inject ElevationRefreshRepository elevationRefreshRepository;
  @Inject GpxTrackRepository trackRepository;
  @Inject PedalonsQueryContext context;
  @Inject DomainResolver domainResolver;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setDomainEnableGpxPlanner(domain, true);
    domainResolver.setDomainForTest(dataService.getOrCreateDefaultDomain());
    dataService.setTeamEnableRoutePlanner(team1, true);
    context.setUserForTest(user1);
    when(client.traceAttributes(any()))
        .thenAnswer(inv -> TraceFixtures.answer(inv.getArgument(0), i -> "paved"));
    service.setEnabledForTest(true);
  }

  @AfterEach
  void restoreSwitch() {
    service.setEnabledForTest(false);
  }

  // ------------------------------------------------------------------ helpers

  private GpxPreview reload(GpxPreview preview) {
    return QuarkusTransaction.requiringNew()
        .call(() -> previewRepository.findById(preview.getId()));
  }

  private PreviewSurfacesDocument surfaces(GpxPreview preview) {
    return QuarkusTransaction.requiringNew()
        .call(() -> previewRepository.findSurfaces(preview.getId()));
  }

  /** A request of the legacy queue, as the previous release left it. */
  private void queue(GpxPreview preview) {
    long revision = reload(preview).getFilesRevision();
    QuarkusTransaction.requiringNew().run(() -> service.requestPreview(preview.getId(), revision));
  }

  /** The HD catch-up given up: what is said of the surface no longer comes from it. */
  private void catchUpGivenUp(GpxPreview preview) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              elevationRefreshRepository.delete("preview.id", preview.getId());
              previewRepository.update(
                  "elevationState = ?1 where id = ?2", ElevationState.FAST, preview.getId());
            });
  }

  private long elevationRevision(GpxPreview preview) {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                elevationRefreshRepository
                    .findByPreviewId(preview.getId())
                    .orElseThrow()
                    .getSourceRevision());
  }

  private SurfaceRefresh refresh(GpxPreview preview) {
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

  private GpxPreviewDto dto(GpxPreview preview) {
    return previewService.getPreview(preview.getPublicId().toString());
  }

  private static RouteRequest routeRequest() {
    return new RouteRequest(
        "Promu",
        MediaDto.builder().markdown("Parcours").build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null);
  }

  // ------------------------------------------------------------------ requests

  @Test
  void everyWayOfCreatingAPreview_queuesNoSurfaceRequest_andIsPendingOnItsHdCatchUp() {
    List<GpxPreview> previews =
        List.of(
            previewService.create(EXAMPLE, "example.gpx"),
            previewService.create(
                gpxProcessingService.fromPoints(
                    "points",
                    List.of(
                        new GeoPoint(2.0, 48.0),
                        new GeoPoint(2.01, 48.01),
                        new GeoPoint(2.02, 48.0))),
                "points",
                true),
            stateBased());
    for (GpxPreview created : previews) {
      GpxPreview preview = reload(created);
      assertNull(refresh(preview), "no request for " + preview.getName());
      assertEquals(preview.getFilesRevision(), elevationRevision(preview));
      assertEquals(TrackSurfaceState.PENDING, dto(preview).tracks().getFirst().surfaceState());
    }
    assertEquals(0, refreshCount());
  }

  @Inject GpxProcessingService gpxProcessingService;

  private GpxPreview stateBased() {
    var dto = previewService.createPreviewFromPoints("state", null, PlannerStateFixtures.drawn());
    return QuarkusTransaction.requiringNew().call(() -> previewService.getByPublicId(dto.id()));
  }

  @Test
  void aMergedPreview_isPendingToo_withoutASurfaceRequest() {
    GpxPreviewDto merged =
        previewService.createMergedPreview(
            List.of(
                new File("src/test/resources/merge_part_a.gpx").toPath(),
                new File("src/test/resources/merge_part_b.gpx").toPath()),
            List.of("a.gpx", "b.gpx"));

    GpxPreview preview =
        QuarkusTransaction.requiringNew().call(() -> previewService.getByPublicId(merged.id()));
    assertNull(refresh(preview));
    assertEquals(preview.getFilesRevision(), elevationRevision(preview));
    assertTrue(
        merged.tracks().stream().allMatch(t -> t.surfaceState() == TrackSurfaceState.PENDING));
  }

  @Test
  void deletingAPreview_takesItsRequestAlong() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    assertEquals(1, refreshCount());

    previewService.delete(created.getPublicId().toString());

    assertEquals(0, refreshCount());
    makeDue(created);
    assertEquals(0, worker.processDue());
    verify(client, never()).traceAttributes(any());
  }

  @Test
  void theWorker_storesTheDocumentUnderTheRevision_andTheDtoIsReady() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);

    assertEquals(1, worker.processDue());

    GpxPreview preview = reload(created);
    PreviewSurfacesDocument stored = surfaces(preview);
    assertEquals(preview.getFilesRevision(), stored.trackRevision());
    assertEquals(preview.getTracks().size(), stored.tracks().size());
    assertEquals(0, refreshCount());
    var track = dto(preview).tracks().getFirst();
    assertEquals(TrackSurfaceState.READY, track.surfaceState());
    assertEquals("PAVED", track.surfaces().getFirst().surface().name());
  }

  @Test
  void theSurfaceColumn_isLazy_apartFromThePlannerState() {
    GpxPreview created = stateBased();
    queue(created);
    makeDue(created);
    worker.processDue();

    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxPreview preview = previewRepository.findById(created.getId());
              assertFalse(Hibernate.isPropertyInitialized(preview, "surfaces"));
              assertNotNull(preview.getPlannerState());
              assertFalse(Hibernate.isPropertyInitialized(preview, "surfaces"));
              assertNotNull(preview.getSurfaces());
            });
  }

  @Test
  void aRename_keepsTheSurface_andAReplacedTrackClearsItAndWaitsForItsCatchUp() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);
    worker.processDue();

    previewService.updatePreview(created.getPublicId().toString(), "Renommé", null, null);
    assertNotNull(surfaces(created));
    assertEquals(0, refreshCount());
    assertEquals(TrackSurfaceState.READY, dto(created).tracks().getFirst().surfaceState());

    long revision = reload(created).getFilesRevision();
    previewService.updatePreview(created.getPublicId().toString(), "Renommé", EXAMPLE, null);
    GpxPreview preview = reload(created);
    assertNull(surfaces(preview));
    assertNotEquals(revision, preview.getFilesRevision());
    assertNull(refresh(preview), "nothing queued for osm-surface");
    assertEquals(preview.getFilesRevision(), elevationRevision(preview));
    assertEquals(TrackSurfaceState.PENDING, dto(preview).tracks().getFirst().surfaceState());
  }

  @Test
  void aDocumentOfAStaleRevision_isNotServed() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);
    worker.processDue();
    catchUpGivenUp(created);
    PreviewSurfacesDocument stored = surfaces(created);
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                previewRepository
                    .findById(created.getId())
                    .setSurfaces(stored.withTrackRevision(stored.trackRevision() + 1)));

    assertNull(dto(created).tracks().getFirst().surfaceState());

    QuarkusTransaction.requiringNew()
        .run(
            () ->
                previewRepository
                    .findById(created.getId())
                    .setSurfaces(
                        new PreviewSurfacesDocument(
                            stored.trackRevision(), Arrays.asList(null, null))));
    assertNull(dto(created).tracks().getFirst().surfaceState(), "not the number of tracks");
  }

  // ------------------------------------------------------------------ raw line (API-149, B)

  private int sentPoints() {
    org.mockito.ArgumentCaptor<fr.pedalons.infrastructure.valhalla.TraceAttributesRequest> captor =
        org.mockito.ArgumentCaptor.forClass(
            fr.pedalons.infrastructure.valhalla.TraceAttributesRequest.class);
    verify(client, times(1)).traceAttributes(captor.capture());
    return fr.pedalons.infrastructure.valhalla.Polyline6Decoder.decode(
            captor.getValue().encodedPolyline())
        .size();
  }

  @Test
  void theRawLine_isSent_whileItDescribesTheTracks() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);
    List<String> lines =
        QuarkusTransaction.requiringNew()
            .call(() -> previewRepository.findById(created.getId()).readableRawLines());
    assertNotNull(lines);

    assertEquals(1, worker.processDue());

    int expected =
        TraceSurfaceComputer.decimate(
                fr.pedalons.infrastructure.valhalla.Polyline6Decoder.decode(lines.getFirst()),
                TraceSurfaceComputer.MIN_SPACING_M)
            .size();
    assertEquals(expected, sentPoints());
    assertNotEquals(reload(created).getTracks().getFirst().trackPoints().size(), expected);
  }

  @Test
  void rawLinesOfAStaleRevision_areNotSent_theTrackPointsAre() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxPreview preview = previewRepository.findById(created.getId());
              preview.setRawLines(
                  preview.getRawLines().withTrackRevision(preview.getFilesRevision() + 1));
            });

    assertEquals(1, worker.processDue());

    assertEquals(reload(created).getTracks().getFirst().trackPoints().size(), sentPoints());
    assertEquals(TrackSurfaceState.READY, dto(created).tracks().getFirst().surfaceState());
  }

  // ------------------------------------------------------------------ HD catch-up

  private void makeElevationDue(GpxPreview preview) {
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                elevationRefreshRepository.update(
                    "dueAt = ?1 where preview.id = ?2",
                    Instant.now().minusSeconds(1),
                    preview.getId()));
  }

  @Test
  void theHdCatchUp_afterTheQueue_writesItsDocumentOnTheNewRevision() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);
    worker.processDue();
    long before = reload(created).getFilesRevision();
    assertEquals(TrackSurfaceDocument.VERSION, surfaces(created).tracks().getFirst().version());

    makeElevationDue(created);
    assertEquals(1, elevationWorker.processDue());

    GpxPreview preview = reload(created);
    assertNotEquals(before, preview.getFilesRevision());
    PreviewSurfacesDocument stored = surfaces(preview);
    assertEquals(preview.getFilesRevision(), stored.trackRevision());
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, stored.tracks().getFirst().version());
    assertEquals(TrackSurfaceState.READY, dto(preview).tracks().getFirst().surfaceState());
    verify(client, times(1)).traceAttributes(any());
  }

  @Test
  void withTheSwitchOff_theHdCatchUp_carriesTheDocumentOntoTheNewRevision() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);
    worker.processDue();
    PreviewSurfacesDocument before = surfaces(created);
    service.setEnabledForTest(false);

    makeElevationDue(created);
    assertEquals(1, elevationWorker.processDue());

    GpxPreview preview = reload(created);
    assertNotEquals(before.trackRevision(), preview.getFilesRevision());
    assertEquals(before.withTrackRevision(preview.getFilesRevision()), surfaces(preview));
    assertEquals(TrackSurfaceState.READY, dto(preview).tracks().getFirst().surfaceState());
  }

  @Test
  void theHdCatchUp_beforeTheQueue_dropsTheRequest_andNoCallIsMade() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeElevationDue(created);

    assertEquals(1, elevationWorker.processDue());

    GpxPreview preview = reload(created);
    assertNull(refresh(preview));
    assertEquals(0, worker.processDue());
    verify(client, never()).traceAttributes(any());
    assertEquals(preview.getFilesRevision(), surfaces(preview).trackRevision());
  }

  @Test
  void withTheSwitchOff_theHdCatchUp_movesTheRequestWaiting_soOneCallIsEnough() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    service.setEnabledForTest(false);
    makeElevationDue(created);
    assertEquals(1, elevationWorker.processDue());
    service.setEnabledForTest(true);

    GpxPreview preview = reload(created);
    assertEquals(preview.getFilesRevision(), refresh(preview).getSourceRevision());

    makeDue(preview);
    assertEquals(1, worker.processDue());
    verify(client, times(1)).traceAttributes(any());
    assertEquals(preview.getFilesRevision(), surfaces(preview).trackRevision());
  }

  @Test
  void aWorkerMidCompute_neverReplacesTheDocumentOfTheHdCatchUp() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);
    makeElevationDue(created);
    doAnswer(
            inv -> {
              assertEquals(1, elevationWorker.processDue());
              return TraceFixtures.answer(inv.getArgument(0), i -> "gravel");
            })
        .when(client)
        .traceAttributes(any());

    assertEquals(1, worker.processDue());

    GpxPreview preview = reload(created);
    PreviewSurfacesDocument stored = surfaces(preview);
    assertEquals(preview.getFilesRevision(), stored.trackRevision());
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, stored.tracks().getFirst().version());
    assertEquals("PAVED", dto(preview).tracks().getFirst().surfaces().getFirst().surface().name());
    assertEquals(0, refreshCount());
  }

  /**
   * A surface written alone keeps the revision, so only the request gone stops the worker, unlike
   * the catch-up above whose new revision already does.
   */
  @Test
  void aWorkerMidCompute_neverReplacesTheDocumentOfASurfaceWrittenAlone() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    Long revision = reload(created).getFilesRevision();
    queue(created);
    makeDue(created);
    makeElevationDue(created);
    doAnswer(
            inv -> {
              FakeRouteDetailsClient.fallbackAfterError = true;
              assertEquals(1, elevationWorker.processDue());
              FakeRouteDetailsClient.fallbackAfterError = false;
              return TraceFixtures.answer(inv.getArgument(0), i -> "gravel");
            })
        .when(client)
        .traceAttributes(any());

    assertEquals(1, worker.processDue());

    GpxPreview preview = reload(created);
    assertEquals(revision, preview.getFilesRevision());
    PreviewSurfacesDocument stored = surfaces(preview);
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, stored.tracks().getFirst().version());
    assertEquals("PAVED", dto(preview).tracks().getFirst().surfaces().getFirst().surface().name());
    assertEquals(0, refreshCount());
  }

  // ------------------------------------------------------------------ promotion

  @Test
  void aPromotion_takesTheDocumentsAlong_forTheCreatorAndForAnotherMember_withoutACall() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    queue(created);
    makeDue(created);
    worker.processDue();
    reset(client);

    RouteDto byCreator =
        previewService.createRoute(created.getPublicId().toString(), team1Slug, routeRequest());
    context.setUserForTest(user2);
    RouteDto byOther =
        previewService.createRoute(created.getPublicId().toString(), team1Slug, routeRequest());

    verify(client, never()).traceAttributes(any());
    assertEquals(0, refreshCount());
    for (RouteDto route : List.of(byCreator, byOther)) {
      var found =
          QuarkusTransaction.requiringNew()
              .call(
                  () ->
                      trackRepository.findSurfaces(
                          fr.pedalons.common.TsidUtils.toLong(route.id())));
      assertEquals(1, found.size());
      TrackSurfaceDocument doc = found.values().iterator().next();
      assertTrue(doc.ok());
    }
  }

  @Test
  void aPromotion_takesTheDocumentOfTheHdCatchUpAlong() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeElevationDue(created);
    assertEquals(1, elevationWorker.processDue());

    RouteDto route =
        previewService.createRoute(created.getPublicId().toString(), team1Slug, routeRequest());

    Long routeId = fr.pedalons.common.TsidUtils.toLong(route.id());
    TrackSurfaceDocument doc =
        QuarkusTransaction.requiringNew()
            .call(() -> trackRepository.findSurfaces(routeId).values().iterator().next());
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, doc.version());
    assertEquals(0, refreshCount());
  }

  @Test
  void aPromotion_ofAPendingPreview_waitsForTheCatchUpOfTheRoute() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");

    RouteDto route =
        previewService.createRoute(created.getPublicId().toString(), team1Slug, routeRequest());

    assertEquals(0, refreshCount());
    Long routeId = fr.pedalons.common.TsidUtils.toLong(route.id());
    assertTrue(
        QuarkusTransaction.requiringNew()
            .call(() -> elevationRefreshRepository.findByRouteId(routeId).isPresent()),
        "the route has its own request");
    assertTrue(
        QuarkusTransaction.requiringNew()
            .call(() -> elevationRefreshRepository.findByPreviewId(created.getId()).isPresent()),
        "as the preview keeps its");
  }
}
