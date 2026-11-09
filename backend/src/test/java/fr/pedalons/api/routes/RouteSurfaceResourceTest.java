package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.surface.SurfaceRefreshService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.io.File;
import java.nio.file.Path;
import java.time.Instant;
import java.util.List;
import org.hibernate.Hibernate;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** docs/LEDGER_*.md WEB-100 (C1b): what the route detail says of the surface of its tracks. */
@QuarkusTest
class RouteSurfaceResourceTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();

  @Inject RouteService routeService;
  @Inject GpxTrackRepository trackRepository;
  @Inject RouteRepository routeRepository;
  @Inject ElevationRefreshRepository elevationRefreshRepository;
  @Inject SurfaceRefreshService surfaceService;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;
  @Inject EntityManager em;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    surfaceService.setEnabledForTest(false);
  }

  @AfterEach
  void restoreSwitch() {
    surfaceService.setEnabledForTest(false);
  }

  // ------------------------------------------------------------------ helpers

  private RouteDto createRoute() {
    queryContext.setUserForTest(user1);
    return routeService.createRoute(
        team1Slug,
        new RouteRequest(
            "Boucle",
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null),
        EXAMPLE);
  }

  private Long trackId(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> trackRepository.findIdsByRouteIds(List.of(TsidUtils.toLong(route.id()))))
        .get(TsidUtils.toLong(route.id()))
        .getFirst();
  }

  private double length(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            trackRepository
                .findPoints(TsidUtils.toLong(route.id()))
                .getFirst()
                .points()
                .getLast()
                .dist());
  }

  /** The HD catch-up given up after its five attempts, with its row kept for diagnosis. */
  private void giveUpCatchUp(RouteDto route) {
    Long id = TsidUtils.toLong(route.id());
    QuarkusTransaction.requiringNew()
        .run(() -> {
          elevationRefreshRepository.update("attempts = 5 where route.id = ?1", id);
          routeRepository.update("elevationState = ?1 where id = ?2", ElevationState.FAST, id);
        });
  }

  private void store(RouteDto route, TrackSurfaceDocument doc) {
    QuarkusTransaction.requiringNew()
        .run(() -> trackRepository.updateSurfaces(trackId(route), doc));
  }

  private TrackSurfaceDocument ok(double distance, List<SurfaceRange> ranges) {
    return new TrackSurfaceDocument(
        1, "ok", null, null, Instant.now(), "bicycle", distance, ranges, List.of());
  }

  private ValidatableResponse detail(RouteDto route) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + route.slug())
        .then()
        .statusCode(200);
  }

  // ------------------------------------------------------------------ tests

  @Test
  void aTrackNeverComputed_saysNothing() {
    RouteDto route = createRoute();
    detail(route)
        .body("tracks[0].surfaceState", nullValue())
        .body("tracks[0].surfaces", nullValue());
  }

  @Test
  void aReadySurface_isServedByClass_mergedAndBounded() {
    RouteDto route = createRoute();
    double length = length(route);
    store(
        route,
        ok(
            length,
            List.of(
                new SurfaceRange(0, length * 0.25, "paved_smooth"),
                new SurfaceRange(length * 0.25, length * 0.5, "paved"),
                new SurfaceRange(length * 0.5, length * 0.75, "fine_gravel"),
                new SurfaceRange(length * 0.75, length, "path"))));

    detail(route)
        .body("tracks[0].surfaceState", equalTo("READY"))
        .body("tracks[0].surfaces", hasSize(3))
        .body("tracks[0].surfaces[0].from", equalTo(0.0f))
        .body("tracks[0].surfaces[0].surface", equalTo("PAVED"))
        .body("tracks[0].surfaces[1].surface", equalTo("GRAVEL"))
        .body("tracks[0].surfaces[2].surface", equalTo("PATH"));
    ValidatableResponse body = detail(route);
    assertEquals(
        length * 0.5,
        ((Number) body.extract().path("tracks[0].surfaces[0].to")).doubleValue(),
        0.1);
    assertEquals(
        length, ((Number) body.extract().path("tracks[0].surfaces[2].to")).doubleValue(), 0.1);
  }

  @Test
  void anUnavailableSurface_isSaidWithoutSpans() {
    RouteDto route = createRoute();
    store(
        route,
        TrackSurfaceDocument.unavailable("valhalla-444", length(route), "bicycle", Instant.now()));
    detail(route)
        .body("tracks[0].surfaceState", equalTo("UNAVAILABLE"))
        .body("tracks[0].surfaces", nullValue());
  }

  @Test
  void aDocumentWithFieldsOfALaterRelease_isStillRead() {
    RouteDto route = createRoute();
    double length = length(route);
    store(route, ok(length, List.of(new SurfaceRange(0, length, "dirt"))));
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery(
                    "update gpx_tracks set surfaces = jsonb_set(jsonb_set(surfaces, '{future}',"
                        + " '{\"a\":1}'), '{surfaces,0,3}', '\"extra\"') where id = :id")
                .setParameter("id", trackId(route))
                .executeUpdate());

    detail(route)
        .body("tracks[0].surfaceState", equalTo("READY"))
        .body("tracks[0].surfaces[0].surface", equalTo("DIRT"));
  }

  // ------------------------------------------------------------------ pending (API-150)

  @Test
  void aTrackAwaitingItsHdCatchUp_isPending_inTheDetailAndTheBulk() {
    RouteDto route = createRoute();
    surfaceService.setEnabledForTest(true);

    detail(route)
        .body("elevationState", equalTo("PENDING"))
        .body("tracks[0].surfaceState", equalTo("PENDING"))
        .body("tracks[0].surfaces", nullValue());
    bulk(route, true)
        .body("routes[0].tracks[0].surfaceState", equalTo("PENDING"))
        .body("routes[0].tracks[0].surfaces", nullValue());
  }

  @Test
  void anAbandonedCatchUp_saysNothing() {
    RouteDto route = createRoute();
    surfaceService.setEnabledForTest(true);
    giveUpCatchUp(route);

    detail(route)
        .body("elevationState", equalTo("FAST"))
        .body("tracks[0].surfaceState", nullValue())
        .body("tracks[0].surfaces", nullValue());
    bulk(route, true).body("routes[0].tracks[0].surfaceState", nullValue());
  }

  @Test
  void withTheSwitchOff_aPendingCatchUpSaysNothing_andADocumentIsStillServed() {
    RouteDto route = createRoute();

    detail(route)
        .body("elevationState", equalTo("PENDING"))
        .body("tracks[0].surfaceState", nullValue());
    bulk(route, true).body("routes[0].tracks[0].surfaceState", nullValue());

    double length = length(route);
    store(route, ok(length, List.of(new SurfaceRange(0, length, "gravel"))));
    detail(route).body("tracks[0].surfaceState", equalTo("READY"));
  }

  @Test
  void aDocument_winsOverAPendingCatchUp() {
    RouteDto route = createRoute();
    double length = length(route);
    store(route, ok(length, List.of(new SurfaceRange(0, length, "gravel"))));
    surfaceService.setEnabledForTest(true);

    detail(route)
        .body("elevationState", equalTo("PENDING"))
        .body("tracks[0].surfaceState", equalTo("READY"))
        .body("tracks[0].surfaces[0].surface", equalTo("GRAVEL"));
  }

  // ------------------------------------------------------------------ versions of the document

  /** Stored as the previous release wrote it: the raw JSON, four elements to a way. */
  private void storeVersion1(RouteDto route, double length) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery(
                    "update gpx_tracks set surfaces = cast(:json as jsonb) where id = :id")
                .setParameter(
                    "json",
                    ("{\"version\":1,\"status\":\"ok\",\"reason\":null,\"osmChangeset\":123,"
                            + "\"computedAt\":\"2026-10-20T08:00:00Z\",\"costing\":\"pedestrian\","
                            + "\"distance\":%1$s,"
                            + "\"surfaces\":[[0,%2$s,\"paved_smooth\"],[%2$s,%1$s,\"compacted\"]],"
                            + "\"ways\":[[0,%1$s,\"road\",\"none\"]]}")
                        .formatted(length, length / 2))
                .setParameter("id", trackId(route))
                .executeUpdate());
  }

  @Test
  void aVersion1Document_isStillServed_byClass() {
    RouteDto route = createRoute();
    double length = length(route);
    storeVersion1(route, length);

    detail(route)
        .body("tracks[0].surfaceState", equalTo("READY"))
        .body("tracks[0].surfaces", hasSize(2))
        .body("tracks[0].surfaces[0].surface", equalTo("PAVED"))
        .body("tracks[0].surfaces[1].surface", equalTo("GRAVEL"));
    bulk(route, true)
        .body("routes[0].tracks[0].surfaceState", equalTo("READY"))
        .body("routes[0].tracks[0].surfaces[1].surface", equalTo("GRAVEL"));
  }

  @Test
  void aVersion2Document_isServedLikeAnyOther() {
    RouteDto route = createRoute();
    double length = length(route);
    store(
        route,
        new TrackSurfaceDocument(
            TrackSurfaceDocument.VERSION_ROUTE_DETAILS,
            "ok",
            null,
            null,
            Instant.now(),
            "bicycle",
            length,
            List.of(
                new SurfaceRange(0, length * 0.25, "paved"),
                new SurfaceRange(length * 0.25, length * 0.5, "paved_rough"),
                new SurfaceRange(length * 0.5, length * 0.75, "gravel"),
                new SurfaceRange(length * 0.75, length, "off_network")),
            List.of(
                new WayRange(
                    0, length * 0.25, "minor_road", null, "ground", true, "paved", "asphalt"),
                new WayRange(length * 0.25, length, "track", null, null, null, "unpaved", null))));

    detail(route)
        .body("tracks[0].surfaceState", equalTo("READY"))
        .body("tracks[0].surfaces", hasSize(4))
        .body("tracks[0].surfaces[0].surface", equalTo("PAVED"))
        .body("tracks[0].surfaces[1].surface", equalTo("PAVED_ROUGH"))
        .body("tracks[0].surfaces[2].surface", equalTo("GRAVEL"))
        .body("tracks[0].surfaces[3].surface", equalTo("OFF_NETWORK"));
  }

  @Test
  void aVersion2UnavailableDocument_isSaidWithoutSpans() {
    RouteDto route = createRoute();
    store(
        route,
        TrackSurfaceDocument.unavailable(
            TrackSurfaceDocument.VERSION_ROUTE_DETAILS,
            "no-typology",
            length(route),
            "bicycle",
            Instant.now()));

    detail(route)
        .body("tracks[0].surfaceState", equalTo("UNAVAILABLE"))
        .body("tracks[0].surfaces", nullValue());
  }

  private ValidatableResponse bulk(RouteDto route, boolean geometry) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("slug", route.slug())
        .queryParam("geometry", geometry)
        .when()
        .get("/api/teams/" + team1Slug + "/routes/bulk")
        .then()
        .statusCode(200);
  }

  @Test
  void theBulkEndpoint_carriesTheSurface_whenTracksAreDrawn() {
    RouteDto route = createRoute();
    double length = length(route);
    store(route, ok(length, List.of(new SurfaceRange(0, length, "paved"))));

    bulk(route, true)
        .body("routes[0].tracks", hasSize(1))
        .body("routes[0].tracks[0].surfaceState", equalTo("READY"))
        .body("routes[0].tracks[0].surfaces", hasSize(1))
        .body("routes[0].tracks[0].surfaces[0].surface", equalTo("PAVED"));
  }

  @Test
  void theBulkEndpoint_withoutGeometry_carriesNoSurface() {
    RouteDto route = createRoute();
    double length = length(route);
    store(route, ok(length, List.of(new SurfaceRange(0, length, "paved"))));

    bulk(route, false).body("routes[0].tracks", hasSize(0));
  }

  @Test
  void theBulkEndpoint_saysNothing_ofATrackNeverComputed() {
    RouteDto route = createRoute();

    bulk(route, true)
        .body("routes[0].tracks[0].surfaceState", nullValue())
        .body("routes[0].tracks[0].surfaces", nullValue());
  }

  @Test
  void theSurfaceColumn_isLazy_inAGroupOfItsOwn() {
    RouteDto route = createRoute();
    double length = length(route);
    store(route, ok(length, List.of(new SurfaceRange(0, length, "paved"))));
    Long trackId = trackId(route);
    QuarkusTransaction.requiringNew()
        .run(() -> {
          GpxTrack track = em.find(GpxTrack.class, trackId);
          assertFalse(Hibernate.isPropertyInitialized(track, "surfaces"));
          // Reading the planner state (several MB) must not read the surface, nor the other way
          track.getPlannerState();
          assertFalse(Hibernate.isPropertyInitialized(track, "surfaces"));
        });
    QuarkusTransaction.requiringNew()
        .run(() -> {
          GpxTrack track = em.find(GpxTrack.class, trackId);
          assertNotNull(track.getSurfaces());
          assertTrue(Hibernate.isPropertyInitialized(track, "surfaces"));
          assertFalse(Hibernate.isPropertyInitialized(track, "plannerState"));
        });
  }
}
