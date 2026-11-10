package fr.pedalons.service.ride;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.ride.RideParticipationRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code RideService.switchGroup} (docs/LEDGER_*.md API-164) under the lock of {@code joinGroup},
 * driven as {@link RideJoinTwoGroupsRaceTest}: one thread holds its transaction open after its own
 * write, the other runs meanwhile; with the ride locked first, the second waits and then sees the
 * first one's row.
 *
 * <ul>
 *   <li>A switch and a join racing for the last seat of a group: one gets it, never both — and the
 *       one refused, if it is the switch, is still in its first group.
 *   <li>Two switches of the same person to two groups: one registration at the end, never two.
 * </ul>
 */
@QuarkusTest
class RideSwitchGroupRaceTest extends AbstractBaseTest {

  @Inject RideService rideService;
  @Inject RideParticipationRepository participationRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  private Domain domain;
  private Team team;
  private User admin;
  private User switcher;
  private User joiner;
  private ExecutorService executor;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    switcher = dataService.createUser("switcher@example.com", "Switcher");
    joiner = dataService.createUser("joiner@example.com", "Joiner");
    dataService.addUserToTeam(switcher, team, TeamRole.MEMBER);
    dataService.addUserToTeam(joiner, team, TeamRole.MEMBER);
    executor = Executors.newFixedThreadPool(2);
  }

  @AfterEach
  void tearDown() {
    executor.shutdownNow();
  }

  private Ride ride() {
    return dataService.createRide(
        team, admin, "Sunday", "sunday", Instant.now().plus(1, ChronoUnit.DAYS), Status.PUBLISHED);
  }

  @Test
  void aSwitchAndAJoinForTheLastSeat_shouldFillItOnce() throws Exception {
    Ride ride = ride();
    RideGroup origin = dataService.createRideGroup(admin, ride, "A", 0);
    RideGroup lastSeat = dataService.createRideGroupWithMaxParticipants(admin, ride, "B", 1);
    dataService.createParticipation(origin, switcher);

    CountDownLatch aWroteUncommitted = new CountDownLatch(1);
    CountDownLatch bDone = new CountDownLatch(1);
    AtomicReference<Throwable> bFailure = new AtomicReference<>();

    // Thread A: the switcher moves to B and holds its transaction open until the join has run.
    Future<?> a =
        executor.submit(() ->
            inRequest(
                switcher,
                () ->
                    QuarkusTransaction.requiringNew()
                        .run(() -> {
                          rideService.switchGroup(team.getSlug(), "sunday", lastSeat.getId());
                          aWroteUncommitted.countDown();
                          try {
                            bDone.await(3, TimeUnit.SECONDS);
                          } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                          }
                        })));

    // Thread B: someone else joins B while the switch is still uncommitted.
    Future<?> b =
        executor.submit(() -> {
          try {
            assertTrue(aWroteUncommitted.await(30, TimeUnit.SECONDS));
            inRequest(
                joiner,
                () -> {
                  try {
                    rideService.joinGroup(team.getSlug(), "sunday", lastSeat.getId());
                  } catch (PedalonsException expected) {
                    // GROUP_FULL: the switch took the seat first.
                    bFailure.set(expected);
                  }
                });
          } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
          } finally {
            bDone.countDown();
          }
        });

    a.get(60, TimeUnit.SECONDS);
    b.get(60, TimeUnit.SECONDS);

    assertEquals(1, countIn(lastSeat), "the last seat is taken once");
    assertNotNull(bFailure.get(), "the join that came second is refused");
    assertTrue(bFailure.get().getMessage().contains("GROUP_FULL"));
    assertEquals(0, countIn(origin), "the switcher left their first group");
    assertEquals(1, countOnRide(switcher, ride));
  }

  @Test
  void twoSwitchesOfOnePerson_shouldLeaveOneRegistration() throws Exception {
    Ride ride = ride();
    RideGroup origin = dataService.createRideGroup(admin, ride, "A", 0);
    RideGroup second = dataService.createRideGroup(admin, ride, "B", 1);
    RideGroup third = dataService.createRideGroup(admin, ride, "C", 2);
    dataService.createParticipation(origin, switcher);

    CountDownLatch aWroteUncommitted = new CountDownLatch(1);
    CountDownLatch bDone = new CountDownLatch(1);
    AtomicReference<Throwable> bFailure = new AtomicReference<>();

    Future<?> a =
        executor.submit(() ->
            inRequest(
                switcher,
                () ->
                    QuarkusTransaction.requiringNew()
                        .run(() -> {
                          rideService.switchGroup(team.getSlug(), "sunday", second.getId());
                          aWroteUncommitted.countDown();
                          try {
                            bDone.await(3, TimeUnit.SECONDS);
                          } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                          }
                        })));

    Future<?> b =
        executor.submit(() -> {
          try {
            assertTrue(aWroteUncommitted.await(30, TimeUnit.SECONDS));
            inRequest(
                switcher,
                () -> {
                  try {
                    rideService.switchGroup(team.getSlug(), "sunday", third.getId());
                  } catch (RuntimeException unexpected) {
                    bFailure.set(unexpected);
                  }
                });
          } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
          } finally {
            bDone.countDown();
          }
        });

    a.get(60, TimeUnit.SECONDS);
    b.get(60, TimeUnit.SECONDS);

    assertNull(bFailure.get(), "the second switch waits for the first, then moves on from it");
    assertEquals(1, countOnRide(switcher, ride), "one registration on the ride, never two");
    assertEquals(1, countIn(third), "the last switch wins");
  }

  private long countIn(RideGroup group) {
    return QuarkusTransaction.requiringNew()
        .call(() -> participationRepository.count("rideGroup.id = ?1", group.getId()));
  }

  private long countOnRide(User user, Ride ride) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            participationRepository.count(
                "user.id = ?1 and rideGroup.ride.id = ?2", user.getId(), ride.getId()));
  }

  /** Runs the action in a fresh request context, as {@code user}, on the default domain. */
  private void inRequest(User user, Runnable action) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      queryContext.setUserForTest(user);
      action.run();
    } finally {
      requestContext.terminate();
    }
  }
}
