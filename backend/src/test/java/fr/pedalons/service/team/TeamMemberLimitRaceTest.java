package fr.pedalons.service.team;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.UserTransaction;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Two joins racing for the last place of a free team (docs/LEDGER_*.md BILL-10).
 *
 * <p>Counting then inserting, without a lock, lets both see 24 of 25 and both commit: nothing else
 * serialises them, the (user, team) unique index does not fire for two different users. The
 * interleaving is driven explicitly, as in {@code RideGroupCapacityRaceTest}: A's join runs inside
 * an open transaction kept uncommitted while B joins. With the team row locked before the count, B
 * waits for A's commit, then counts 25 and is refused.
 */
@QuarkusTest
class TeamMemberLimitRaceTest extends AbstractBaseTest {

  @Inject TeamMembershipService membershipService;
  @Inject UserTeamRepository userTeamRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject DomainResolver domainResolver;
  @Inject UserTransaction userTransaction;

  private Domain domain;
  private Team team;
  private User joinerA;
  private User joinerB;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    User admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    dataService.setTeamJoinable(team, true);
    // The admin plus 23: one place left under the free cap of 25.
    dataService.addFillerMembers(team, "filler", 23);
    joinerA = dataService.createUser("joiner-a@example.com", "Joiner A");
    joinerB = dataService.createUser("joiner-b@example.com", "Joiner B");
  }

  @Test
  void concurrentJoinsForTheLastPlace_letOnlyOneIn() throws Exception {
    CountDownLatch aJoinedUncommitted = new CountDownLatch(1);
    CountDownLatch releaseA = new CountDownLatch(1);

    // Transaction A: takes the last place, then holds the transaction open.
    CompletableFuture<Void> a =
        CompletableFuture.runAsync(() ->
            inRequest(
                joinerA,
                () -> {
                  try {
                    userTransaction.begin();
                    try {
                      membershipService.joinTeam(team.getSlug());
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

    // Transaction B: another user joins while A is still uncommitted.
    AtomicReference<ErrorCode> bRefusal = new AtomicReference<>();
    CompletableFuture<Void> b =
        CompletableFuture.runAsync(() ->
            inRequest(
                joinerB,
                () -> {
                  try {
                    membershipService.joinTeam(team.getSlug());
                  } catch (PedalonsException e) {
                    bRefusal.set(e.getErrorCode());
                  }
                }));

    // Without the lock B completes at once; with it B waits for A. Let A commit either way.
    try {
      b.get(3, TimeUnit.SECONDS);
    } catch (TimeoutException expectedWhileLocked) {
      // B is waiting on the team row.
    }
    releaseA.countDown();
    a.get(30, TimeUnit.SECONDS);
    b.get(30, TimeUnit.SECONDS);

    assertEquals(ErrorCode.TEAM_MEMBER_LIMIT_REACHED, bRefusal.get());
    assertEquals(25, userTeamRepository.countActiveMembers(team.getId()));
    assertTrue(userTeamRepository.findByUserAndTeam(joinerA.getId(), team.getId()).isPresent());
    assertTrue(userTeamRepository.findByUserAndTeam(joinerB.getId(), team.getId()).isEmpty());
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
