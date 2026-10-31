package fr.pedalons.service.surface;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.route.SurfaceRefresh;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.valhalla.TraceAttributesClient;
import fr.pedalons.infrastructure.valhalla.TraceAttributesRequest;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.SurfaceRefreshRepository;
import fr.pedalons.service.elevation.ElevationRefreshWorker;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.route.planner.PlannerStateFixtures;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import java.awt.image.BufferedImage;
import java.io.File;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import javax.imageio.ImageIO;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * docs/LEDGER_*.md WEB-100 (C1b): a saved route queues a surface request in its own transaction,
 * the worker computes it with the (faked) provider and stores the document, and the detail serves
 * it. No test reaches Stadia Maps.
 */
@QuarkusTest
class SurfaceRefreshTest extends AbstractResourceTest {

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();

  @InjectMock MapThumbnailRenderer renderer;
  @InjectMock @RestClient TraceAttributesClient client;

  @Inject RouteService routeService;
  @Inject SurfaceRefreshService service;
  @Inject SurfaceRefreshWorker worker;
  @Inject SurfaceRefreshRepository refreshRepository;
  @Inject GpxTrackRepository trackRepository;
  @Inject ElevationRefreshWorker elevationWorker;
  @Inject ElevationRefreshRepository elevationRefreshRepository;
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
    when(client.traceAttributes(any()))
        .thenAnswer(inv -> TraceFixtures.answer(inv.getArgument(0), i -> "paved"));
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

  private RouteDto createDrawn(PlannerState state) {
    queryContext.setUserForTest(user1);
    return routeService.createRoute(team1Slug, request("Tracé", state), null);
  }

  private RouteDto updateRoute(RouteDto route, String name, Path gpx) {
    queryContext.setUserForTest(user1);
    return routeService.updateRoute(team1Slug, route.slug(), request(name, null), gpx);
  }

  private static Long id(RouteDto route) {
    return TsidUtils.toLong(route.id());
  }

