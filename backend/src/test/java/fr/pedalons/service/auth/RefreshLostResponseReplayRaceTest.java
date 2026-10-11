package fr.pedalons.service.auth;

import static fr.pedalons.common.TokenUtils.hashToken;
import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.auth.response.RefreshResult;
import fr.pedalons.dto.device.response.DeviceTokenResponse;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.service.device.DeviceAuthService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug reproduction (found with a TLA+ model of refresh-token rotation, the "ResponseLost" action of
 * the auth spec): a refresh whose response is lost after the server committed the rotation leaves
 * the client holding t0, now the session's previous token. A retry inside the 60 s grace answers
 * IN_GRACE with no new token, so the client still has nothing better than t0; its next refresh past
 * the grace (mobile cold start, 15-minute access-token expiry, Karoo route load) is taken for a
 * replay and revokes the session, although no second party ever held the token.
 * RefreshTokenRotation.refresh lines 74-78 / 86-99, AuthSessionRepository.rotate.
 *
 * <p>The client is modelled faithfully: it only replaces its stored token when a response carries a
 * non-null refresh token (mobile auth_provider._handleAuthSuccess, auth_interceptor; Karoo
 * AuthManager), and keeps it on a network error.
 *
 * <p>These tests fail on the current code. Note that {@code
 * AuthServiceTest.refreshToken_previousTokenAfterTheGrace_revokesTheSession} and {@code
 * DeviceRefreshRotationTest.refresh_previousTokenAfterTheGrace_revokesTheDevicesSession} pin the
 * current (buggy for the lost-response case) behaviour; a fix has to arbitrate between them.
 */
@QuarkusTest
class RefreshLostResponseReplayRaceTest extends AbstractBaseTest {

  @Inject AuthService authService;
  @Inject DeviceAuthService deviceAuthService;
  @Inject AuthSessionRepository authSessionRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domainResolver.setDomainForTest(dataService.getOrCreateDefaultDomain());
  }

  @Test
  void lostRefreshResponse_thenRetryInGrace_thenRefreshAfterGrace_keepsTheSession() {
    User user = dataService.createVerifiedUser("lost-response@example.com", "Lost Response");
    String stored = dataService.createRefreshTokenForUser(user);
    String t0 = stored;
    Long sessionId = sessionIdOf(t0);

    // 1. The refresh commits the rotation, but its response never reaches the client.
    authService.refreshToken(t0);

    // 2. The client retries within the grace with the only token it has.
    RefreshResult retry = authService.refreshToken(stored);
    assertNotNull(retry.response().accessToken());
    if (retry.refreshToken() != null) {
      stored = retry.refreshToken();
    }

    // 3. More than the grace later (cold start, access-token expiry), the client refreshes again.
    backdateRotation(sessionId, Duration.ofSeconds(61));
    String presented = stored;

    RefreshResult later =
        assertDoesNotThrow(
            () -> authService.refreshToken(presented),
            "the honest client that lost one response is signed out: its token is taken for a"
                + " replay");
    assertNotNull(later.response().accessToken());
    assertFalse(isRevoked(sessionId), "the session was revoked although nobody else held t0");
  }

  @Test
  void lostRefreshResponse_thenColdStartAfterGrace_keepsTheSession() {
    User user = dataService.createVerifiedUser("cold-start@example.com", "Cold Start");
    String t0 = dataService.createRefreshTokenForUser(user);
    Long sessionId = sessionIdOf(t0);

    // The rotation commits; the response is lost and the app is killed. t0 stays in storage.
    authService.refreshToken(t0);
    backdateRotation(sessionId, Duration.ofSeconds(61));

    // Next cold start: AuthNotifier.initialize() refreshes with t0.
    assertDoesNotThrow(() -> authService.refreshToken(t0));
    assertFalse(isRevoked(sessionId), "a single lost response revoked the session");
  }

  @Test
  void lostDeviceRefreshResponse_thenRetryInGrace_thenRefreshAfterGrace_keepsTheDevicePaired() {
    User user = dataService.createVerifiedUser("karoo-lost@example.com", "Karoo Lost");
    String stored = dataService.createRefreshTokenForUser(user);
    Long sessionId = sessionIdOf(stored);

    // The device refresh commits, the Bluetooth-bridged response is lost.
    deviceAuthService.refreshToken(stored, "karoo");

    DeviceTokenResponse retry = deviceAuthService.refreshToken(stored, "karoo");
    if (retry.refreshToken() != null) {
      stored = retry.refreshToken();
    }

    backdateRotation(sessionId, Duration.ofSeconds(61));
    String presented = stored;

    assertDoesNotThrow(
        () -> deviceAuthService.refreshToken(presented, "karoo"),
        "the Karoo ends in TOKEN_INVALID and must be re-paired after one lost response");
    assertFalse(isRevoked(sessionId));
  }

  private Long sessionIdOf(String refreshToken) {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                authSessionRepository
                    .find("refreshTokenHash = ?1", hashToken(refreshToken))
                    .firstResult()
                    .getId());
  }

  private boolean isRevoked(Long sessionId) {
    return QuarkusTransaction.requiringNew()
        .call(() -> authSessionRepository.findById(sessionId).isRevoked());
  }

  private void backdateRotation(Long sessionId, Duration by) {
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                authSessionRepository.update(
                    "rotatedAt = ?1 where id = ?2", Instant.now().minus(by), sessionId));
  }
}
