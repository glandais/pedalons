package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
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
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.ElevationRefresh;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.admin.ElevationRefreshKind;
import fr.pedalons.dto.admin.ElevationRefreshRetryRequest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.elevation.ElevationRefreshService;
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
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-131: the platform admin restarts the HD recomputations the worker gave up on
 * (attempts used up, target FAST), in one domain, spread over time.
 */
@QuarkusTest
class AdminElevationRefreshResourceTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();
  private static final String URL = "/api/admin/elevation-refresh/retry";

  @InjectMock MapThumbnailRenderer renderer;

  @Inject RouteService routeService;
  @Inject ElevationRefreshService service;
  @Inject ElevationRefreshWorker worker;
  @Inject ElevationRefreshRepository refreshRepository;
  @Inject RouteRepository routeRepository;
  @Inject GpxPreviewRepository previewRepository;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  private User platformAdmin;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    platformAdmin = dataService.createPlatformAdminUser("admin@example.com", "Platform Admin");
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

  private String adminToken() {
    return jwtService.generateAccessToken(platformAdmin);
  }

  private io.restassured.response.ValidatableResponse retry(
      String query, boolean dryRun, Integer limit, ElevationRefreshKind kind) {
    return given()
        .auth()
        .oauth2(adminToken())
        .contentType("application/json")
        .body(new ElevationRefreshRetryRequest(dryRun, limit, kind))
        .when()
        .post(URL + query)
        .then()
        .statusCode(200);
  }

  // ------------------------------------------------------------------ fixtures

  /** A route with a request that used up its attempts, and the FAST state that goes with it. */
  private Route abandonedRoute(Team team, String name, Instant firstRequestedAt) {
    Route route = dataService.createRoute(team, user1, name);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              refreshRepository.requestForRoute(
                  route.getId(), 1L, Instant.now(), Duration.ofSeconds(90), Duration.ofMinutes(10));
              refreshRepository.update(
                  "attempts = ?1, lastError = 'boom', firstRequestedAt = ?2 where route.id = ?3",
                  ElevationRefreshService.MAX_ATTEMPTS,
                  firstRequestedAt,
                  route.getId());
              routeRepository.update(
                  "elevationState = ?1 where id = ?2", ElevationState.FAST, route.getId());
            });
    return route;
  }

  private GpxPreview abandonedPreview() {
    GpxPreview preview = dataService.createGpxPreview(domain, user1, UUID.randomUUID());
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              refreshRepository.requestForPreview(
                  preview.getId(),
                  1L,
                  Instant.now(),
                  Duration.ofSeconds(90),
                  Duration.ofMinutes(10));
              refreshRepository.update(
                  "attempts = ?1, lastError = 'boom' where preview.id = ?2",
                  ElevationRefreshService.MAX_ATTEMPTS,
                  preview.getId());
              previewRepository.update(
                  "elevationState = ?1 where id = ?2", ElevationState.FAST, preview.getId());
            });
    return preview;
  }

  private ElevationRefresh request(Route route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> refreshRepository.findByRouteId(route.getId()).orElse(null));
  }

  private ElevationState state(Route route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> routeRepository.findById(route.getId()).getElevationState());
  }

  // ------------------------------------------------------------------ tests

  @Test
  void retry_asNonAdmin_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new ElevationRefreshRetryRequest(true, null, null))
        .when()
        .post(URL)
        .then()
        .statusCode(403);
  }

  @Test
  void dryRun_listsTheAbandonedTargets_andChangesNothing() {
    Route route = abandonedRoute(team1, "Abandonnée", Instant.now().minusSeconds(3600));
    // Not abandoned: still has attempts left
    Route fresh = dataService.createRoute(team1, user1, "En cours");
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                refreshRepository.requestForRoute(
                    fresh.getId(),
                    1L,
                    Instant.now(),
                    Duration.ofSeconds(90),
                    Duration.ofMinutes(10)));
    String id = TsidUtils.toString(route.getId());

    retry("", true, null, null)
        .body("dryRun", equalTo(true))
        .body("matched", equalTo(1))
        .body("items", hasSize(1))
        .body("items[0].kind", equalTo("ROUTE"))
        .body("items[0].targetId", equalTo(id))
        .body("items[0].teamSlug", equalTo(team1.getSlug()))
        .body("items[0].routeSlug", equalTo(route.getSlug()))
        .body("items[0].attempts", equalTo(ElevationRefreshService.MAX_ATTEMPTS))
        .body("items[0].lastError", equalTo("boom"));

    ElevationRefresh after = request(route);
    assertEquals(ElevationRefreshService.MAX_ATTEMPTS, after.getAttempts());
    assertEquals("boom", after.getLastError());
    assertEquals(ElevationState.FAST, state(route));
  }

  @Test
  void retry_restartsTheRequest_reportsTheErrorItCleared_andIsIdempotent() {
    Route route = abandonedRoute(team1, "Abandonnée", Instant.now().minusSeconds(3600));
    Instant before = Instant.now();

    retry("", false, null, null)
        .body("dryRun", equalTo(false))
        .body("matched", equalTo(1))
        .body("items[0].lastError", equalTo("boom"))
        .body("items[0].attempts", equalTo(ElevationRefreshService.MAX_ATTEMPTS));

    ElevationRefresh after = request(route);
    assertNotNull(after, "abandoned rows are kept, not purged");
    assertEquals(0, after.getAttempts());
    assertNull(after.getLastError());
    assertNull(after.getClaimedUntil());
    assertTrue(!after.getFirstRequestedAt().isBefore(before.minusSeconds(5)), "a new window");
    assertEquals(ElevationState.PENDING, state(route));

    retry("", false, null, null).body("matched", equalTo(0)).body("items", empty());
    assertEquals(0, request(route).getAttempts());
  }

  @Test
  void retry_leavesAnHdTargetAlone_evenWithAnAbandonedRowBesideIt() {
    Route route = abandonedRoute(team1, "Déjà HD", Instant.now().minusSeconds(3600));
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                routeRepository.update(
                    "elevationState = ?1 where id = ?2", ElevationState.HD, route.getId()));

    retry("", false, null, null).body("matched", equalTo(0)).body("items", empty());

    assertEquals(ElevationRefreshService.MAX_ATTEMPTS, request(route).getAttempts());
    assertEquals(ElevationState.HD, state(route));
  }

  @Test
  void retry_onlyTouchesTheTargetDomain() {
    Route mine = abandonedRoute(team1, "Chez nous", Instant.now().minusSeconds(3600));
    Domain other =
        dataService.createDomain("other.example.org", "Other", "https://other.example.org");
    Team otherTeam = dataService.createTeam(other, user1, "Autre", "autre", Visibility.PUBLIC);
    Route theirs = abandonedRoute(otherTeam, "Chez eux", Instant.now().minusSeconds(3600));

    retry("", false, null, null)
        .body("matched", equalTo(1))
        .body("items[0].targetId", equalTo(TsidUtils.toString(mine.getId())));

    assertEquals(0, request(mine).getAttempts());
    assertEquals(ElevationRefreshService.MAX_ATTEMPTS, request(theirs).getAttempts());
    assertEquals(ElevationState.FAST, state(theirs));

    retry("?domainId=" + TsidUtils.toString(other.getId()), false, null, null)
        .body("matched", equalTo(1))
        .body("items[0].targetId", equalTo(TsidUtils.toString(theirs.getId())));
    assertEquals(0, request(theirs).getAttempts());
    assertEquals(ElevationState.PENDING, state(theirs));
  }

  @Test
  void retry_ignoresDeletedRoutes() {
    Route route = abandonedRoute(team1, "Supprimée", Instant.now().minusSeconds(3600));
    QuarkusTransaction.requiringNew()
        .run(() -> routeRepository.update("deleted = true where id = ?1", route.getId()));

    retry("", false, null, null).body("matched", equalTo(0)).body("items", empty());

    assertEquals(ElevationRefreshService.MAX_ATTEMPTS, request(route).getAttempts());
  }

  @Test
  void retry_spreadsTheDueTimes_oldestFirst() {
    Instant now = Instant.now();
    Route newest = abandonedRoute(team1, "C", now.minusSeconds(100));
    Route oldest = abandonedRoute(team1, "A", now.minusSeconds(300));
    Route middle = abandonedRoute(team1, "B", now.minusSeconds(200));

    retry("", false, null, null).body("matched", equalTo(3)).body("items", hasSize(3));

    Instant first = request(oldest).getDueAt();
    Instant second = request(middle).getDueAt();
    Instant third = request(newest).getDueAt();
    assertEquals(Duration.ofMinutes(1), Duration.between(first, second));
    assertEquals(Duration.ofMinutes(1), Duration.between(second, third));
    assertTrue(Duration.between(now, first).abs().toSeconds() < 60, "the first one is due now");
  }

  @Test
  void retry_withALimit_restartsTheOldestOnly() {
    Instant now = Instant.now();
    Route oldest = abandonedRoute(team1, "A", now.minusSeconds(300));
    Route middle = abandonedRoute(team1, "B", now.minusSeconds(200));
    Route newest = abandonedRoute(team1, "C", now.minusSeconds(100));

    retry("", false, 2, null)
        .body("matched", equalTo(3))
        .body("items", hasSize(2))
        .body("items[0].targetId", equalTo(TsidUtils.toString(oldest.getId())))
        .body("items[1].targetId", equalTo(TsidUtils.toString(middle.getId())));

    assertEquals(0, request(oldest).getAttempts());
    assertEquals(0, request(middle).getAttempts());
    assertEquals(ElevationRefreshService.MAX_ATTEMPTS, request(newest).getAttempts());
    assertEquals(ElevationState.FAST, state(newest));
  }

  @Test
  void retry_withAKind_leavesTheOtherKindAlone() {
    Route route = abandonedRoute(team1, "Route", Instant.now().minusSeconds(3600));
    GpxPreview preview = abandonedPreview();

    retry("", true, null, ElevationRefreshKind.PREVIEW)
        .body("matched", equalTo(1))
        .body("items[0].kind", equalTo("PREVIEW"))
        .body("items[0].previewPublicId", equalTo(preview.getPublicId().toString()));

    retry("", false, null, ElevationRefreshKind.PREVIEW).body("matched", equalTo(1));

    assertEquals(ElevationRefreshService.MAX_ATTEMPTS, request(route).getAttempts());
    assertEquals(ElevationState.FAST, state(route));
    assertEquals(
        ElevationState.PENDING,
        QuarkusTransaction.requiringNew()
            .call(() -> previewRepository.findById(preview.getId()).getElevationState()));
  }

  @Test
  void aRetriedRoute_isRecomputedByTheWorker_andBecomesHd() {
    queryContext.setUserForTest(user1);
    RouteDto created =
        routeService.createRoute(
            team1Slug,
            new RouteRequest(
                "Boucle",
                MediaDto.builder().markdown("Parcours").build(),
                SurfaceType.ROAD,
                Visibility.PUBLIC,
                null),
            EXAMPLE);
    Long id = TsidUtils.toLong(created.id());
    // The worker gave up on it
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              refreshRepository.update(
                  "attempts = ?1, lastError = 'boom' where route.id = ?2",
                  ElevationRefreshService.MAX_ATTEMPTS,
                  id);
              routeRepository.update("elevationState = ?1 where id = ?2", ElevationState.FAST, id);
            });
    assertEquals(0, worker.processDue(), "an abandoned request is not taken");

    retry("", false, null, null).body("matched", equalTo(1));

    QuarkusTransaction.requiringNew()
        .run(
            () ->
                refreshRepository.update(
                    "dueAt = ?1 where route.id = ?2", Instant.now().minusSeconds(1), id));
    assertEquals(1, worker.processDue());

    assertEquals(
        ElevationState.HD,
        QuarkusTransaction.requiringNew()
            .call(() -> routeRepository.findById(id).getElevationState()));
    assertEquals(
        0,
        (long)
            QuarkusTransaction.requiringNew()
                .call(() -> refreshRepository.count("route.id = ?1", id)));
  }
}
