package fr.pedalons.service.auth;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.dto.auth.request.OtpRequest;
import fr.pedalons.enums.AuthTokenType;
import fr.pedalons.repository.auth.AuthTokenRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.mailer.MockMailbox;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.UserTransaction;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug: AuthService.requestOtp's rate limit ("at most 3 codes per 5 minutes") and its "one live
 * code" rule are check-then-act. createOtp counts recent rows, bulk-invalidates the live ones and
 * inserts a new one, with no lock per address. Two requests in flight together each count only
 * committed rows, each invalidate only committed rows, and each insert a code. The result is more
 * than 3 codes in the window and several rows with usedAt IS NULL. verifyOtp then checks an
 * arbitrary live row and burns only that one, so the guess budget documented for SEC/H1 (3 x 5)
 * grows with the number of concurrent requests.
 *
 * <p>Found by the TLA+/TLC model of createOtp: two transactions under READ COMMITTED doing
 * count -> check -> invalidate -> insert. The invariants {@code issuedInWindow <= 3} and {@code
 * liveCodes <= 1} are violated by the interleaving count(A) invalidate(A) insert(A) count(B)
 * invalidate(B) insert(B) commit(A) commit(B).
 *
 * <p>The interleaving is driven explicitly. A's requestOtp joins a transaction that the test holds
 * open after the code is flushed. B then requests a code in its own transaction. Today B's count
 * does not see A's row. Its invalidate may wait on a row A updated, but it never sees A's new row,
 * so it inserts a second live code. Once requests are serialised per address (a lock on the user
 * row or an advisory lock taken before the count), B waits for A's commit. Then B counts A's code
 * and is either rate-limited or invalidates A's code.
 */
@QuarkusTest
class OtpRequestRateLimitRaceTest extends AbstractBaseTest {

  private static final String EMAIL = "otp-race@example.com";

  @Inject AuthService authService;
  @Inject AuthTokenRepository authTokenRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;
  @Inject UserTransaction userTransaction;
  @Inject MockMailbox mailbox;

  private Domain domain;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    mailbox.clear();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    dataService.createVerifiedUser(EMAIL, "OTP Race");
  }

  /** Two codes already issued; two concurrent requests must not bring the window past 3. */
  @Test
  void concurrentRequests_doNotIssueMoreThanTheRateLimit() throws Exception {
    authService.requestOtp(new OtpRequest(EMAIL));
    authService.requestOtp(new OtpRequest(EMAIL));
    assertEquals(2, otpRows(), "setup: two codes issued sequentially");

    raceTwoRequests();

    long issued = otpRows();
    assertTrue(
        issued <= 3,
        "rate limit is 3 codes per window, but "
            + issued
            + " were issued ("
            + mailbox.getMailsSentTo(EMAIL).size()
            + " mails sent)");
  }

  /** Two concurrent requests from scratch (a web tab and the app) must leave one live code. */
  @Test
  void concurrentRequests_leaveAtMostOneLiveCode() throws Exception {
    raceTwoRequests();

    long live = liveOtpRows();
    assertEquals(1, live, live + " OTP codes are live at once for the same address");
  }

  /**
   * A requests a code inside a transaction held open after the flush. B requests another while A
   * is uncommitted, then A commits.
   */
  private void raceTwoRequests() throws Exception {
    CountDownLatch aIssuedUncommitted = new CountDownLatch(1);
    CountDownLatch releaseA = new CountDownLatch(1);

    CompletableFuture<Void> a =
        CompletableFuture.runAsync(
            () ->
                inRequest(
                    () -> {
                      try {
                        userTransaction.begin();
                        try {
                          // requestOtp joins this transaction (QuarkusTransaction.joiningExisting).
                          authService.requestOtp(new OtpRequest(EMAIL));
                          authTokenRepository.flush(); // the insert reaches the database
                          aIssuedUncommitted.countDown();
                          assertTrue(releaseA.await(30, TimeUnit.SECONDS));
                          userTransaction.commit();
                        } catch (Throwable t) {
                          userTransaction.rollback();
                          throw t;
                        }
                      } catch (Throwable t) {
                        throw new RuntimeException(t);
                      } finally {
                        aIssuedUncommitted.countDown();
                      }
                    }));

    assertTrue(aIssuedUncommitted.await(30, TimeUnit.SECONDS), "A's request did not run");
    if (a.isDone()) {
      a.get(); // surfaces A's own failure before the race is staged
    }

    CompletableFuture<Void> b =
        CompletableFuture.runAsync(
            () ->
                inRequest(
                    () -> {
                      try {
                        authService.requestOtp(new OtpRequest(EMAIL));
                      } catch (RuntimeException e) {
                        // A unique-index fix may reject B outright: that is a correct outcome.
                      }
                    }));

    // Today B either completes at once or waits only on the row A invalidated. Once requests are
    // serialised, B waits on A's lock. Give it a moment, then let A commit either way.
    try {
      b.get(3, TimeUnit.SECONDS);
    } catch (TimeoutException expectedWhileAHoldsALock) {
      // B is waiting for A.
    }
    releaseA.countDown();
    a.get(30, TimeUnit.SECONDS);
    b.get(30, TimeUnit.SECONDS);
  }

  private long otpRows() {
    return authTokenRepository.count(
        "email = ?1 and tokenType = ?2 and domainId = ?3",
        EMAIL,
        AuthTokenType.OTP,
        domain.getId());
  }

  private long liveOtpRows() {
    return authTokenRepository.count(
        "email = ?1 and tokenType = ?2 and domainId = ?3 and usedAt is null",
        EMAIL,
        AuthTokenType.OTP,
        domain.getId());
  }

  /** Runs {@code body} on this thread in a fresh request context on the test domain. */
  private void inRequest(Runnable body) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      body.run();
    } finally {
      requestContext.terminate();
    }
  }
}
