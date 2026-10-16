package fr.pedalons.service.gps.sync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.gps.response.GpsServiceConnectionDto;
import fr.pedalons.dto.gps.response.RouteUploadResponse;
import fr.pedalons.enums.GpsAutoSyncState;
import fr.pedalons.enums.GpsRouteSyncState;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.gps.GpsCallResult;
import fr.pedalons.infrastructure.gps.HammerheadClient;
import fr.pedalons.infrastructure.gps.RouteMeta;
import fr.pedalons.infrastructure.security.TokenEncryptionService;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import fr.pedalons.service.gps.GpsRouteGpx;
import fr.pedalons.service.gps.GpsService;
import fr.pedalons.service.gps.sync.GpsRouteSyncService.RouteSyncStatus;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.user.AccountErasureService;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The route sync seen from the rest of the backend (docs/LEDGER_*.md API-120): manual uploads
 * through the tracking rows, the profile state, the per-route state, the switch, the clean-up at
 * disconnection and at account erasure.
 */
@QuarkusTest
class GpsRouteSyncServiceTest extends AbstractResourceTest {

  @Inject GpsService gpsService;
  @Inject GpsRouteSyncService syncService;
  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsRouteSyncWorker worker;
  @Inject GpsSyncTestData sync;
  @Inject TokenEncryptionService encryptionService;
  @Inject GpsServiceConnectionRepository connectionRepository;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject DomainResolver domainResolver;
  @Inject EntityManager em;
  @Inject AccountErasureService erasureService;

  @InjectMock HammerheadClient hammerhead;
  @InjectMock GpsRouteGpx routeGpx;

  private Ride ride;
  private Route route;
  private RideGroup group;
  private GpsServiceConnection connection;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    dataService.createDomainGpsCredential(
        domain, GpsServiceType.HAMMERHEAD, "client", encryptionService.encrypt("secret"));
    ride =
        dataService.createRide(
            team1, user1, "Sortie", "sortie", Instant.now().plus(2, ChronoUnit.DAYS));
    route = sync.routeWithGpx(ride, user1, "Boucle");
    dataService.setRideRoute(ride, route);
    group = dataService.createRideGroup(user1, ride, "Groupe A", 0);
    connection = sync.connect(user1, GpsServiceType.HAMMERHEAD, false);
    pedalonsContext.setUserForTest(user1);

