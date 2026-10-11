package fr.pedalons.service.auth;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AuthFailureKind;
import fr.pedalons.repository.auth.AuthFailureRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.elytron.security.common.BcryptUtil;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.mockito.InjectSpy;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.BrokenBarrierException;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * Bug: AuthThrottle counts only committed failures, so concurrent guesses overshoot the password
 * limit (docs/LEDGER_*.md SEC-7).
 *
 * <p>Found by the TLA+/TLC model of AuthService.loginWithPassword + AuthThrottle: each request runs
 * check (countSince over committed auth_failures rows) → bcrypt → record (insert in requiringNew),
 * with nothing serialising check..record per subject. The invariant "guesses that reach the
 * password comparison within a window ≤ pedalons.auth.password.max-failures" is violated by the
 * interleaving check(1) … check(N) record(1) … record(N): every request reads a count of 0 and is
 * let through. In production the overshoot is bounded only by the JDBC pool (~20 per instance).
 * POST /api/device/oauth/complete (checkDeviceCode / recordDeviceCodeFailure) has the same shape.
 *
 * <p>The interleaving is driven explicitly: a spy on {@link AuthFailureRepository#countSince} lets
 * the real count run, then parks each request on a barrier until all {@value #GUESSES} have read
 * their count — so all of them check before any records. Once check..record is serialised per
 * subject (advisory lock, locked counter row…), the requests can no longer all reach the barrier:
 * it times out, breaks, and the requests go on one after the other, each seeing the failures of the
 * previous ones, so only {@code max-failures} guesses get through.
 */
@QuarkusTest
class AuthThrottleConcurrentGuessRaceTest extends AbstractBaseTest {

  /** Above the limit of 5, and low enough (2 connections each) to stay inside the test pool. */
  private static final int GUESSES = 8;

  private static final int MAX_FAILURES = 5; // pedalons.auth.password.max-failures default

  private static final String EMAIL = "victim@example.com";

  @Inject AuthService authService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;
  @InjectSpy AuthFailureRepository authFailureRepository;

  private Domain domain;
  private ExecutorService executor;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    User victim = dataService.createVerifiedUser(EMAIL, "Victim");
    dataService.setUserPasswordHash(victim, BcryptUtil.bcryptHash("the-real-password"));
    executor = Executors.newFixedThreadPool(GUESSES);
  }

  @AfterEach
  void tearDown() {
    executor.shutdownNow();
  }

  @Test
  void concurrentWrongPasswords_doNotGetPastTheFailureLimit() throws Exception {
    CyclicBarrier allChecked = new CyclicBarrier(GUESSES);
    Mockito.doAnswer(
            invocation -> {
              Object count = invocation.callRealMethod();
              try {
                // Hold every request between its check and its record until all have checked.
                allChecked.await(5, TimeUnit.SECONDS);
              } catch (TimeoutException | BrokenBarrierException serialised) {
                // A fix serialises the requests: they cannot all meet here, go on one at a time.
              }
              return count;
            })
        .when(authFailureRepository)
        .countSince(any(), eq(AuthFailureKind.PASSWORD), anyString(), any(Instant.class));

    List<Future<ErrorCode>> outcomes = new ArrayList<>();
    for (int i = 0; i < GUESSES; i++) {
      String guess = "wrong-guess-" + i;
      outcomes.add(executor.submit(() -> inRequest(() -> attempt(guess))));
    }

    int reachedBcrypt = 0;
    int throttled = 0;
    for (Future<ErrorCode> outcome : outcomes) {
      ErrorCode code = outcome.get(60, TimeUnit.SECONDS);
      if (code == ErrorCode.INVALID_CREDENTIALS) {
        reachedBcrypt++;
      } else if (code == ErrorCode.LOGIN_RATE_LIMITED) {
        throttled++;
      } else {
        fail("unexpected outcome " + code);
      }
    }

    assertEquals(GUESSES, reachedBcrypt + throttled);
    assertTrue(
        reachedBcrypt <= MAX_FAILURES,
        reachedBcrypt
            + " concurrent wrong passwords were compared for one address, the limit is "
            + MAX_FAILURES
            + " (throttled: "
            + throttled
            + ")");
  }

  private ErrorCode attempt(String password) {
    try {
      authService.loginWithPassword(EMAIL, password, "Agent", "203.0.113.7");
      return null;
    } catch (PedalonsException e) {
      return e.getErrorCode();
    }
  }

  /** Runs {@code body} on this thread in a fresh request context bound to the test domain. */
  private ErrorCode inRequest(java.util.function.Supplier<ErrorCode> body) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(domain);
      return body.get();
    } finally {
      requestContext.terminate();
    }
  }
}
