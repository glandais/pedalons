package fr.pedalons.service.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.notification.NotificationEventEntry;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.enums.NotificationEventStatus;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.notification.event.RideUpdated;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.NotificationTestData;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug found by the TLA+ model of the notification queue (RIDE_UPDATED coalescing vs. the
 * dispatcher's claim / fan-out): an edit whose {@code RideUpdated} folds into an event that the
 * dispatcher has already claimed is lost.
 *
 * <p>{@code claimNextPending} commits the event PROCESSING but keeps its dedup key; {@code fanOut}
 * reads the ride, snapshots its date, and only releases the key ({@code dedupKey#id}) when it
 * commits. An organiser's edit B landing in between has its {@code insertIfAbsent} ({@code ON
 * CONFLICT (dedup_key) DO NOTHING}) see the committed key and do nothing, while {@code fanOut}
 * announces the ride at its pre-B date. Once B commits nothing is pending: the riders keep "moved
 * to 10:00" while the ride is at 10:30.
 *
 * <p>The interleaving is driven explicitly: the event is claimed; thread B saves edit B (ride
 * date, then {@code publish(RideUpdated)} as {@code RideService.updateRide} does) and keeps its
 * transaction open; the main thread runs {@code fanOut} and commits; B then commits. Grace
 * timeouts keep a fix that adds a lock (B or the fan-out waiting on the other) from deadlocking
 * the test.
 */
@QuarkusTest
class RideUpdatedFoldIntoClaimedEventRaceTest extends AbstractResourceTest {

  @Inject NotificationDispatchService dispatchService;
  @Inject NotificationPublisher publisher;
  @Inject NotificationTestData notifications;
  @Inject RideRepository rideRepository;
  @Inject UserRepository userRepository;
  @Inject DomainResolver domainResolver;

  private ExecutorService executor;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    executor = Executors.newSingleThreadExecutor();
  }

  @AfterEach
  void tearDown() {
    executor.shutdownNow();
  }

  @Test
  void editFoldedIntoAClaimedEvent_isStillAnnounced() throws Exception {
    Instant t0 = Instant.now().plus(7, ChronoUnit.DAYS).truncatedTo(ChronoUnit.HOURS);
    Instant t1 = t0.plus(1, ChronoUnit.HOURS); // edit A: 9:00 -> 10:00
    Instant t2 = t1.plus(30, ChronoUnit.MINUTES); // edit B: 10:00 -> 10:30

    Ride created = dataService.createRide(team1, user1, "Sortie", "sortie", t0);
    RideGroup group = dataService.createRideGroup(user1, created, "G1");
    dataService.createParticipation(group, user3);
    long rideId = created.getId();

    // Edit A commits and queues K = RIDE_UPDATED:<ride>, prev = t0, after the coalescing delay.
    editRide(rideId, t0, t1);
    notifications.makeEventsDue();

    // The dispatcher claims K: PROCESSING, dedup key still held.
    Optional<Long> claimed = dispatchService.claimNextPending();
    assertTrue(claimed.isPresent(), "edit A's event is due and claimed");
    long eventId = claimed.get();

    CountDownLatch bPublished = new CountDownLatch(1);
    CountDownLatch fanOutDone = new CountDownLatch(1);

    // Edit B: moves the ride to t2 and publishes its RideUpdated, transaction kept open.
    Future<?> editB =
        executor.submit(
            () ->
                inRequest(
                    () ->
                        QuarkusTransaction.requiringNew()
                            .run(
                                () -> {
                                  applyEdit(rideId, t1, t2);
                                  bPublished.countDown();
                                  try {
                                    // Unfixed, the fan-out never waits on B; a fix that makes it
                                    // wait gets B's commit after the grace delay.
                                    fanOutDone.await(3, TimeUnit.SECONDS);
                                  } catch (InterruptedException e) {
                                    Thread.currentThread().interrupt();
                                  }
                                })));

    // A fix that makes B's insert wait on the dispatcher must not hang the test either.
    bPublished.await(3, TimeUnit.SECONDS);
    try {
      QuarkusTransaction.requiringNew()
          .call(
              () -> {
                dispatchService.fanOut(eventId);
                return null;
              });
    } finally {
      fanOutDone.countDown();
    }
    editB.get(60, TimeUnit.SECONDS);

    // Whatever is still queued is given its chance, delay skipped.
    notifications.makeEventsDue();
    while (dispatchService.dispatchOne()) {
      // drain
    }

    List<NotificationEventEntry> rideUpdates =
        notifications.eventEntries().stream()
            .filter(e -> e.getType() == NotificationType.RIDE_UPDATED)
            .toList();
    Optional<NotificationEventEntry> lastAnnounced =
        rideUpdates.stream()
            .filter(e -> e.getStatus() == NotificationEventStatus.DONE)
            .max(Comparator.comparing(NotificationEventEntry::getProcessedAt));

    assertTrue(lastAnnounced.isPresent(), "edit A at least was announced: " + rideUpdates);
    assertEquals(
        t2,
        lastAnnounced.get().getSubjectDateTime(),
        "the ride is at "
            + t2
            + " but the last RIDE_UPDATED told the riders "
            + lastAnnounced.get().getSubjectDateTime()
            + ", and nothing is queued to correct it (edit B folded into the claimed event"
            + " and was lost): "
            + rideUpdates.stream()
                .map(e -> e.getStatus() + " " + e.getDedupKey() + " " + e.getSubjectDateTime())
                .toList());
  }

  /** One committed edit, as {@code RideService.updateRide}. */
  private void editRide(long rideId, Instant from, Instant to) {
    QuarkusTransaction.requiringNew().run(() -> applyEdit(rideId, from, to));
  }

  /**
   * The part of {@code RideService.updateRide} that matters here: the managed ride moved (flushed
   * at commit), then the {@code RideUpdated} carrying the state before, with the coalescing delay.
   */
  private void applyEdit(long rideId, Instant from, Instant to) {
    Ride ride = rideRepository.findById(rideId);
    assertEquals(from, ride.getDateTime());
    ride.setDateTime(to);
    rideRepository.persist(ride);
    publisher.publish(
        new RideUpdated(rideId, from, null),
        ride.getTeam(),
        userRepository.findById(user1.getId()),
        Duration.ofMinutes(5));
  }

  /** Runs the action in a fresh request context, on the default domain. */
  private void inRequest(Runnable action) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      action.run();
    } finally {
      requestContext.terminate();
    }
  }
}
