package fr.pedalons.service.ride;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.ride.RideParticipationRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.UserTransaction;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug: concurrent joins by two different users can push a ride group past maxParticipants.
 *
 * <p>Found by the TLA+/TLC model of RideService.joinGroup (two join transactions under READ
 * COMMITTED, each reading the group without a lock, checking {@code RideGroup.hasCapacity()} on
 * the lazily loaded participations, then inserting): the invariant {@code Cardinality(group) <=
 * maxParticipants} is violated by the interleaving read(A) read(B) insert(A) insert(B) commit(A)
 * commit(B). Nothing serialises the two: the (ride_group_id, user_id) unique index does not fire
 * for distinct users and the ride_groups row is never written, so its version does not conflict.
 *
 * <p>The interleaving is driven explicitly: A's join runs inside an open transaction that stays
 * uncommitted while B joins in its own transaction. Today B neither blocks nor sees A's row, so
 * both commit and the group holds 2 of 1. Once the group (or ride) row is locked before the
 * capacity check, B waits for A's commit and then gets GROUP_FULL: the group holds 1.
 */
@QuarkusTest
class RideGroupCapacityRaceTest extends AbstractBaseTest {

  @Inject RideService rideService;
  @Inject RideParticipationRepository participationRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject DomainResolver domainResolver;
  @Inject UserTransaction userTransaction;

  private Domain domain;
  private Team team;
  private User riderA;
  private User riderB;
  private Long groupId;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    User admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    riderA = dataService.createUser("rider-a@example.com", "Rider A");
    riderB = dataService.createUser("rider-b@example.com", "Rider B");
    dataService.addUserToTeam(riderA, team, TeamRole.MEMBER);
    dataService.addUserToTeam(riderB, team, TeamRole.MEMBER);
    Ride ride =
        dataService.createRide(team, admin, "Race", "race", Instant.now().plus(1, ChronoUnit.DAYS));
    RideGroup group = dataService.createRideGroupWithMaxParticipants(admin, ride, "Group", 1);
    groupId = group.getId();
  }

  @Test
  void concurrentJoinsByTwoUsers_doNotExceedMaxParticipants() throws Exception {
    CountDownLatch aJoinedUncommitted = new CountDownLatch(1);
    CountDownLatch releaseA = new CountDownLatch(1);

    // Transaction A: join the last place, then hold the transaction open.
    CompletableFuture<Void> a =
        CompletableFuture.runAsync(
            () ->
                inRequest(
                    riderA,
                    () -> {
                      try {
                        userTransaction.begin();
                        try {
                          rideService.joinGroup(team.getSlug(), "race", groupId);
                          aJoinedUncommitted.countDown();
                          assertTrue(releaseA.await(30, TimeUnit.SECONDS));
                          userTransaction.commit();
                        } catch (Throwable t) {
                          userTransaction.rollback();
                          throw t;
                        }
                      } catch (Throwable t) {
                        throw new RuntimeException(t);
                      } finally {
                        aJoinedUncommitted.countDown();
                      }
                    }));

    assertTrue(aJoinedUncommitted.await(30, TimeUnit.SECONDS), "A's join did not run");
    if (a.isDone()) {
      a.get(); // surfaces A's own failure, if any, before the race is staged
    }

    // Transaction B: a different user joins the same group while A is still uncommitted.
    CompletableFuture<Void> b =
        CompletableFuture.runAsync(
            () ->
                inRequest(
                    riderB,
                    () -> {
                      try {
                        rideService.joinGroup(team.getSlug(), "race", groupId);
                      } catch (PedalonsException e) {
                        // GROUP_FULL is the correct outcome once joins are serialised.
                        assertTrue(e.getMessage().contains("GROUP_FULL"), e.getMessage());
                      }
                    }));

    // Today B completes at once (no lock). With a lock B blocks on A: give it a moment, then let
    // A commit either way so B can finish.
    try {
      b.get(3, TimeUnit.SECONDS);
    } catch (TimeoutException expectedOnceLocked) {
      // B is waiting for A's lock.
    }
    releaseA.countDown();
    a.get(30, TimeUnit.SECONDS);
    b.get(30, TimeUnit.SECONDS);

    long participants = participationRepository.count("rideGroup.id = ?1", groupId);
    assertEquals(1, participants, "group with maxParticipants=1 holds " + participants + " riders");
  }

  /** Runs {@code body} on this thread in a fresh request context, as {@code user}. */
  private void inRequest(User user, Runnable body) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      pedalonsContext.setUserForTest(user);
      body.run();
    } finally {
      requestContext.terminate();
    }
  }
}
