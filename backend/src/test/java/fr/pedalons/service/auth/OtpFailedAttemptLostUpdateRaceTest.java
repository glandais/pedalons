package fr.pedalons.service.auth;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TokenUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.auth.AuthToken;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AuthTokenType;
import fr.pedalons.repository.auth.AuthTokenRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug (auth, found by the TLA+ model of concurrent {@code verifyOtp} calls on one login OTP): the
 * wrong-attempt counter is a lost update. {@link AuthService#verifyOtp} loads the token through
 * {@code AuthTokenRepository.findValidByEmailAndType} with no lock, {@code
 * AuthToken.recordFailedAttempt} increments {@code failedAttempts} in memory, and Hibernate flushes
 * an all-column UPDATE from that stale snapshot ({@code AuthToken} has no {@code @Version}). A wrong
 * guess that read {@code {failed=0, used_at=NULL}} and commits after the code was burnt (5 misses)
 * or used (owner logged in) writes {@code failed_attempts=1, used_at=NULL}: the code is valid again
 * with its counter reset, so a parallel burst gets far more than 5 guesses per code.
 *
 * <p>The interleaving is driven explicitly: the main thread runs the stale wrong guess through the
 * real {@code verifyOtp} inside an outer transaction (it joins it, so the read and the in-memory
 * increment happen but nothing is flushed), then, while that transaction is open, another thread
 * burns (or uses) the code in committed transactions, and only then does the stale guess commit.
 * Grace timeouts keep a fix that locks the row ({@code SELECT ... FOR UPDATE}) from deadlocking the
 * test: the other thread then waits on the stale guess, which commits first, as it would in prod.
 * A fix with {@code @Version} makes the stale commit fail, which is accepted.
 */
@QuarkusTest
class OtpFailedAttemptLostUpdateRaceTest extends AbstractBaseTest {

  private static final String EMAIL = "otp-race@example.com";
  private static final String RIGHT_CODE = "123456";

  @Inject AuthService authService;
  @Inject AuthTokenRepository authTokenRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  private Domain domain;
  private ExecutorService executor;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    executor = Executors.newSingleThreadExecutor();
    User user = dataService.createVerifiedUser(EMAIL, "OTP Race");
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                authTokenRepository.persist(
                    new AuthToken(
                        user,
                        EMAIL,
                        TokenUtils.hashToken(RIGHT_CODE),
                        AuthTokenType.OTP,
                        Instant.now().plus(5, ChronoUnit.MINUTES),
                        domain.getId())));
  }

  @AfterEach
  void tearDown() {
    executor.shutdownNow();
  }

  @Test
  void staleWrongGuess_committingAfterTheCodeWasBurnt_mustNotReviveIt() throws Exception {
    runStaleWrongGuessAround(
        () -> {
          // Five other wrong guesses, each committed: the code is burnt.
          for (int i = 0; i < 5; i++) {
            assertThrows(
                BadRequestException.class,
                () -> authService.verifyOtp(EMAIL, "000000", "Agent", "198.51.100.1"));
          }
        });

    Optional<AuthToken> token = findValidToken();
    assertTrue(
        token.isEmpty(),
        "six wrong guesses were made against a 5-try code, yet it is valid again with"
            + " failedAttempts="
            + token.map(AuthToken::getFailedAttempts).orElse(-1)
            + " (the stale guess wrote used_at=NULL over the burn)");
    assertThrows(
        BadRequestException.class,
        () -> authService.verifyOtp(EMAIL, RIGHT_CODE, "Agent", "198.51.100.1"),
        "a burnt code must not log anyone in");
  }

  @Test
  void staleWrongGuess_committingAfterTheOwnerLoggedIn_mustNotReopenTheUsedCode() throws Exception {
    runStaleWrongGuessAround(
        () ->
            assertNotNull(
                authService
                    .verifyOtp(EMAIL, RIGHT_CODE, "Owner", "203.0.113.7")
                    .response()
                    .accessToken()));

    Optional<AuthToken> token = findValidToken();
    assertTrue(
        token.isEmpty(),
        "the owner already used the code, yet it is valid again with failedAttempts="
            + token.map(AuthToken::getFailedAttempts).orElse(-1));
    assertThrows(
        BadRequestException.class,
        () -> authService.verifyOtp(EMAIL, RIGHT_CODE, "Attacker", "198.51.100.1"),
        "a used OTP must not log in a second time");
  }

  /**
   * A wrong guess reads the token and counts its miss in memory; {@code interleaved} then runs on
   * another thread, in committed transactions of its own; the stale guess commits last.
   */
  private void runStaleWrongGuessAround(Runnable interleaved) throws Exception {
    AtomicReference<Future<?>> other = new AtomicReference<>();
    try {
      QuarkusTransaction.requiringNew()
          .run(
              () -> {
                // verifyOtp joins this transaction: it reads {failed=0, used_at=NULL} and
                // increments in memory; the flush waits for this transaction's commit.
                assertThrows(
                    BadRequestException.class,
                    () -> authService.verifyOtp(EMAIL, "999999", "Agent", "198.51.100.1"));

                other.set(executor.submit(() -> inRequest(interleaved)));
                try {
                  // Unfixed, nothing blocks the other thread. A row lock makes it wait on us: we
                  // then commit first and it runs after.
                  other.get().get(5, TimeUnit.SECONDS);
                } catch (TimeoutException lockedOut) {
                  // fixed with a lock: fall through and commit
                } catch (Exception e) {
                  throw new IllegalStateException(e);
                }
              });
    } catch (RuntimeException staleCommitRejected) {
      // A @Version fix rejects the stale write at commit: that is the fixed behaviour.
    }
    // Whatever the other thread still has to do (it was waiting on our lock) finishes here, and
    // its own assertions are surfaced.
    assertNotNull(other.get(), "the interleaved step was started");
    other.get().get(60, TimeUnit.SECONDS);
  }

  private Optional<AuthToken> findValidToken() {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                authTokenRepository.findValidByEmailAndType(
                    EMAIL, AuthTokenType.OTP, domain.getId()));
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
