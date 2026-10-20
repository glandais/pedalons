package fr.pedalons.service.gps.sync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.InternalException;
import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ride.RideParticipation;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.request.WaypointRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.GpsSyncError;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WaypointType;
import fr.pedalons.infrastructure.gps.GpsAuth;
import fr.pedalons.infrastructure.gps.GpsCallResult;
import fr.pedalons.infrastructure.gps.GpsTokenRefusedException;
import fr.pedalons.infrastructure.gps.HammerheadClient;
import fr.pedalons.infrastructure.gps.RouteMeta;
import fr.pedalons.infrastructure.gps.TokenResponse;
import fr.pedalons.infrastructure.security.TokenEncryptionService;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.service.gps.GpsRouteGpx;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The worker's calls and what it writes back (docs/LEDGER_*.md API-120 §4.2-4.4), the service
 * mocked: create, update, delete, the 404s, the 401 and its refresh, the 412, the 429, the backoff.
 */
@QuarkusTest
class GpsRouteSyncWorkerTest extends AbstractResourceTest {

  private static final byte[] GPX = "<gpx/>".getBytes();

  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsRouteSyncWorker worker;
  @Inject GpsSyncTestData sync;
  @Inject TokenEncryptionService encryptionService;

  @Inject RouteService routeService;
  @Inject RouteRepository routeRepository;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  @InjectMock HammerheadClient hammerhead;
  @InjectMock GpsRouteGpx routeGpx;