    when(routeGpx.read(any())).thenReturn("<gpx/>".getBytes());
    when(hammerhead.createRoute(any(), any(), any())).thenReturn(new GpsCallResult.Ok("ext-1"));
    when(hammerhead.updateRoute(any(), anyString(), any(), any()))
        .thenAnswer(i -> new GpsCallResult.Ok(i.getArgument(1)));
    when(hammerhead.deleteRoute(any(), anyString()))
        .thenAnswer(i -> new GpsCallResult.Ok(i.getArgument(1)));
  }

  private RouteUploadResponse upload() {
    return gpsService.uploadRoute(GpsServiceType.HAMMERHEAD, team1Slug, route.getSlug());
  }

  // ------------------------------------------------------------------ manual uploads

  @Test
  void manualUpload_isRecorded() {
    RouteUploadResponse response = upload();

    assertTrue(response.success());
    assertEquals("ext-1", response.externalRouteId());
    List<GpsRouteSync> rows = sync.rows(connection.getId());
    assertEquals(1, rows.size());
    GpsRouteSync row = rows.getFirst();
    assertFalse(row.isAutomatic());
    assertEquals(route.getId(), row.getDesiredRouteId());
    assertEquals("ext-1", row.getExternalRouteId());
    assertEquals(row.getDesiredHash(), row.getSyncedHash());
  }

  @Test
  void secondManualUpload_updatesTheSameRouteInsteadOfACopy() {
    upload();
    RouteUploadResponse second = upload();

    assertTrue(second.success());
    assertEquals("ext-1", second.externalRouteId());
    verify(hammerhead, times(1)).createRoute(any(), any(), any());
    verify(hammerhead).updateRoute(any(), eq("ext-1"), any(), any());
    assertEquals(1, sync.rows(connection.getId()).size());
  }

  @Test
  void manualUpload_deletedAtTheService_isCreatedAgain() {
    upload();
    when(hammerhead.updateRoute(any(), anyString(), any(), any()))
        .thenReturn(new GpsCallResult.NotFound());
    when(hammerhead.createRoute(any(), any(), any())).thenReturn(new GpsCallResult.Ok("ext-2"));

    RouteUploadResponse second = upload();

    assertEquals("ext-2", second.externalRouteId());
    assertEquals("ext-2", sync.rows(connection.getId()).getFirst().getExternalRouteId());
  }

  @Test
  void manualUpload_isNeverManagedWhileTheSyncIsOff() {
    dataService.createParticipation(group, user1);
    upload();

    planner.plan(Instant.now());
    worker.processDue();

    // The switch is off: no automatic row, the manual upload neither updated nor deleted.
    List<GpsRouteSync> rows = sync.rows(connection.getId());
    assertEquals(1, rows.size());
    assertFalse(rows.getFirst().isAutomatic());
    verify(hammerhead, never()).deleteRoute(any(), anyString());
  }

  @Test
  void manualUpload_ofARouteTheSyncHolds_updatesTheSyncedRoute() {
    sync.setAutoSync(connection.getId(), true);
    dataService.createParticipation(group, user1);
    planner.plan(Instant.now());
    worker.processDue();

    RouteUploadResponse response = upload();

    assertTrue(response.success());
    assertEquals("ext-1", response.externalRouteId());
    verify(hammerhead, times(1)).createRoute(any(), any(), any());
    verify(hammerhead).updateRoute(any(), eq("ext-1"), any(), any());
    List<GpsRouteSync> rows = sync.rows(connection.getId());
    assertEquals(1, rows.size());
    assertTrue(rows.getFirst().isAutomatic());
  }

  @Test
  void syncTurnedOn_takesOverTheManualUpload() {
    upload();
    sync.setAutoSync(connection.getId(), true);
    dataService.createParticipation(group, user1);

    planner.plan(Instant.now());
    worker.processDue();

    // Updated under the manual upload's id (renamed for the ride), not created a second time.
    verify(hammerhead, times(1)).createRoute(any(), any(), any());
    verify(hammerhead)
        .updateRoute(
            any(),
            eq("ext-1"),
            any(),
            org.mockito.ArgumentMatchers.<RouteMeta>argThat(
                meta -> meta.name().contains("Groupe A")));
    List<GpsRouteSync> rows = sync.rows(connection.getId());
    assertEquals(1, rows.size());
    assertTrue(rows.getFirst().isAutomatic());
    assertEquals("ext-1", rows.getFirst().getExternalRouteId());
  }

  /**
   * The take-over is written before the service is called: a first update that fails leaves the
   * manual upload's id on the automatic row, and the retry updates that route — never a copy.
   */
  @Test
  void takeOver_whoseFirstUpdateFails_keepsTheManualUploadsId() {
    upload();
    sync.setAutoSync(connection.getId(), true);
    dataService.createParticipation(group, user1);
    when(hammerhead.updateRoute(any(), anyString(), any(), any()))
        .thenReturn(new GpsCallResult.Failed(503, "HTTP 503"))
        .thenAnswer(i -> new GpsCallResult.Ok(i.getArgument(1)));

    planner.plan(Instant.now());
    worker.processDue();

    List<GpsRouteSync> rows = sync.rows(connection.getId());
    assertEquals(1, rows.size());
    GpsRouteSync row = rows.getFirst();
    assertTrue(row.isAutomatic());
    assertEquals("ext-1", row.getExternalRouteId());
    assertEquals(1, row.getAttempts());

    sync.setAttempts(row.getId(), 1, null);
    worker.processDue();

    verify(hammerhead, times(1)).createRoute(any(), any(), any());
    verify(hammerhead, times(2)).updateRoute(any(), eq("ext-1"), any(), any());
    assertEquals(row.getDesiredHash(), sync.rows(connection.getId()).getFirst().getSyncedHash());
  }

  /** Turning the sync back on makes the rows that ran out of attempts due again. */
  @Test
  void syncTurnedBackOn_forgetsTheFailures() {
    sync.setAutoSync(connection.getId(), true);
    dataService.createParticipation(group, user1);
    when(hammerhead.createRoute(any(), any(), any()))
        .thenReturn(new GpsCallResult.Failed(500, "HTTP 500"));
    planner.plan(Instant.now());
    worker.processDue();
    GpsRouteSync row = sync.rows(connection.getId()).getFirst();
    sync.setAttempts(row.getId(), GpsRouteSyncExecutor.MAX_ATTEMPTS, null);
    sync.setAutoSync(connection.getId(), false);

    gpsService.setAutoSync(GpsServiceType.HAMMERHEAD, true);

    GpsRouteSync after = sync.rows(connection.getId()).getFirst();
    assertEquals(0, after.getAttempts());
    assertNull(after.getNextAttemptAt());
    assertNull(after.getLastError());
  }

  // ------------------------------------------------------------------ state

  @Test
  void routeStatuses_tellManualFromAutomatic() {
    Route other = sync.routeWithGpx(ride, user1, "Autre");
    upload();

    Map<Long, List<RouteSyncStatus>> statuses =
        syncService.findRouteStatuses(
            domain.getId(), user1.getId(), List.of(route.getId(), other.getId()));

    assertEquals(1, statuses.size());
    RouteSyncStatus status = statuses.get(route.getId()).getFirst();
    assertEquals(GpsServiceType.HAMMERHEAD, status.serviceType());
    assertFalse(status.automatic());
    assertEquals(GpsRouteSyncState.SENT, status.state());
    assertEquals("ext-1", status.externalRouteId());
  }

  @Test
  void setAutoSync_turnsItOnAndReportsTheState() {
    GpsServiceConnectionDto dto = gpsService.setAutoSync(GpsServiceType.HAMMERHEAD, true);

    assertTrue(dto.autoSync());
    assertEquals(GpsAutoSyncState.UP_TO_DATE, dto.autoSyncState());
    assertEquals(0, dto.autoSyncRouteCount());

    dataService.createParticipation(group, user1);
    planner.plan(Instant.now());
    assertEquals(
        GpsAutoSyncState.PENDING, gpsService.getConnectionsForUser().getFirst().autoSyncState());

    worker.processDue();
    GpsServiceConnectionDto after = gpsService.getConnectionsForUser().getFirst();
    assertEquals(GpsAutoSyncState.UP_TO_DATE, after.autoSyncState());
    assertEquals(1, after.autoSyncRouteCount());
    assertTrue(after.lastAutoSyncAt() != null);

    assertEquals(
        GpsAutoSyncState.OFF,
        gpsService.setAutoSync(GpsServiceType.HAMMERHEAD, false).autoSyncState());
  }

  @Test
  void failingAndReconnectRequired_areReported() {
    sync.setAutoSync(connection.getId(), true);
    dataService.createParticipation(group, user1);
    when(hammerhead.createRoute(any(), any(), any()))
        .thenReturn(new GpsCallResult.Failed(500, "HTTP 500"));
    planner.plan(Instant.now());
    worker.processDue();
    assertEquals(
        GpsAutoSyncState.FAILING, gpsService.getConnectionsForUser().getFirst().autoSyncState());

    sync.markReconnectRequired(connection.getId());
    // The test's request-scoped persistence context still holds the connection read above; a
    // request reads it afresh, and the bulk update does not reach the loaded copy.
    em.clear();
    assertEquals(
        GpsAutoSyncState.RECONNECT_REQUIRED,
        gpsService.getConnectionsForUser().getFirst().autoSyncState());
  }

  // ------------------------------------------------------------------ clean-up

  @Test
  void disconnect_removesTheSyncedRoutesThenTheRowsAndTheConnection() {
    sync.setAutoSync(connection.getId(), true);
    dataService.createParticipation(group, user1);
    planner.plan(Instant.now());
    worker.processDue();
    Route other = sync.routeWithGpx(ride, user1, "Manuelle");
    when(hammerhead.createRoute(any(), any(), any()))
        .thenReturn(new GpsCallResult.Ok("ext-manual"));
    gpsService.uploadRoute(GpsServiceType.HAMMERHEAD, team1Slug, other.getSlug());

    gpsService.disconnect(GpsServiceType.HAMMERHEAD);

    // The automatic route is removed; the manual upload stays at the service, as it always did.
    verify(hammerhead, times(1)).deleteRoute(any(), anyString());
    verify(hammerhead).deleteRoute(any(), eq("ext-1"));
    assertEquals(0, sync.countRows());
    assertTrue(
        connectionRepository
            .findByUserAndService(user1.getId(), GpsServiceType.HAMMERHEAD)
            .isEmpty());
  }

  @Test
  void disconnect_succeedsWhenTheServiceFails() {
    sync.setAutoSync(connection.getId(), true);
    dataService.createParticipation(group, user1);
    planner.plan(Instant.now());
    worker.processDue();
    when(hammerhead.deleteRoute(any(), anyString()))
        .thenReturn(new GpsCallResult.Failed(503, "HTTP 503"));

    gpsService.disconnect(GpsServiceType.HAMMERHEAD);

    assertEquals(0, sync.countRows());
    assertTrue(
        connectionRepository
            .findByUserAndService(user1.getId(), GpsServiceType.HAMMERHEAD)
            .isEmpty());
  }

  @Test
  void theSwitchAlone_doesNotLiftAReconnection() {
    sync.markReconnectRequired(connection.getId());

    gpsService.setAutoSync(GpsServiceType.HAMMERHEAD, true);
    assertTrue(
        sync.connection(connection.getId()).getSyncReconnectRequiredAt() != null,
        "the switch alone does not lift it");
  }

  @Test
  void accountErasure_removesTheSyncedRoutesAndTheRows() {
    sync.setAutoSync(connection.getId(), true);
    dataService.createParticipation(group, user1);
    planner.plan(Instant.now());
    worker.processDue();

    // As the erasure scheduler runs it: the clean-up first, with no transaction open, then the
    // erasure in its own.
    erasureService.removeSyncedRoutes(user1.getId());
    erasureService.eraseById(user1.getId());

    verify(hammerhead).deleteRoute(any(), eq("ext-1"));
    assertEquals(0, sync.countRows());
    assertNull(sync.connection(connection.getId()));
  }
}
