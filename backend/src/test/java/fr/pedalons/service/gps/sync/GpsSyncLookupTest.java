package fr.pedalons.service.gps.sync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.dto.gps.response.RouteGpsSyncStatusDto;
import fr.pedalons.dto.gps.response.RouteGpsSyncStatuses;
import fr.pedalons.enums.GpsRouteSyncState;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code gpsSyncStatuses} as {@link GpsSyncLookup} resolves it (docs/LEDGER_*.md API-120): one entry
 * per service of the caller whose automatic sync is on and which holds the route, nothing for a
 * service without it, nothing at all — and no query — for a visitor.
 */
@QuarkusTest
class GpsSyncLookupTest extends AbstractResourceTest {

  @Inject GpsSyncLookup lookup;
  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsSyncTestData sync;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject DomainResolver domainResolver;

  private Instant now;
  private Ride ride;
  private Route route;
  private RideGroup group;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    // Within the planner's 7-day horizon.
    ride = dataService.createRide(team1, user1, "Sortie", "sortie", now.plus(2, ChronoUnit.DAYS));
    route = sync.routeWithGpx(ride, user1, "Boucle");
    dataService.setRideRoute(ride, route);
    group = dataService.createRideGroup(user1, ride, "Groupe A", 0);
    pedalonsContext.setUserForTest(user3);
  }

  private List<RouteGpsSyncStatusDto> statusesOf(Route r) {
    return lookup.forRoutes(List.of(r.getId())).forRoute(r.getId());
  }

  @Test
  void autoSyncedService_holdingTheRoute_givesOneEntry_pendingThenSent() {
    GpsServiceConnection connection = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    dataService.createParticipation(group, user3);
    planner.plan(now);

    List<RouteGpsSyncStatusDto> pending = statusesOf(route);
    assertEquals(1, pending.size());
    assertEquals(GpsServiceType.HAMMERHEAD, pending.getFirst().serviceType());
    assertEquals(GpsRouteSyncState.PENDING, pending.getFirst().state());
    assertNull(pending.getFirst().syncedAt());

    GpsRouteSync row = sync.row(connection.getId(), ride.getId()).orElseThrow();
    sync.markSynced(row.getId(), "ext-1");

    List<RouteGpsSyncStatusDto> sent = statusesOf(route);
    assertEquals(1, sent.size());
    assertEquals(GpsRouteSyncState.SENT, sent.getFirst().state());
    assertNotNull(sent.getFirst().syncedAt());
  }

  @Test
  void serviceWithoutAutoSync_withAManualUpload_givesNoEntry() {
    GpsServiceConnection connection = sync.connect(user3, GpsServiceType.HAMMERHEAD, false);
    sync.recordManualUpload(domain.getId(), connection, route, "ext-manual");

    assertTrue(statusesOf(route).isEmpty());
    assertSame(RouteGpsSyncStatuses.NONE, lookup.forRoutes(List.of(route.getId())));
  }

  @Test
  void autoSyncedService_withAManualUpload_givesAnEntry() {
    GpsServiceConnection connection = sync.connect(user3, GpsServiceType.GARMIN, true);
    sync.recordManualUpload(domain.getId(), connection, route, "ext-manual");

    List<RouteGpsSyncStatusDto> statuses = statusesOf(route);
    assertEquals(1, statuses.size());
    assertEquals(GpsServiceType.GARMIN, statuses.getFirst().serviceType());
  }

  @Test
  void twoServices_onlyTheAutoSyncedOne_givesAnEntry() {
    sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    GpsServiceConnection manual = sync.connect(user3, GpsServiceType.GARMIN, false);
    dataService.createParticipation(group, user3);
    planner.plan(now);
    sync.recordManualUpload(domain.getId(), manual, route, "ext-garmin");

    List<RouteGpsSyncStatusDto> statuses = statusesOf(route);
    assertEquals(1, statuses.size());
    assertEquals(GpsServiceType.HAMMERHEAD, statuses.getFirst().serviceType());
  }

  @Test
  void twoAutoSyncedServices_areSortedByService() {
    sync.connect(user3, GpsServiceType.WAHOO, true);
    sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    dataService.createParticipation(group, user3);
    planner.plan(now);

    List<RouteGpsSyncStatusDto> statuses = statusesOf(route);
    assertEquals(
        List.of(GpsServiceType.HAMMERHEAD, GpsServiceType.WAHOO),
        statuses.stream().map(RouteGpsSyncStatusDto::serviceType).toList());
  }

  @Test
  void anotherUsersRows_areNeverShown() {
    sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    dataService.createParticipation(group, user3);
    planner.plan(now);

    pedalonsContext.setUserForTest(user2);

    assertTrue(statusesOf(route).isEmpty());
  }

  @Test
  void anonymous_getsNothing_withoutAQuery() {
    sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    dataService.createParticipation(group, user3);
    planner.plan(now);
    pedalonsContext.setUserForTest(null);

    var result = new RouteGpsSyncStatuses[1];
    long statements =
        queryStats.measure(
            "GpsSyncLookup anonymous", () -> result[0] = lookup.forRoutes(List.of(route.getId())));

    assertSame(RouteGpsSyncStatuses.NONE, result[0]);
    assertEquals(0, statements);
  }

  @Test
  void noRoute_getsNothing_withoutAQuery() {
    var result = new RouteGpsSyncStatuses[1];
    long statements =
        queryStats.measure("GpsSyncLookup no route", () -> result[0] = lookup.forRoutes(List.of()));

    assertSame(RouteGpsSyncStatuses.NONE, result[0]);
    assertEquals(0, statements);
  }

  @Test
  void tripStageRoute_isReported() {
    sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    Trip trip = dataService.createTrip(team1, user1, "Voyage", now.plus(1, ChronoUnit.DAYS));
    TripStage stage =
        dataService.createTripStage(user1, trip, "Étape 1", 0, now.plus(1, ChronoUnit.DAYS));
    Route stageRoute = sync.routeWithGpx(team1, user1, "Col du Galibier");
    sync.setStageRoute(stage, stageRoute);
    dataService.createTripParticipation(trip, user3);
    planner.plan(now);

    List<RouteGpsSyncStatusDto> statuses = statusesOf(stageRoute);
    assertEquals(1, statuses.size());
    assertEquals(GpsServiceType.HAMMERHEAD, statuses.getFirst().serviceType());
    assertEquals(GpsRouteSyncState.PENDING, statuses.getFirst().state());
    // The ride's route is not held: user3 joined no ride.
    assertTrue(statusesOf(route).isEmpty());
  }
}
