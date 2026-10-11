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
 * Bug found by the TLA+ model of ride registration (check-then-insert in {@code
 * RideService.joinGroup}, model variant FIXED=FALSE): two concurrent joins by the same user on two
 * different groups of one ride both pass {@code findByUserAndRide} (neither sees the other's
 * uncommitted row), and the database only enforces unique (ride_group_id, user_id), so both commit
 * and the user ends up registered in two groups of the same ride.
 *
 * <p>The interleaving is driven explicitly: thread A runs {@code joinGroup(g1)} inside a
 * transaction it keeps open; thread B then runs {@code joinGroup(g2)} in its own transaction; A
 * commits only once B is done (or after a grace delay, so that a fix that makes B wait on a lock —
 * e.g. PESSIMISTIC_WRITE on the ride row — does not deadlock the test and B then sees A's row).
 */
@QuarkusTest
class RideJoinTwoGroupsRaceTest extends AbstractBaseTest {

  @Inject RideService rideService;
  @Inject RideParticipationRepository participationRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  private Domain domain;
  private Team team;
  private User admin;
  private User member;
  private ExecutorService executor;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    member = dataService.createUser("member@example.com", "Member");
    dataService.addUserToTeam(member, team, TeamRole.MEMBER);
    executor = Executors.newFixedThreadPool(2);
  }

  @AfterEach
  void tearDown() {
    executor.shutdownNow();
  }

  @Test
  void concurrentJoinsOfTwoGroups_leaveTheUserInOneGroupOnly() throws Exception {
    Ride ride =
        dataService.createRide(
            team,
            admin,
            "Sunday",
            "sunday",
            Instant.now().plus(1, ChronoUnit.DAYS),
            Status.PUBLISHED);
    RideGroup g1 = dataService.createRideGroup(admin, ride, "G1", 0);
    RideGroup g2 = dataService.createRideGroup(admin, ride, "G2", 1);

    CountDownLatch aJoinedUncommitted = new CountDownLatch(1);
    CountDownLatch bDone = new CountDownLatch(1);
    AtomicReference<Throwable> bFailure = new AtomicReference<>();

    // Thread A: joins g1 and holds its transaction open until B has run.
    Future<?> a =
        executor.submit(
            () ->
                inRequest(
                    () ->
                        QuarkusTransaction.requiringNew()
                            .run(
                                () -> {
                                  rideService.joinGroup(team.getSlug(), "sunday", g1.getId());
                                  aJoinedUncommitted.countDown();
                                  try {
                                    // Without a fix B finishes at once; with a lock B blocks, so
                                    // A commits after the grace delay and releases it.
                                    bDone.await(3, TimeUnit.SECONDS);
                                  } catch (InterruptedException e) {
                                    Thread.currentThread().interrupt();
                                  }
                                })));

    // Thread B: joins g2 while A's registration is still uncommitted.
    Future<?> b =
        executor.submit(
            () -> {
              try {
                assertTrue(aJoinedUncommitted.await(30, TimeUnit.SECONDS));
                inRequest(
                    () -> {
                      try {
                        rideService.joinGroup(team.getSlug(), "sunday", g2.getId());
                      } catch (PedalonsException expectedOnceFixed) {
                        // ALREADY_REGISTERED is the correct outcome for the second join.
                        bFailure.set(expectedOnceFixed);
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

    long registrations =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    participationRepository.count(
                        "user.id = ?1 and rideGroup.ride.id = ?2", member.getId(), ride.getId()));

    assertEquals(
        1, registrations, "the same user must not be registered in two groups of the same ride");
    assertNotNull(bFailure.get(), "the second concurrent join must be refused");
  }

  /** Runs the action in a fresh request context, as the member, on the default domain. */
  private void inRequest(Runnable action) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      queryContext.setUserForTest(member);
      action.run();
    } finally {
      requestContext.terminate();
    }
  }
}
