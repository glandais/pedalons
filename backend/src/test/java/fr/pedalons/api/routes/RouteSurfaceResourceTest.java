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
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.route.GpxTrackRepository;
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
        .call(
            () ->
                trackRepository
                    .findPoints(TsidUtils.toLong(route.id()))
                    .getFirst()
                    .points()
                    .getLast()
                    .dist());
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
        .run(
            () ->
                em.createNativeQuery(
                        "update gpx_tracks set surfaces = jsonb_set(jsonb_set(surfaces, '{future}',"
                            + " '{\"a\":1}'), '{surfaces,0,3}', '\"extra\"') where id = :id")
                    .setParameter("id", trackId(route))
                    .executeUpdate());

    detail(route)
        .body("tracks[0].surfaceState", equalTo("READY"))
        .body("tracks[0].surfaces[0].surface", equalTo("DIRT"));
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
        .run(
            () -> {
              GpxTrack track = em.find(GpxTrack.class, trackId);
              assertFalse(Hibernate.isPropertyInitialized(track, "surfaces"));
              // Reading the planner state (several MB) must not read the surface, nor the other way
              track.getPlannerState();
              assertFalse(Hibernate.isPropertyInitialized(track, "surfaces"));
            });
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxTrack track = em.find(GpxTrack.class, trackId);
              assertNotNull(track.getSurfaces());
              assertTrue(Hibernate.isPropertyInitialized(track, "surfaces"));
              assertFalse(Hibernate.isPropertyInitialized(track, "plannerState"));
            });
  }
}
