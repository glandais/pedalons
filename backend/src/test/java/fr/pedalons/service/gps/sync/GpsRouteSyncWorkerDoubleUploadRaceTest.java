package fr.pedalons.service.gps.sync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.gps.GpsCallResult;
import fr.pedalons.infrastructure.gps.HammerheadClient;
import fr.pedalons.infrastructure.security.TokenEncryptionService;
import fr.pedalons.service.gps.GpsRouteGpx;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Two workers on the same row — the two backends of a rolling deploy, each running its tick — make
 * one creation, not two (docs/LEDGER_*.md API-120 §4.2). Hammerhead and Garmin deduplicate
 * nothing: a second creation would be a second route on the member's device. Driven as {@code
 * FeedbackGithubWorkerDoublePublishRaceTest}: instance A blocks inside the call, instance B runs a
 * whole tick meanwhile, then A is released.
 */
@QuarkusTest
class GpsRouteSyncWorkerDoubleUploadRaceTest extends AbstractResourceTest {

  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsRouteSyncWorker worker;
  @Inject GpsSyncTestData sync;
  @Inject TokenEncryptionService encryptionService;

  @InjectMock HammerheadClient hammerhead;
  @InjectMock GpsRouteGpx routeGpx;

  private ExecutorService executor;
  private CountDownLatch firstCallEntered;
  private CountDownLatch releaseFirstCall;
  private AtomicInteger calls;
  private Ride ride;
  private GpsServiceConnection connection;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    executor = Executors.newFixedThreadPool(2);
    firstCallEntered = new CountDownLatch(1);
    releaseFirstCall = new CountDownLatch(1);
    calls = new AtomicInteger();
    dataService.createDomainGpsCredential(
        domain, GpsServiceType.HAMMERHEAD, "client", encryptionService.encrypt("secret"));
    ride =
        dataService.createRide(
            team1, user1, "Sortie", "sortie", Instant.now().plus(1, ChronoUnit.DAYS));
    Route route = sync.routeWithGpx(ride, user1, "Boucle");
    dataService.setRideRoute(ride, route);
    RideGroup group = dataService.createRideGroup(user1, ride, "Groupe", 0);
    dataService.createParticipation(group, user3);
    connection = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);

    when(routeGpx.read(any())).thenReturn("<gpx/>".getBytes());
    when(hammerhead.createRoute(any(), any(), any()))
        .thenAnswer(
            i -> {
              int n = calls.incrementAndGet();
              if (n == 1) {
                firstCallEntered.countDown();
                releaseFirstCall.await(30, TimeUnit.SECONDS);
              }
              return new GpsCallResult.Ok("ext-" + n);
            });
  }

  @AfterEach
  void tearDown() {
    releaseFirstCall.countDown();
    executor.shutdownNow();
  }

  @Test
  void twoWorkers_createTheRouteOnce() throws Exception {
    planner.plan(Instant.now());

    Future<?> instanceA = executor.submit(() -> worker.processDue());
    assertTrue(firstCallEntered.await(30, TimeUnit.SECONDS), "instance A never called");
    Future<?> instanceB = executor.submit(() -> worker.processDue());
    instanceB.get(30, TimeUnit.SECONDS);
    releaseFirstCall.countDown();
    instanceA.get(30, TimeUnit.SECONDS);

    assertEquals(1, calls.get());
    assertEquals(
        "ext-1", sync.row(connection.getId(), ride.getId()).orElseThrow().getExternalRouteId());
  }
}