  private SurfaceRefresh refresh(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> refreshRepository.findByRouteId(id(route)).orElse(null));
  }

  private long refreshCount() {
    return QuarkusTransaction.requiringNew().call(() -> refreshRepository.count());
  }

  private void makeDue(RouteDto route) {
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                refreshRepository.update(
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

  private static WebApplicationException error(int status, int code) {
    return new WebApplicationException(
        Response.status(status).entity("{\"error_code\":" + code + "}").build());
  }

  // ------------------------------------------------------------------ request

  @Test
  void aSavedRoute_isQueuedInItsTransaction_andPending() {
    Instant before = Instant.now();
    RouteDto route = createRoute();

    SurfaceRefresh request = refresh(route);
    assertNotNull(request);
    assertEquals(1, refreshCount());
    assertEquals(0, request.getAttempts());
    long originalFileId =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    routeService.findBySlug(team1, route.slug()).getAssets().stream()
                        .filter(a -> a.getType() == fr.pedalons.enums.AssetType.ROUTE_ORIGINAL_GPX)
                        .findFirst()
                        .orElseThrow()
                        .getFileId());
    assertEquals(originalFileId, request.getSourceRevision());
    assertTrue(request.getDueAt().isAfter(before.plus(Duration.ofSeconds(80))));
    assertTrue(request.getDueAt().isBefore(before.plus(Duration.ofSeconds(120))));

    detail(route)
        .body("tracks[0].surfaceState", equalTo("PENDING"))
        .body("tracks[0].surfaces", nullValue());
    verify(client, never()).traceAttributes(any());
  }

  @Test
  void withTheSwitchOff_nothingIsQueued_andNothingIsSent() {
    RouteDto route = createRoute();
    service.setEnabledForTest(false);
    makeDue(route);

    assertEquals(0, worker.processDue());
    verify(client, never()).traceAttributes(any());
    assertEquals(1, refreshCount(), "the queue waits");

    RouteDto other = createRoute();
    assertNull(refresh(other));
    detail(other).body("tracks[0].surfaceState", nullValue());
  }

  @Test
  void aRename_makesNoRequest_andTheSurfaceStays() {
    RouteDto route = createRoute();
    makeDue(route);
    assertEquals(1, worker.processDue());
    assertEquals(0, refreshCount());

    updateRoute(route, "Renommé", null);

    assertEquals(0, refreshCount());
    assertNotNull(document(route));
  }

  @Test
  void aNewTrack_dropsTheSurfaceOfTheOldOne_andAsksAgainUnderItsRevision() {
    RouteDto route = createRoute();
    makeDue(route);
    assertEquals(1, worker.processDue());
    assertNotNull(document(route));

    updateRoute(route, "Boucle", EXAMPLE);

    assertNull(document(route), "the old surface left with the old track");
    SurfaceRefresh request = refresh(route);
    assertNotNull(request);
    long originalFileId =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    routeService.findBySlug(team1, route.slug()).getAssets().stream()
                        .filter(a -> a.getType() == fr.pedalons.enums.AssetType.ROUTE_ORIGINAL_GPX)
                        .findFirst()
                        .orElseThrow()
                        .getFileId());
    assertEquals(originalFileId, request.getSourceRevision());
    detail(route).body("tracks[0].surfaceState", equalTo("PENDING"));
  }

  // ------------------------------------------------------------------ worker

  @Test
  void theWorker_writesTheDocument_removesTheRequest_andTheDetailIsReady() {
    RouteDto route = createRoute();
    makeDue(route);

    assertEquals(1, worker.processDue());

    assertEquals(0, refreshCount());
    TrackSurfaceDocument doc = document(route);
    assertNotNull(doc);
    assertTrue(doc.ok());
    assertEquals("bicycle", doc.costing());
    var response =
        detail(route)
            .body("tracks[0].surfaceState", equalTo("READY"))
            .body("tracks[0].surfaces[0].from", equalTo(0.0f))
            .body("tracks[0].surfaces[0].surface", equalTo("PAVED"))
            .body("tracks[0].surfaces.size()", equalTo(1));
    assertEquals(doc.distance(), number(response, "tracks[0].surfaces[0].to"), 0.2);
  }

  @Test
  void theCostingFollowsTheProfileOfTheState_andAFileIsCycled() {
    ArgumentCaptor<TraceAttributesRequest> captor =
        ArgumentCaptor.forClass(TraceAttributesRequest.class);
    Object[][] cases = {
      {RouterProfile.BIKE, "bicycle"},
      {RouterProfile.FASTBIKE, "bicycle"},
      {RouterProfile.GRAVEL, "bicycle"},
      {RouterProfile.MTB, "bicycle"},
      {RouterProfile.RUN_HIKE, "pedestrian"},
      {RouterProfile.MOTORCYCLE, "auto"},
    };
    int calls = 0;
    for (Object[] c : cases) {
      RouteDto route =
          createDrawn(
              PlannerStateFixtures.withProfile(PlannerStateFixtures.drawn(), (RouterProfile) c[0]));
      makeDue(route);
      worker.processDue();
      calls++;
      verify(client, times(calls)).traceAttributes(captor.capture());
      assertEquals(c[1], captor.getValue().costing(), String.valueOf(c[0]));
      assertEquals(c[1], document(route).costing());
      assertEquals("map_snap", captor.getValue().shapeMatch());
    }
    RouteDto file = createRoute();
    makeDue(file);
    worker.processDue();
    verify(client, times(calls + 1)).traceAttributes(captor.capture());
    assertEquals("bicycle", captor.getValue().costing());
  }

  @Test
  void aStraightPiece_isOffNetwork_atTheRightDistance() {
    PlannerState state =
        new PlannerState(
            1,
            RouterProfile.BIKE,
            java.util.List.of(),
            java.util.List.of(
                PlannerStateFixtures.control(4.8300, 45.7600),
                PlannerStateFixtures.control(4.8340, 45.7620),
                PlannerStateFixtures.control(4.8400, 45.7650)),
            java.util.List.of(
                PlannerStateFixtures.routed(new double[][] {{4.8320, 45.7610}}),
                PlannerStateFixtures.direct()));
    RouteDto route = createDrawn(state);
    makeDue(route);

    worker.processDue();

    TrackSurfaceDocument doc = document(route);
    var off = doc.surfaces().stream().filter(r -> r.code().equals("off_network")).toList();
    assertEquals(1, off.size());
    assertEquals(doc.distance(), off.getFirst().to(), 1.0);
    // c1 is at about 40 % of the line
    double ratio = off.getFirst().from() / doc.distance();
    assertTrue(ratio > 0.25 && ratio < 0.6, "ratio " + ratio);
    assertEquals("off_network", doc.ways().getLast().use());
    detail(route).body("tracks[0].surfaces[-1].surface", equalTo("OFF_NETWORK"));
  }

  @Test
  void aTrackSavedAgainBeforeTheWrite_isNotWritten_andTheRequestIsRealigned() {
    RouteDto route = createRoute();
    makeDue(route);
    boolean[] replaced = {false};
    doAnswer(
            inv -> {
              if (!replaced[0]) {
                replaced[0] = true;
                updateRoute(route, "Boucle", EXAMPLE);
              }
              return TraceFixtures.answer(inv.getArgument(0), i -> "gravel");
            })
        .when(client)
        .traceAttributes(any());
    long before = refresh(route).getSourceRevision();

    assertEquals(1, worker.processDue());

    assertNull(document(route), "nothing of the old track written on the new one");
    SurfaceRefresh request = refresh(route);
    assertNotNull(request);
    assertNotEquals(before, request.getSourceRevision());
    assertEquals(0, request.getAttempts());
  }

  @Test
  void aRateLimit_failsTheAttempt_withABackoff_andFiveFailuresGiveUp() {
    doThrow(error(429, -1)).when(client).traceAttributes(any());
    RouteDto route = createRoute();
    makeDue(route);
    Instant before = Instant.now();

    assertEquals(1, worker.processDue());

    SurfaceRefresh request = refresh(route);
    assertEquals(1, request.getAttempts());
    assertTrue(request.getDueAt().isAfter(before.plus(Duration.ofSeconds(110))));
    assertTrue(request.getDueAt().isBefore(before.plus(Duration.ofSeconds(130))));
    assertTrue(request.getLastError().contains("429"));
    assertNull(document(route));
    detail(route).body("tracks[0].surfaceState", equalTo("PENDING"));

    for (int i = 0; i < 4; i++) {
      makeDue(route);
      assertEquals(1, worker.processDue());
    }
    assertEquals(5, refresh(route).getAttempts());
    makeDue(route);
    assertEquals(0, worker.processDue(), "given up: not claimed again");
    assertEquals(1, refreshCount(), "and left in the table");
    detail(route)
        .body("tracks[0].surfaceState", nullValue())
        .body("tracks[0].surfaces", nullValue());
    verify(client, times(5)).traceAttributes(any());
  }

  @Test
  void aTrackTheProviderCannotMatch_isUnavailable_forGood() {
    doThrow(error(400, 444)).when(client).traceAttributes(any());
    RouteDto route = createRoute();
    makeDue(route);

    assertEquals(1, worker.processDue());

    assertEquals(0, refreshCount());
    assertEquals("unavailable", document(route).status());
    detail(route)
        .body("tracks[0].surfaceState", equalTo("UNAVAILABLE"))
        .body("tracks[0].surfaces", nullValue());
    assertEquals(0, worker.processDue());
    verify(client, times(1)).traceAttributes(any());
  }

  @Test
  void theHdCatchUp_keepsTheDocument_andTheSpansFollowTheNewLength() {
    RouteDto route = createRoute();
    makeDue(route);
    worker.processDue();
    TrackSurfaceDocument before = document(route);

    QuarkusTransaction.requiringNew()
        .run(
            () ->
                elevationRefreshRepository.update(
                    "dueAt = ?1 where route.id = ?2", Instant.now().minusSeconds(1), id(route)));
    assertEquals(1, elevationWorker.processDue());

    assertEquals(before, document(route));
    double length =
        QuarkusTransaction.requiringNew()
            .call(() -> trackRepository.findPoints(id(route)).getFirst().points().getLast().dist());
    assertEquals(length, number(detail(route), "tracks[0].surfaces[-1].to"), 0.2);
  }

  // ------------------------------------------------------------------ raw line (API-147, B)

  private int sentPoints() {
    ArgumentCaptor<TraceAttributesRequest> captor =
        ArgumentCaptor.forClass(TraceAttributesRequest.class);
    verify(client, atLeastOnce()).traceAttributes(captor.capture());
    return fr.pedalons.infrastructure.valhalla.Polyline6Decoder.decode(
            captor.getValue().encodedPolyline())
        .size();
  }

  private int storedPoints(RouteDto route) {
    return QuarkusTransaction.requiringNew()
        .call(() -> trackRepository.findPoints(id(route)).getFirst().points().size());
  }

  @Test
  void theRawLine_isSentThinned_andTheDocumentStaysOnTheStoredPoints() {
    RouteDto route = createRoute();
    makeDue(route);
    java.util.List<double[]> raw =
        QuarkusTransaction.requiringNew()
            .call(() -> trackRepository.findRawLines(id(route)).values().iterator().next());

    assertEquals(1, worker.processDue());

    assertEquals(
        TraceSurfaceComputer.decimate(raw, TraceSurfaceComputer.MIN_SPACING_M).size(),
        sentPoints());
    assertNotEquals(storedPoints(route), sentPoints());
    TrackSurfaceDocument doc = document(route);
    double length =
        QuarkusTransaction.requiringNew()
            .call(() -> trackRepository.findPoints(id(route)).getFirst().points().getLast().dist());
    assertEquals(length, doc.distance(), 0);
    assertEquals(length, doc.surfaces().getLast().to(), 0.1);
  }

  @Test
  void withoutARawLine_theStoredPointsAreSent() {
    RouteDto route = createRoute();
    makeDue(route);
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                trackRepository
                    .getEntityManager()
                    .createNativeQuery(
                        "update gpx_tracks set raw_geometry = null where route_id = :id")
                    .setParameter("id", id(route))
                    .executeUpdate());

    assertEquals(1, worker.processDue());

    assertEquals(storedPoints(route), sentPoints());
    assertTrue(document(route).ok());
  }

  @Test
  void theWorker_treatsTheRequestsOfEveryDomain_withNoRequestDomain() {
    RouteDto first = createRoute();
    fr.pedalons.domain.platform.Domain other =
        dataService.createDomain("other.example.org", "Other", "https://other.example.org");
    domainResolver.setDomainForTest(other);
    fr.pedalons.domain.user.User otherUser =
        dataService.createUser(other, "o@example.org", "Other");
    fr.pedalons.domain.team.Team otherTeam =
        dataService.createTeam(otherUser, "Other team", "other-team", Visibility.PUBLIC);
    dataService.setTeamEnableRoutePlanner(otherTeam, true);
    queryContext.setUserForTest(otherUser);
    RouteDto second = routeService.createRoute("other-team", request("Autre", null), EXAMPLE);
    makeDue(first);
    makeDue(second);
    domainResolver.setDomainForTest(null);

    assertEquals(2, worker.processDue());

    assertEquals(0, refreshCount());
    verify(client, atLeastOnce()).traceAttributes(any());
    assertNotNull(document(first));
    assertNotNull(document(second));
  }
}