  private Instant now;
  private Ride ride;
  private RideGroup group;
  private RideParticipation registration;
  private GpsServiceConnection connection;
  private Route route;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    now = Instant.now();
    dataService.createDomainGpsCredential(
        domain,
        GpsServiceType.HAMMERHEAD,
        "hammerhead-client",
        encryptionService.encrypt("hammerhead-secret"));
    ride = dataService.createRide(team1, user1, "Sortie", "sortie", now.plus(2, ChronoUnit.DAYS));
    route = sync.routeWithGpx(ride, user1, "Boucle");
    dataService.setRideRoute(ride, route);
    group = dataService.createRideGroup(user1, ride, "Groupe A", 0);
    registration = dataService.createParticipation(group, user3);
    connection = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);

    when(routeGpx.read(any())).thenReturn(GPX);
    when(hammerhead.createRoute(any(), any(), any())).thenReturn(new GpsCallResult.Ok("ext-1"));
    when(hammerhead.updateRoute(any(), anyString(), any(), any()))
        .thenAnswer(i -> new GpsCallResult.Ok(i.getArgument(1)));
    when(hammerhead.deleteRoute(any(), anyString()))
        .thenAnswer(i -> new GpsCallResult.Ok(i.getArgument(1)));
  }

  private GpsRouteSync row() {
    return sync.row(connection.getId(), ride.getId()).orElseThrow();
  }

  private void planAndProcess() {
    planner.plan(Instant.now());
    worker.processDue();
  }

  @Test
  void create_storesTheExternalIdAndTheHashSent() {
    planAndProcess();

    GpsRouteSync row = row();
    assertEquals("ext-1", row.getExternalRouteId());
    assertEquals(row.getDesiredHash(), row.getSyncedHash());
    assertNotNull(row.getSyncedAt());
    assertNull(row.getClaimedUntil());
    verify(hammerhead)
        .createRoute(
            argThat(
                auth ->
                    auth instanceof GpsAuth.Bearer b
                        && b.accessToken().equals(GpsSyncTestData.ACCESS_TOKEN)),
            eq(GPX),
            argThat((RouteMeta meta) -> meta.name().contains("Groupe A")));
  }

  @Test
  void upToDate_callsNothing() {
    planAndProcess();
    planAndProcess();

    verify(hammerhead, times(1)).createRoute(any(), any(), any());
    verify(hammerhead, never()).updateRoute(any(), anyString(), any(), any());
  }

  @Test
  void routeChange_updatesTheSameRouteAtTheService() {
    planAndProcess();
    Route other = sync.routeWithGpx(ride, user1, "Variante");
    sync.setGroupRoute(group, other);

    planAndProcess();

    verify(hammerhead).updateRoute(any(), eq("ext-1"), eq(GPX), any());
    GpsRouteSync row = row();
    assertEquals(other.getId(), row.getDesiredRouteId());
    assertEquals(row.getDesiredHash(), row.getSyncedHash());
  }

  // ------------------------------------------------------------------ waypoints (WEB-100, C3c)

  /** A real route made of a GPX with three waypoints, riding the ride. */
  private RouteDto realRouteWithWaypoints() {
    domainResolver.setDomainForTest(domain);
    queryContext.setUserForTest(user1);
    RouteDto created =
        routeService.createRoute(
            team1Slug,
            new RouteRequest(
                "Avec points",
                MediaDto.builder().markdown("Parcours").build(),
                SurfaceType.ROAD,
                Visibility.PUBLIC,
                null),
            Path.of("src/test/resources/waypoints.gpx"));
    Route entity =
        QuarkusTransaction.requiringNew()
            .call(() -> routeRepository.findById(TsidUtils.toLong(created.id())));
    dataService.setRideRoute(ride, entity);
    return created;
  }

  @Test
  void executor_sendsCoursePointsInMeta() {
    realRouteWithWaypoints();

    planAndProcess();

    verify(hammerhead)
        .createRoute(any(), any(), argThat((RouteMeta meta) -> meta.coursePoints().size() == 3));
  }

  @Test
  void pointsOnlyEdit_pushesTheRouteAgain() {
    RouteDto created = realRouteWithWaypoints();
    planAndProcess();
    verify(hammerhead, times(1)).createRoute(any(), any(), any());
    List<WaypointRequest> list =
        new ArrayList<>(
            QuarkusTransaction.requiringNew()
                .call(() -> routeService.getDto(team1Slug, created.slug()))
                .waypoints()
                .stream()
                .map(
                    w ->
                        new WaypointRequest(
                            w.id(),
                            new GeoPoint(
                                w.geometry().getPosition().getLon(),
                                w.geometry().getPosition().getLat()),
                            w.type(),
                            w.name(),
                            w.description(),
                            w.distance(),
                            null))
                .toList());
    list.add(
        new WaypointRequest(
            null,
            new GeoPoint(-1.5456685, 47.2024271),
            WaypointType.TOILETS,
            "Toilettes",
            null,
            null,
            null));

    queryContext.setUserForTest(user1);
    routeService.updateRoute(
        team1Slug,
        created.slug(),
        new RouteRequest(
            "Avec points",
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null,
            null,
            null,
            list),
        null);
    planAndProcess();

    verify(hammerhead)
        .updateRoute(
            any(),
            eq("ext-1"),
            any(),
            argThat((RouteMeta meta) -> meta.coursePoints().size() == 4));
  }

  @Test
  void update404_createsTheRouteAgain() {
    planAndProcess();
    // A corrected GPX: a new asset, a new hash, an update — which finds the route gone.
    sync.attachGpx(route, user1);
    when(hammerhead.updateRoute(any(), anyString(), any(), any()))
        .thenReturn(new GpsCallResult.NotFound());
    when(hammerhead.createRoute(any(), any(), any())).thenReturn(new GpsCallResult.Ok("ext-2"));

    planAndProcess();

    assertEquals("ext-2", row().getExternalRouteId());
    assertEquals(row().getDesiredHash(), row().getSyncedHash());
  }

  @Test
  void leaving_deletesTheRouteAndTheRow() {
    planAndProcess();
    dataService.deleteParticipation(registration);

    planAndProcess();

    verify(hammerhead).deleteRoute(any(), eq("ext-1"));
    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void delete404_isASuccess() {
    planAndProcess();
    when(hammerhead.deleteRoute(any(), anyString())).thenReturn(new GpsCallResult.NotFound());
    dataService.deleteParticipation(registration);

    planAndProcess();

    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void unauthorized_refreshesTheTokenOnceAndReplays() {
    when(hammerhead.createRoute(any(), any(), any()))
        .thenReturn(new GpsCallResult.Unauthorized())
        .thenReturn(new GpsCallResult.Ok("ext-1"));
    when(hammerhead.refreshToken(any(DomainGpsCredential.class), eq(GpsSyncTestData.REFRESH_TOKEN)))
        .thenReturn(new TokenResponse("fresh-token", "fresh-refresh", 3600L, null));

    planAndProcess();

    assertEquals("ext-1", row().getExternalRouteId());
    verify(hammerhead)
        .createRoute(
            argThat(
                auth -> auth instanceof GpsAuth.Bearer b && b.accessToken().equals("fresh-token")),
            any(),
            any());
    assertEquals(
        "fresh-token",
        encryptionService.decrypt(sync.connection(connection.getId()).getAccessTokenEncrypted()));
  }

  @Test
  void unauthorizedAfterTheRefresh_requiresAReconnection() {
    when(hammerhead.createRoute(any(), any(), any())).thenReturn(new GpsCallResult.Unauthorized());
    when(hammerhead.refreshToken(any(DomainGpsCredential.class), anyString()))
        .thenReturn(new TokenResponse("fresh-token", null, 3600L, null));

    planAndProcess();

    assertNotNull(sync.connection(connection.getId()).getSyncReconnectRequiredAt());
    GpsRouteSync row = row();
    assertEquals(GpsSyncError.UNAUTHORIZED, row.getLastError());
    assertEquals(0, row.getAttempts());
    assertNull(row.getClaimedUntil());

    // Nothing more for this connection until a reconnection.
    worker.processDue();
    verify(hammerhead, times(2)).createRoute(any(), any(), any());
  }

  @Test
  void expiredToken_isRefreshedAndStoredBeforeTheCall() {
    sync.expireToken(connection.getId());
    when(hammerhead.refreshToken(any(DomainGpsCredential.class), eq(GpsSyncTestData.REFRESH_TOKEN)))
        .thenReturn(new TokenResponse("fresh-token", "fresh-refresh", 3600L, null));
    when(hammerhead.createRoute(any(), any(), any()))
        .thenReturn(new GpsCallResult.Failed(500, "HTTP 500"));

    planAndProcess();

    // Stored in a transaction of its own: a failed call does not lose the rotated tokens.
    GpsServiceConnection stored = sync.connection(connection.getId());
    assertEquals("fresh-token", encryptionService.decrypt(stored.getAccessTokenEncrypted()));
    assertEquals("fresh-refresh", encryptionService.decrypt(stored.getRefreshTokenEncrypted()));
    assertEquals(1, row().getAttempts());
  }

  /** Access revoked at the service: the expired token's refresh is refused (400 invalid_grant). */
  @Test
  void expiredTokenWhoseRefreshIsRefused_requiresAReconnection() {
    sync.expireToken(connection.getId());
    when(hammerhead.refreshToken(any(DomainGpsCredential.class), anyString()))
        .thenThrow(new GpsTokenRefusedException("Hammerhead", 400));

    planAndProcess();

    assertNotNull(sync.connection(connection.getId()).getSyncReconnectRequiredAt());
    GpsRouteSync row = row();
    assertEquals(GpsSyncError.UNAUTHORIZED, row.getLastError());
    assertEquals(0, row.getAttempts());
    verify(hammerhead, never()).createRoute(any(), any(), any());
  }

  /** A network error or a 5xx on the token endpoint may pass: an attempt, retried later. */
  @Test
  void expiredTokenWhoseRefreshFails_isRetriedLater() {
    sync.expireToken(connection.getId());
    when(hammerhead.refreshToken(any(DomainGpsCredential.class), anyString()))
        .thenThrow(
            new InternalException(
                ErrorCode.GPS_TOKEN_EXCHANGE_FAILED, new java.io.IOException("timeout")));

    planAndProcess();

    assertNull(sync.connection(connection.getId()).getSyncReconnectRequiredAt());
    GpsRouteSync row = row();
    assertEquals(GpsSyncError.SERVICE_ERROR, row.getLastError());
    assertEquals(1, row.getAttempts());
  }

  @Test
  void permissionRevoked_requiresAReconnection() {
    when(hammerhead.createRoute(any(), any(), any()))
        .thenReturn(new GpsCallResult.PermissionRevoked());

    planAndProcess();

    assertNotNull(sync.connection(connection.getId()).getSyncReconnectRequiredAt());
    assertEquals(GpsSyncError.PERMISSION_REVOKED, row().getLastError());
  }

  @Test
  void rateLimited_pausesTheConnection() {
    Instant retryAt = Instant.now().plus(10, ChronoUnit.MINUTES);
    when(hammerhead.createRoute(any(), any(), any()))
        .thenReturn(new GpsCallResult.RateLimited(retryAt));

    planAndProcess();
    worker.processDue();

    Instant paused = sync.connection(connection.getId()).getSyncPausedUntil();
    assertNotNull(paused);
    assertTrue(Duration.between(retryAt, paused).abs().toSeconds() < 1);
    assertEquals(GpsSyncError.RATE_LIMITED, row().getLastError());
    assertEquals(0, row().getAttempts());
    verify(hammerhead, times(1)).createRoute(any(), any(), any());
  }

  @Test
  void failure_backsOff() {
    when(hammerhead.createRoute(any(), any(), any()))
        .thenReturn(new GpsCallResult.Failed(500, "HTTP 500"));

    planAndProcess();
    worker.processDue();

    GpsRouteSync row = row();
    assertEquals(1, row.getAttempts());
    assertEquals(GpsSyncError.SERVICE_ERROR, row.getLastError());
    assertNotNull(row.getNextAttemptAt());
    assertTrue(row.getNextAttemptAt().isAfter(Instant.now().plusSeconds(30)));
    verify(hammerhead, times(1)).createRoute(any(), any(), any());
  }

  @Test
  void afterMaxAttempts_waitsForANewDesiredState() {
    planner.plan(Instant.now());
    sync.setAttempts(row().getId(), GpsRouteSyncExecutor.MAX_ATTEMPTS, null);

    worker.processDue();
    verify(hammerhead, never()).createRoute(any(), any(), any());

    // A new desired state forgets the failures.
    sync.setGroupStartAt(group, now.plus(3, ChronoUnit.DAYS));
    planAndProcess();
    verify(hammerhead).createRoute(any(), any(), any());
  }

  @Test
  void routeChangedDuringTheCall_staysOutOfSync() {
    planner.plan(Instant.now());
    Long rowId = row().getId();
    AtomicReference<String> sentHash = new AtomicReference<>();
    when(hammerhead.createRoute(any(), any(), any()))
        .thenAnswer(
            i -> {
              sentHash.set(row().getDesiredHash());
              sync.setDesiredHash(rowId, "changed-meanwhile");
              return new GpsCallResult.Ok("ext-1");
            });

    worker.processDue();

    GpsRouteSync row = row();
    assertEquals(sentHash.get(), row.getSyncedHash());
    assertNotEquals(row.getDesiredHash(), row.getSyncedHash());
    assertEquals("ext-1", row.getExternalRouteId());
  }

  @Test
  void backoff_isCapped() {
    assertEquals(Duration.ofMinutes(1), GpsRouteSyncExecutor.backoff(1));
    assertEquals(Duration.ofMinutes(2), GpsRouteSyncExecutor.backoff(2));
    assertEquals(Duration.ofHours(6), GpsRouteSyncExecutor.backoff(30));
  }

  @Test
  void wahooExternalId_isStableForTheRide() {
    assertEquals(
        "pedalons-" + domain.getId() + "-" + ride.getId(),
        GpsSyncNames.wahooExternalId(domain.getId(), ride.getId()));
    assertFalse(
        GpsSyncNames.wahooExternalId(domain.getId(), ride.getId())
            .equals(GpsSyncNames.wahooExternalId(domain.getId(), group.getId())));
  }
}
