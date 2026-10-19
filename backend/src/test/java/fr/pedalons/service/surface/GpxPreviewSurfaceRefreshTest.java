package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
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
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TrackSurfaceState;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.valhalla.StadiaTraceAttributesClient;
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
 * docs/LEDGER_*.md WEB-100 (C1b), previews of the GPX tools: the request under the preview's
 * {@code files_revision}, the document that follows the HD catch-up, and the promotion to a route
 * that takes the surface along. No test reaches Stadia Maps.
 */
@QuarkusTest
class GpxPreviewSurfaceRefreshTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();

  @InjectMock @RestClient StadiaTraceAttributesClient client;

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
  void everyWayOfCreatingAPreview_queuesARequestUnderItsRevision() {
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
      SurfaceRefresh request = refresh(preview);
      assertNotNull(request, "a request for " + preview.getName());
      assertEquals(preview.getFilesRevision(), request.getSourceRevision());
      assertEquals(TrackSurfaceState.PENDING, dto(preview).tracks().getFirst().surfaceState());
    }
    assertEquals(3, refreshCount());
  }

  @Inject GpxProcessingService gpxProcessingService;

  private GpxPreview stateBased() {
    var dto = previewService.createPreviewFromPoints("state", null, PlannerStateFixtures.drawn());
    return QuarkusTransaction.requiringNew().call(() -> previewService.getByPublicId(dto.id()));
  }

  @Test
  void aMergedPreview_isQueuedAndPendingToo() {
    GpxPreviewDto merged =
        previewService.createMergedPreview(
            List.of(
                new File("src/test/resources/merge_part_a.gpx").toPath(),
                new File("src/test/resources/merge_part_b.gpx").toPath()),
            List.of("a.gpx", "b.gpx"));

    GpxPreview preview =
        QuarkusTransaction.requiringNew().call(() -> previewService.getByPublicId(merged.id()));
    assertEquals(preview.getFilesRevision(), refresh(preview).getSourceRevision());
    assertTrue(
        merged.tracks().stream().allMatch(t -> t.surfaceState() == TrackSurfaceState.PENDING));
  }

  @Test
  void deletingAPreview_takesItsRequestAlong() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
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
  void aRename_keepsTheSurface_andAReplacedTrackClearsItAndAsksAgain() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
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
    assertEquals(preview.getFilesRevision(), refresh(preview).getSourceRevision());
    assertEquals(TrackSurfaceState.PENDING, dto(preview).tracks().getFirst().surfaceState());
  }

  @Test
  void aDocumentOfAStaleRevision_isNotServed() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeDue(created);
    worker.processDue();
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
  void theHdCatchUp_afterTheSurface_carriesTheDocumentOntoTheNewRevision() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeDue(created);
    worker.processDue();
    long before = reload(created).getFilesRevision();

    makeElevationDue(created);
    assertEquals(1, elevationWorker.processDue());

    GpxPreview preview = reload(created);
    assertNotEquals(before, preview.getFilesRevision());
    assertEquals(preview.getFilesRevision(), surfaces(preview).trackRevision());
    assertEquals(TrackSurfaceState.READY, dto(preview).tracks().getFirst().surfaceState());
    verify(client, times(1)).traceAttributes(any());
  }

  @Test
  void theHdCatchUp_beforeTheSurface_movesThePendingRequest_soOneCallIsEnough() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    makeElevationDue(created);
    assertEquals(1, elevationWorker.processDue());

    GpxPreview preview = reload(created);
    assertEquals(preview.getFilesRevision(), refresh(preview).getSourceRevision());

    makeDue(preview);
    assertEquals(1, worker.processDue());
    verify(client, times(1)).traceAttributes(any());
    assertEquals(preview.getFilesRevision(), surfaces(preview).trackRevision());
  }

  // ------------------------------------------------------------------ promotion

  @Test
  void aPromotion_takesTheDocumentsAlong_forTheCreatorAndForAnotherMember_withoutACall() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
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
  void aPromotion_ofAPendingPreview_makesTheRoutesOwnRequest() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");

    RouteDto route =
        previewService.createRoute(created.getPublicId().toString(), team1Slug, routeRequest());

    assertEquals(2, refreshCount(), "the preview's, and the route's");
    long routeRequests =
        QuarkusTransaction.requiringNew()
            .call(() -> refreshRepository.count("route.id is not null"));
    assertEquals(1, routeRequests);
    assertNotNull(route);
  }
}
