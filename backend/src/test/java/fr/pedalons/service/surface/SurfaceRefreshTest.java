package fr.pedalons.service.surface;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
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
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.elevation.ElevationRefreshWorker;
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
import java.time.Instant;
import java.util.List;
import java.util.Map;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md WEB-100 (C1b): what the API says of the surface of a route. Since docs/LEDGER_*.md
 * API-150 a track waits for its HD catch-up, which writes the surface. A version 1 document is
 * seeded ({@link #storeVersion1}): nothing writes one any more, but the routes that hold one stay
 * readable until they are recomputed.
 */
@QuarkusTest
class SurfaceRefreshTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();

  @InjectMock MapThumbnailRenderer renderer;

  @Inject RouteService routeService;
  @Inject SurfaceRefreshService service;
  @Inject GpxTrackRepository trackRepository;
  @Inject ElevationRefreshWorker elevationWorker;
  @Inject ElevationRefreshRepository elevationRefreshRepository;
  @Inject RouteRepository routeRepository;
  @Inject AssetRepository assetRepository;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    dataService.setTeamEnableRoutePlanner(team1, true);
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
    dataService.setDomainEnableGpxPlanner(domain, true);
    service.setEnabledForTest(true);
  }

  @AfterEach
  void restoreSwitch() {
    service.setEnabledForTest(false);
  }

  // ------------------------------------------------------------------ helpers

  private static RouteRequest request(String name, PlannerState state) {
    return new RouteRequest(
        name,
        MediaDto.builder().markdown("Parcours").build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null,
        null,
        state);
  }

  private RouteDto createRoute() {
    queryContext.setUserForTest(user1);
    return routeService.createRoute(team1Slug, request("Boucle", null), EXAMPLE);
  }

  private RouteDto updateRoute(RouteDto route, String name, Path gpx) {
    queryContext.setUserForTest(user1);
    return routeService.updateRoute(team1Slug, route.slug(), request(name, null), gpx);
  }

  private static Long id(RouteDto route) {
    return TsidUtils.toLong(route.id());
  }

  private long originalFileId(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> assetRepository.findCurrentFileId(id(route), AssetType.ROUTE_ORIGINAL_GPX));
  }

  /** The document a route keeps from the former queue, on the length of its stored points. */
  private void storeVersion1(RouteDto route) {
    double length = length(route);
    QuarkusTransaction.requiringNew()
        .run(() ->
            trackRepository.updateSurfaces(
                trackRepository.findIdsByRouteIds(List.of(id(route))).get(id(route)).getFirst(),
                new TrackSurfaceDocument(
                    TrackSurfaceDocument.VERSION,
                    TrackSurfaceDocument.STATUS_OK,
                    null,
                    123L,
                    Instant.parse("2026-10-20T08:00:00Z"),
                    "bicycle",
                    length,
                    List.of(new SurfaceRange(0, length, "paved")),
                    List.of(new WayRange(0, length, "road", "none")))));
  }

  private double length(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> trackRepository.findPoints(id(route)).getFirst().points().getLast().dist());
  }

  /** The HD catch-up over: no request, the state says nothing is to come. */
  private void catchUpDone(RouteDto route) {
    QuarkusTransaction.requiringNew()
        .run(() -> {
          elevationRefreshRepository.delete("route.id", id(route));
          routeRepository.update("elevationState = ?1 where id = ?2", ElevationState.HD, id(route));
        });
  }

  private void makeElevationDue(RouteDto route) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            elevationRefreshRepository.update(
                "dueAt = ?1 where route.id = ?2", Instant.now().minusSeconds(1), id(route)));
  }

  private TrackSurfaceDocument document(RouteDto route) {
    Map<Long, TrackSurfaceDocument> found =
        QuarkusTransaction.requiringNew().call(() -> trackRepository.findSurfaces(id(route)));
    return found.isEmpty() ? null : found.values().iterator().next();
  }

  private io.restassured.response.ValidatableResponse detail(RouteDto route) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + route.slug())
        .then()
        .statusCode(200);
  }

  private static double number(io.restassured.response.ValidatableResponse response, String path) {
    return ((Number) response.extract().path(path)).doubleValue();
  }

  private io.restassured.response.ValidatableResponse bulk(RouteDto route) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("slug", route.slug())
        .queryParam("geometry", true)
        .when()
        .get("/api/teams/" + team1Slug + "/routes/bulk")
        .then()
        .statusCode(200);
  }

  // ------------------------------------------------------------------ request

  @Test
  void aSavedRoute_queuesNoSurfaceRequest_andIsPendingOnItsHdCatchUp() {
    RouteDto route = createRoute();

    assertEquals(
        originalFileId(route),
        QuarkusTransaction.requiringNew()
            .call(() ->
                elevationRefreshRepository
                    .findByRouteId(id(route))
                    .orElseThrow()
                    .getSourceRevision()));

    detail(route)
        .body("tracks[0].surfaceState", equalTo("PENDING"))
        .body("tracks[0].surfaces", nullValue());
  }

  @Test
  void withTheSwitchOff_nothingIsPending() {
    service.setEnabledForTest(false);

    RouteDto route = createRoute();

    detail(route).body("tracks[0].surfaceState", nullValue());
  }

  @Test
  void aRename_makesNoRequest_andTheSurfaceStays() {
    RouteDto route = createRoute();
    storeVersion1(route);

    updateRoute(route, "Renommé", null);

    assertNotNull(document(route));
  }

  @Test
  void aNewTrack_dropsTheSurfaceOfTheOldOne_andWaitsForItsHdCatchUp() {
    RouteDto route = createRoute();
    storeVersion1(route);
    assertNotNull(document(route));

    updateRoute(route, "Boucle", EXAMPLE);

    assertNull(document(route), "the old surface left with the old track");
    assertEquals(
        originalFileId(route),
        QuarkusTransaction.requiringNew()
            .call(() ->
                elevationRefreshRepository
                    .findByRouteId(id(route))
                    .orElseThrow()
                    .getSourceRevision()));
    detail(route).body("tracks[0].surfaceState", equalTo("PENDING"));
  }

  // ------------------------------------------------------------------ a version 1 document

  @Test
  void aVersion1Document_isServed_andTheDetailIsReady() {
    RouteDto route = createRoute();
    storeVersion1(route);
    TrackSurfaceDocument doc = document(route);
    assertTrue(doc.ok());

    var response =
        detail(route)
            .body("tracks[0].surfaceState", equalTo("READY"))
            .body("tracks[0].surfaces[0].from", equalTo(0.0f))
            .body("tracks[0].surfaces[0].surface", equalTo("PAVED"))
            .body("tracks[0].surfaces.size()", equalTo(1));
    assertEquals(doc.distance(), number(response, "tracks[0].surfaces[0].to"), 0.2);
  }

  @Test
  void theHdCatchUp_replacesAVersion1Document_withTheOneOfItsAnswer() {
    RouteDto route = createRoute();
    storeVersion1(route);
    assertEquals(TrackSurfaceDocument.VERSION, document(route).version());

    makeElevationDue(route);
    assertEquals(1, elevationWorker.processDue());

    TrackSurfaceDocument after = document(route);
    assertEquals(TrackSurfaceDocument.VERSION_ROUTE_DETAILS, after.version());
    double length = length(route);
    assertEquals(length, after.distance(), 0.01);
    assertEquals(length, number(detail(route), "tracks[0].surfaces[-1].to"), 0.2);
  }

  @Test
  void withTheSwitchOff_theHdCatchUp_keepsTheDocument_andTheSpansFollowTheNewLength() {
    RouteDto route = createRoute();
    storeVersion1(route);
    TrackSurfaceDocument before = document(route);
    service.setEnabledForTest(false);

    makeElevationDue(route);
    assertEquals(1, elevationWorker.processDue());

    assertEquals(before, document(route));
    assertEquals(length(route), number(detail(route), "tracks[0].surfaces[-1].to"), 0.2);
  }

  /** Without a document once the HD catch-up is over, the API says nothing, in the list too. */
  @Test
  void aTrackWithoutADocument_afterItsHdCatchUp_readsAsNothing() {
    RouteDto route = createRoute();
    catchUpDone(route);

    detail(route)
        .body("tracks[0].surfaceState", nullValue())
        .body("tracks[0].surfaces", nullValue());
    bulk(route)
        .body("routes[0].tracks[0].surfaceState", nullValue())
        .body("routes[0].tracks[0].surfaces", nullValue());
    assertEquals(0, elevationWorker.processDue());
  }
}
