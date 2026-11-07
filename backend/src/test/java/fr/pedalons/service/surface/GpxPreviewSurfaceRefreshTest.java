package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.gpx.response.GpxPreviewDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TrackSurfaceState;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.service.elevation.ElevationRefreshWorker;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.planner.PlannerStateFixtures;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.File;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.hibernate.Hibernate;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md WEB-100 (C1b), previews of the GPX tools: the document under the preview's
 * {@code files_revision}, the one of the HD catch-up, and the promotion to a route that takes the
 * surface along. A version 1 document is seeded ({@link #storeVersion1}): nothing writes one any
 * more (docs/LEDGER_*.md API-150), but the previews that hold one stay readable.
 */
@QuarkusTest
class GpxPreviewSurfaceRefreshTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();

  @Inject GpxPreviewService previewService;
  @Inject GpxPreviewRepository previewRepository;
  @Inject SurfaceRefreshService service;
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

  /** The document a preview keeps from the former queue, one per track, under its revision. */
  private void storeVersion1(GpxPreview preview) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxPreview managed = previewRepository.findById(preview.getId());
              List<TrackSurfaceDocument> documents = new ArrayList<>();
              for (GpxPreview.PreviewTrack track : managed.getTracks()) {
                documents.add(version1(track.trackPoints().getLast().dist()));
              }
              managed.setSurfaces(
                  new PreviewSurfacesDocument(managed.getFilesRevision(), documents));
            });
  }

  private static TrackSurfaceDocument version1(double length) {
    return new TrackSurfaceDocument(
        TrackSurfaceDocument.VERSION,
        TrackSurfaceDocument.STATUS_OK,
        null,
        123L,
        Instant.parse("2026-10-20T08:00:00Z"),
        "bicycle",
        length,
        List.of(new SurfaceRange(0, length, "paved")),
        List.of(new WayRange(0, length, "road", "none")));
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
      assertEquals(preview.getFilesRevision(), elevationRevision(preview));
      assertEquals(TrackSurfaceState.PENDING, dto(preview).tracks().getFirst().surfaceState());
    }
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
    assertEquals(preview.getFilesRevision(), elevationRevision(preview));
    assertTrue(
        merged.tracks().stream().allMatch(t -> t.surfaceState() == TrackSurfaceState.PENDING));
  }

  @Test
  void theSurfaceColumn_isLazy_apartFromThePlannerState() {
    GpxPreview created = stateBased();
    storeVersion1(created);

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
    storeVersion1(created);

    previewService.updatePreview(created.getPublicId().toString(), "Renommé", null, null);
    assertNotNull(surfaces(created));
    assertEquals(TrackSurfaceState.READY, dto(created).tracks().getFirst().surfaceState());

    long revision = reload(created).getFilesRevision();
    previewService.updatePreview(created.getPublicId().toString(), "Renommé", EXAMPLE, null);
    GpxPreview preview = reload(created);
    assertNull(surfaces(preview));
    assertNotEquals(revision, preview.getFilesRevision());
    assertEquals(preview.getFilesRevision(), elevationRevision(preview));
    assertEquals(TrackSurfaceState.PENDING, dto(preview).tracks().getFirst().surfaceState());
  }

  @Test
  void aDocumentOfAStaleRevision_isNotServed() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    storeVersion1(created);
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
  void theHdCatchUp_replacesAVersion1Document_onTheNewRevision() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    storeVersion1(created);
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
  }

  @Test
  void withTheSwitchOff_theHdCatchUp_carriesTheDocumentOntoTheNewRevision() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    storeVersion1(created);
    PreviewSurfacesDocument before = surfaces(created);
    service.setEnabledForTest(false);

    makeElevationDue(created);
    assertEquals(1, elevationWorker.processDue());

    GpxPreview preview = reload(created);
    assertNotEquals(before.trackRevision(), preview.getFilesRevision());
    assertEquals(before.withTrackRevision(preview.getFilesRevision()), surfaces(preview));
    assertEquals(TrackSurfaceState.READY, dto(preview).tracks().getFirst().surfaceState());
  }

  /** Without a document once the HD catch-up is over, the API says nothing. */
  @Test
  void aPreviewWithoutADocument_afterItsHdCatchUp_readsAsNothing() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              elevationRefreshRepository.delete("preview.id", created.getId());
              previewRepository.update(
                  "elevationState = ?1 where id = ?2", ElevationState.HD, created.getId());
            });

    var track = dto(created).tracks().getFirst();
    assertNull(track.surfaceState());
    assertNull(track.surfaces());
    assertEquals(0, elevationWorker.processDue());
  }

  // ------------------------------------------------------------------ promotion

  @Test
  void aPromotion_takesTheDocumentsAlong_forTheCreatorAndForAnotherMember_withoutACall() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");
    storeVersion1(created);

    RouteDto byCreator =
        previewService.createRoute(created.getPublicId().toString(), team1Slug, routeRequest());
    context.setUserForTest(user2);
    RouteDto byOther =
        previewService.createRoute(created.getPublicId().toString(), team1Slug, routeRequest());

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
  }

  @Test
  void aPromotion_ofAPendingPreview_waitsForTheCatchUpOfTheRoute() {
    GpxPreview created = previewService.create(EXAMPLE, "example.gpx");

    RouteDto route =
        previewService.createRoute(created.getPublicId().toString(), team1Slug, routeRequest());

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
