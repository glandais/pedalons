package fr.pedalons.service.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TokenUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.auth.AuthToken;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.auth.request.OtpRequest;
import fr.pedalons.enums.AuthTokenType;
import fr.pedalons.repository.auth.AuthTokenRepository;
import fr.pedalons.repository.user.UserRepository;
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
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Regression (docs/LEDGER_*.md SEC-34, SEC-35): {@code createOtp} locks the account row, then
 * invalidates the live code; {@code verifyOtp} must take its locks in the same order. Taking the
 * code first, a right code racing a request for a new code deadlocks: the login holds the code and
 * waits on the account for {@code recordLogin}, the request holds the account and waits on the
 * code. PostgreSQL then aborts one of them — a 500 on a valid login, or on {@code requestOtp}.
 *
 * <p>The interleaving is driven explicitly. The test's transaction stands for the request: it
 * takes the account lock the way {@code createOtp} does first, the owner's {@code verifyOtp} starts
 * on another thread and is given time to block, then {@code requestOtp} runs in that same
 * transaction (it joins it) and commits. With one lock order, the login waits on the account before
 * touching the code: the request goes through, and the login, run after it, finds its code
 * invalidated (a 400, as for any code replaced by a newer one) — or succeeds if a fix lets it in
 * first. Either way neither side fails with anything but {@link BadRequestException}.
 */
@QuarkusTest
class OtpVerifyRequestDeadlockRaceTest extends AbstractBaseTest {

  private static final String EMAIL = "otp-race@example.com";
  private static final String RIGHT_CODE = "123456";

  @Inject AuthService authService;
  @Inject AuthTokenRepository authTokenRepository;
  @Inject UserRepository userRepository;
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
  void rightCode_racingARequestForANewCode_doesNotDeadlock() throws Exception {
    Future<Boolean> login =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  // createOtp's first step: the account row, locked.
                  assertTrue(
                      userRepository
                          .findByEmailAndDomainForUpdate(domain.getId(), EMAIL)
                          .isPresent());

                  Future<Boolean> owner =
                      executor.submit(
                          () ->
                              inRequest(
                                  () -> {
                                    try {
                                      return authService
                                              .verifyOtp(EMAIL, RIGHT_CODE, "Owner", "203.0.113.7")
                                              .response()
                                              .accessToken()
                                          != null;
                                    } catch (BadRequestException codeReplaced) {
                                      return false;
                                    }
                                  }));
                  try {
                    // The login blocks on the account row (with the code already locked, unfixed).
                    owner.get(3, TimeUnit.SECONDS);
                  } catch (TimeoutException waitingOnTheAccount) {
                    // expected
                  }
                  assertFalse(owner.isDone(), "the login did not wait on the locked account");

                  // The rest of createOtp, in this transaction: count, invalidate, insert.
                  authService.requestOtp(new OtpRequest(EMAIL));
                  return owner;
                });

    // Whatever the login still had to do runs now; a deadlock abort surfaces here.
    Boolean loggedIn = login.get(60, TimeUnit.SECONDS);
    assertNotNull(loggedIn);

    long live =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    authTokenRepository.count(
                        "email = ?1 and tokenType = ?2 and domainId = ?3 and usedAt is null",
                        EMAIL,
                        AuthTokenType.OTP,
                        domain.getId()));
    assertEquals(1, live, "the request's new code is the only live one");
  }

  /** Runs the action in a fresh request context, on the default domain. */
  private <T> T inRequest(java.util.concurrent.Callable<T> action) throws Exception {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      return action.call();
    } finally {
      requestContext.terminate();
    }
  }
}
