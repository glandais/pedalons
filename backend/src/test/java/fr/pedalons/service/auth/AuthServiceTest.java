package fr.pedalons.service.auth;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.auth.AuthToken;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.auth.request.OtpRequest;
import fr.pedalons.dto.auth.request.RegisterRequest;
import fr.pedalons.dto.auth.response.AuthResult;
import fr.pedalons.dto.auth.response.RefreshResult;
import fr.pedalons.enums.AuthTokenType;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.repository.auth.AuthTokenRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.mailer.MockMailbox;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.logging.Handler;
import java.util.logging.LogRecord;
import java.util.logging.Logger;
import org.jboss.logmanager.ExtLogRecord;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AuthServiceTest extends AbstractBaseTest {

  @Inject AuthService authService;
  @Inject UserRepository userRepository;
  @Inject AuthTokenRepository authTokenRepository;
  @Inject AuthSessionRepository authSessionRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject MockMailbox mailbox;
  @Inject DomainResolver domainResolver;
  @Inject PedalonsQueryContext pedalonsContext;

  private Domain domain;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    mailbox.clear();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
  }

  // --- Register tests ---

  @Test
  void register_shouldCreateVerificationToken() {
    RegisterRequest request = new RegisterRequest("new@example.com", "New User", true);

    authService.register(request);

    var tokens = authTokenRepository.listAll();
    assertEquals(1, tokens.size());
    assertEquals("new@example.com", tokens.getFirst().getEmail());
    assertEquals(AuthTokenType.EMAIL_VERIFICATION, tokens.getFirst().getTokenType());
    assertEquals("New User", tokens.getFirst().getPendingDisplayName());
  }

  @Test
  void register_shouldSendVerificationEmail() {
    RegisterRequest request = new RegisterRequest("new@example.com", "New User", true);

    authService.register(request);

    var sent = mailbox.getMailsSentTo("new@example.com");
    assertEquals(1, sent.size());
    assertTrue(sent.getFirst().getSubject().contains("Confirmez"));
  }

  @Test
  void register_shouldThrowIfEmailExists() {
    dataService.createVerifiedUser("existing@example.com", "Existing User");
    RegisterRequest request = new RegisterRequest("existing@example.com", "New User", true);

    assertThrows(BadRequestException.class, () -> authService.register(request));
  }

  @Test
  @Transactional
  void register_shouldInvalidateExistingTokens() {
    // Create existing token
    Instant expiresAt = Instant.now().plus(24, ChronoUnit.HOURS);
    dataService.createAuthToken(
        "test@example.com", "old-hash", AuthTokenType.EMAIL_VERIFICATION, expiresAt);

    RegisterRequest request = new RegisterRequest("test@example.com", "Test User", true);
    authService.register(request);

    // Old token should be invalidated
    assertTrue(authTokenRepository.findValidByTokenHash("old-hash").isEmpty());
  }

  // --- VerifyEmail tests ---

  @Test
  void verifyEmail_shouldCreateUserAndSession() {
    // Create a token manually with known hash
    createVerificationToken("verify@example.com", "Verified User", "test-token");

    AuthResult result =
        authService.activateAccount("test-token", "ownerpass123", "Test Agent", "127.0.0.1");

    assertNotNull(result.response().accessToken());
    assertEquals("verify@example.com", result.response().user().email());
    assertEquals("Verified User", result.response().user().displayName());

    // User should exist and be verified
    User user =
        userRepository.findByEmailAndDomain(domain.getId(), "verify@example.com").orElseThrow();
    assertTrue(user.isEmailVerified());
  }

  @Test
  void verifyEmail_shouldThrowForInvalidToken() {
    assertThrows(
        BadRequestException.class,
        () -> authService.activateAccount("invalid", "ownerpass123", "Agent", "IP"));
  }

  @Test
  void verifyEmail_shouldThrowForExpiredToken() {
    createExpiredVerificationToken("expired@example.com", "User", "expired-token");

    assertThrows(
        BadRequestException.class,
        () -> authService.activateAccount("expired-token", "ownerpass123", "Agent", "IP"));
  }

  // --- RequestOtp tests ---

  @Test
  void requestOtp_shouldCreateTokenAndSendEmail() {
    dataService.createVerifiedUser("otp@example.com", "OTP User");
    OtpRequest request = new OtpRequest("otp@example.com");

    authService.requestOtp(request);

    var tokens =
        authTokenRepository.findValidByEmailAndType(
            "otp@example.com", AuthTokenType.OTP, domain.getId());
    assertTrue(tokens.isPresent());

    assertEquals(1, mailbox.getMailsSentTo("otp@example.com").size());
  }

  @Test
  void requestOtp_shouldNotThrowForNonexistentUser() {
    OtpRequest request = new OtpRequest("nonexistent@example.com");

    // Should not throw - prevents email enumeration
    assertDoesNotThrow(() -> authService.requestOtp(request));
    assertEquals(0, mailbox.getTotalMessagesSent());
  }

  @Test
  void requestOtp_shouldNotSendForUnverifiedUser() {
    dataService.createUser("unverified@example.com", "Unverified User");
    OtpRequest request = new OtpRequest("unverified@example.com");

    authService.requestOtp(request);

    assertEquals(0, mailbox.getTotalMessagesSent());
  }

  // --- VerifyOtp tests ---

  @Test
  void verifyOtp_shouldReturnAuthResult() {
    User user = dataService.createVerifiedUser("otp@example.com", "OTP User");
    createOtpToken(user, "123456");

    AuthResult result = authService.verifyOtp("otp@example.com", "123456", "Agent", "IP");

    assertNotNull(result.response().accessToken());
    assertEquals("otp@example.com", result.response().user().email());
  }

  @Test
  void verifyOtp_shouldThrowForInvalidCode() {
    User user = dataService.createVerifiedUser("otp@example.com", "OTP User");
    createOtpToken(user, "123456");

    assertThrows(
        BadRequestException.class,
        () -> authService.verifyOtp("otp@example.com", "000000", "Agent", "IP"));
  }

  @Test
  void verifyOtp_burnsTheCodeAfterFiveWrongGuesses() {
    User user = dataService.createVerifiedUser("otp@example.com", "OTP User");
    createOtpToken(user, "123456");

    // Each miss is committed despite the exception — a rolled-back counter would never reach 5.
    for (int i = 0; i < 5; i++) {
      assertThrows(
          BadRequestException.class,
          () -> authService.verifyOtp("otp@example.com", "000000", "Agent", "IP"));
    }

    // The right code no longer opens anything: a guesser cannot walk the million combinations.
    assertThrows(
        BadRequestException.class,
        () -> authService.verifyOtp("otp@example.com", "123456", "Agent", "IP"));
  }

  @Test
  void verifyOtp_rightCodeAfterAFewTyposStillLogsIn() {
    User user = dataService.createVerifiedUser("otp@example.com", "OTP User");
    createOtpToken(user, "123456");

    for (int i = 0; i < 4; i++) {
      assertThrows(
          BadRequestException.class,
          () -> authService.verifyOtp("otp@example.com", "000000", "Agent", "IP"));
    }

    assertNotNull(
        authService.verifyOtp("otp@example.com", "123456", "Agent", "IP").response().accessToken());
  }

  // --- RefreshToken tests ---

  @Test
  void refreshToken_shouldReturnNewAccessToken() {
    User user = dataService.createVerifiedUser("refresh@example.com", "Refresh User");
    String refreshToken = dataService.createRefreshTokenForUser(user);

    RefreshResult result = authService.refreshToken(refreshToken);

    assertNotNull(result.response().accessToken());
    assertEquals("refresh@example.com", result.response().user().email());
    assertNull(result.response().refreshToken());
  }

  // --- Refresh token rotation (audit M7, docs/LEDGER_*.md SEC-27) ---

  @Test
  void refreshToken_rotatesTheRefreshToken() {
    User user = dataService.createVerifiedUser("rotate@example.com", "Rotate User");
    String first = dataService.createRefreshTokenForUser(user);

    String second = authService.refreshToken(first).refreshToken();

    assertNotNull(second);
    assertNotEquals(first, second);
    String third = authService.refreshToken(second).refreshToken();
    assertNotNull(third);
    assertNotEquals(second, third);
  }

  @Test
  void refreshToken_previousTokenWithinTheGrace_refreshesWithoutRotatingAgain() {
    User user = dataService.createVerifiedUser("grace@example.com", "Grace User");
    String first = dataService.createRefreshTokenForUser(user);
    String second = authService.refreshToken(first).refreshToken();

    // The other tab, whose refresh left with the same token and lost the race.
    RefreshResult late = authService.refreshToken(first);

    assertNotNull(late.response().accessToken());
    assertNull(late.refreshToken());
    // The winner's token is untouched: it still refreshes, and rotates.
    assertNotNull(authService.refreshToken(second).refreshToken());
  }

  @Test
  void refreshToken_previousTokenAfterTheGrace_rotatesAgainFromIt() {
    User user = dataService.createVerifiedUser("replay@example.com", "Replay User");
    String first = dataService.createRefreshTokenForUser(user);
    String second = authService.refreshToken(first).refreshToken();
    assertNotNull(second);
    backdateRotation(first, Duration.ofMinutes(5));

    // The response that carried the second token was lost (docs/LEDGER_*.md API-94): the first
    // rotates again instead of revoking the session.
    String third = authService.refreshToken(first).refreshToken();
    assertNotNull(third);
    assertNotEquals(second, third);

    // The successor it replaced is dead; the new one rotates, and retires the first.
    assertThrows(ForbiddenException.class, () -> authService.refreshToken(second));
    assertNotNull(authService.refreshToken(third).refreshToken());
    assertThrows(ForbiddenException.class, () -> authService.refreshToken(first));
  }

  @Test
  void refreshToken_aTokenTwoRotationsBack_isRefused() {
    User user = dataService.createVerifiedUser("stale@example.com", "Stale User");
    String first = dataService.createRefreshTokenForUser(user);
    String second = authService.refreshToken(first).refreshToken();
    assertNotNull(second);
    String third = authService.refreshToken(second).refreshToken();
    assertNotNull(third);

    assertThrows(ForbiddenException.class, () -> authService.refreshToken(first));
    assertNotNull(authService.refreshToken(third).refreshToken());
  }

  @Test
  void logout_withTheTokenARefreshJustRotatedAway_endsTheSession() {
    User user = dataService.createVerifiedUser("logout-rotated@example.com", "User");
    String first = dataService.createRefreshTokenForUser(user);
    String second = authService.refreshToken(first).refreshToken();

    authService.logout(first);

    assertThrows(ForbiddenException.class, () -> authService.refreshToken(second));
  }

  /** Moves the rotation that made {@code previousToken} the previous one {@code by} into the past. */
  private void backdateRotation(String previousToken, Duration by) {
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                authSessionRepository.update(
                    "rotatedAt = ?1 where previousRefreshTokenHash = ?2",
                    Instant.now().minus(by),
                    hashToken(previousToken)));
  }

  @Test
  void refreshToken_shouldRecordSessionUseWithoutTouchingTheUser() {
    User user = dataService.createVerifiedUser("refresh-use@example.com", "Refresh User");
    String refreshToken = dataService.createRefreshTokenForUser(user);
    Object[] before = userVersionAndLastLogin(user.getId());

    authService.refreshToken(refreshToken);
    authService.refreshToken(refreshToken);

    // A refresh is not a login: writing the versioned user row made concurrent refreshes of one
    // session fail on the optimistic lock.
    assertArrayEquals(before, userVersionAndLastLogin(user.getId()));
    Instant lastUsedAt =
        authSessionRepository
            .getEntityManager()
            .createQuery(
                "select s.lastUsedAt from AuthSession s where s.previousRefreshTokenHash = :hash",
                Instant.class)
            .setParameter("hash", hashToken(refreshToken))
            .getSingleResult();
    assertNotNull(lastUsedAt);
  }

  /** Scalar projection, so the answer comes from the database and not a cached entity. */
  private Object[] userVersionAndLastLogin(Long userId) {
    return userRepository
        .getEntityManager()
        .createQuery("select u.version, u.lastLoginAt from User u where u.id = :id", Object[].class)
        .setParameter("id", userId)
        .getSingleResult();
  }

  @Test
  void refreshToken_shouldThrowForInvalidToken() {
    assertThrows(ForbiddenException.class, () -> authService.refreshToken("invalid-token"));
  }

  @Test
  void refreshToken_shouldThrowForRevokedSession() {
    User user = dataService.createVerifiedUser("revoked@example.com", "User");
    String refreshToken = dataService.createRefreshTokenForUser(user);
    authService.logout(refreshToken);

    assertThrows(ForbiddenException.class, () -> authService.refreshToken(refreshToken));
  }

  // --- Logout tests ---

  @Test
  void logout_shouldRevokeSession() {
    User user = dataService.createVerifiedUser("logout@example.com", "Logout User");
    String refreshToken = dataService.createRefreshTokenForUser(user);

    authService.logout(refreshToken);

    assertThrows(ForbiddenException.class, () -> authService.refreshToken(refreshToken));
  }

  @Test
  void logout_shouldHandleNullToken() {
    assertDoesNotThrow(() -> authService.logout(null));
  }

  @Test
  void logout_shouldHandleBlankToken() {
    assertDoesNotThrow(() -> authService.logout(""));
    assertDoesNotThrow(() -> authService.logout("   "));
  }

  // --- LogoutAll tests ---

  @Test
  void logoutAll_shouldRevokeAllUserSessions() {
    User user = dataService.createVerifiedUser("logoutall@example.com", "User");
    String token1 = dataService.createRefreshTokenForUser(user);
    String token2 = dataService.createRefreshTokenForUser(user);

    pedalonsContext.setUserForTest(user);
    authService.logoutAll();

    assertThrows(ForbiddenException.class, () -> authService.refreshToken(token1));
    assertThrows(ForbiddenException.class, () -> authService.refreshToken(token2));
  }

  // --- AuthenticateWithPasskey tests ---

  @Test
  void authenticateWithPasskey_shouldThrowForInvalidResponse() {
    // Invalid passkey response (no valid credential)
    var response =
        java.util.Map.of(
            "id",
            "dW5rbm93bg", // "unknown" in base64
            "response",
            java.util.Map.of(
                "clientDataJSON", "e30",
                "authenticatorData", "AAAA",
                "signature", "AAAA"));

    assertThrows(
        NotFoundException.class,
        () -> authService.authenticateWithPasskey(response, "Test Agent", "127.0.0.1"));
  }

  @Test
  void authenticateWithPasskey_shouldThrowForMalformedResponse() {
    var response = java.util.Map.<String, Object>of("invalid", "data");

    assertThrows(
        ForbiddenException.class,
        () -> authService.authenticateWithPasskey(response, "Test Agent", "127.0.0.1"));
  }

  // --- GetUserByEmail tests ---

  @Test
  void getUserByEmail_shouldReturnUser() {
    dataService.createUser("find@example.com", "Find User");

    User user = authService.getUserByEmail("find@example.com");

    assertEquals("find@example.com", user.getEmail());
  }

  @Test
  void getUserByEmail_shouldThrowForNonexistent() {
    assertThrows(NotFoundException.class, () -> authService.getUserByEmail("nonexistent@test.com"));
  }

  // --- Password login tests ---

  @Test
  void loginWithPassword_shouldReturnAuthResult() {
    createVerifiedUserWithPassword("login@example.com", "Login User", "mypassword123");

    AuthResult result =
        authService.loginWithPassword("login@example.com", "mypassword123", "Agent", "IP");

    assertNotNull(result.response().accessToken());
    assertEquals("login@example.com", result.response().user().email());
  }

  @Test
  void loginWithPassword_shouldRecordTheLoginWithoutBumpingTheUserVersion() {
    createVerifiedUserWithPassword("login-twice@example.com", "Login User", "mypassword123");
    User user = dataService.findUserByEmail("login-twice@example.com");
    Object[] before = userVersionAndLastLogin(user.getId());

    authService.loginWithPassword("login-twice@example.com", "mypassword123", "Agent", "IP");

    // Two logins of one account at once (two tabs, the app and the site) failed on the optimistic
    // lock: a login must record itself without writing the versioned row.
    Object[] after = userVersionAndLastLogin(user.getId());
    assertEquals(before[0], after[0]);
    assertNotNull(after[1]);
    assertNotEquals(before[1], after[1]);
  }

  @Test
  void loginWithPassword_withNoPasswordSet_shouldThrowInvalidCredentials() {
    dataService.createVerifiedUser("nopassword@example.com", "No Password");

    BadRequestException ex =
        assertThrows(
            BadRequestException.class,
            () ->
                authService.loginWithPassword("nopassword@example.com", "anypass", "Agent", "IP"));
    assertEquals(fr.pedalons.dto.error.ErrorCode.INVALID_CREDENTIALS, ex.getErrorCode());
  }

  @Test
  void loginWithPassword_withWrongPassword_shouldThrowInvalidCredentials() {
    createVerifiedUserWithPassword("login2@example.com", "Login User", "correctpass");

    assertThrows(
        BadRequestException.class,
        () -> authService.loginWithPassword("login2@example.com", "wrongpass", "Agent", "IP"));
  }

  // --- Failed sign-in log (docs/LEDGER_*.md SEC-23, audit L14) ---

  @Test
  void loginWithPassword_wrongPassword_logsTheFailureWithoutThePassword() {
    createVerifiedUserWithPassword("stuffed@example.com", "Login User", "correctpass");

    List<String> lines =
        failedLoginLines(
            () ->
                assertThrows(
                    BadRequestException.class,
                    () ->
                        authService.loginWithPassword(
                            "stuffed@example.com", "guessedpass", "Agent", "203.0.113.7")));

    assertEquals(1, lines.size());
    String line = lines.getFirst();
    assertTrue(line.contains("method=password"), line);
    assertTrue(line.contains("reason=wrong_password"), line);
    assertTrue(line.contains("email=stuffed@example.com"), line);
    assertTrue(line.contains("ip=203.0.113.7"), line);
    assertFalse(line.contains("guessedpass"), line);
  }

  @Test
  void loginWithPassword_unknownAccount_isLoggedToo() {
    List<String> lines =
        failedLoginLines(
            () ->
                assertThrows(
                    BadRequestException.class,
                    () ->
                        authService.loginWithPassword(
                            "nobody@example.com", "anypass", "Agent", "203.0.113.7")));

    assertEquals(1, lines.size());
    assertTrue(lines.getFirst().contains("reason=unknown_account"), lines.getFirst());
  }

  @Test
  void loginWithPassword_success_logsNoFailure() {
    createVerifiedUserWithPassword("fine@example.com", "Login User", "correctpass");

    List<String> lines =
        failedLoginLines(
            () -> authService.loginWithPassword("fine@example.com", "correctpass", "Agent", "IP"));

    assertTrue(lines.isEmpty(), lines.toString());
  }

  @Test
  void verifyOtp_wrongCode_logsTheFailureWithoutTheCode() {
    User user = dataService.createVerifiedUser("otp-log@example.com", "OTP User");
    createOtpToken(user, "123456");

    List<String> lines =
        failedLoginLines(
            () ->
                assertThrows(
                    BadRequestException.class,
                    () ->
                        authService.verifyOtp(
                            "otp-log@example.com", "654321", "Agent", "203.0.113.7")));

    assertEquals(1, lines.size());
    String line = lines.getFirst();
    assertTrue(line.contains("method=otp"), line);
    assertTrue(line.contains("reason=wrong_code"), line);
    assertFalse(line.contains("654321"), line);
    assertFalse(line.contains("123456"), line);
  }

  @Test
  void authenticateWithPasskey_unknownCredential_isLogged() {
    var response =
        java.util.Map.of(
            "id",
            "dW5rbm93bg",
            "response",
            java.util.Map.of(
                "clientDataJSON", "e30",
                "authenticatorData", "AAAA",
                "signature", "AAAA"));

    List<String> lines =
        failedLoginLines(
            () ->
                assertThrows(
                    NotFoundException.class,
                    () -> authService.authenticateWithPasskey(response, "Agent", "203.0.113.7")));

    assertEquals(1, lines.size());
    assertTrue(lines.getFirst().contains("method=passkey"), lines.getFirst());
    assertTrue(lines.getFirst().contains("reason=PASSKEY_NOT_FOUND"), lines.getFirst());
  }

  /** The "Login failed" lines {@link AuthService} logs while {@code action} runs. */
  private List<String> failedLoginLines(Runnable action) {
    List<String> lines = new CopyOnWriteArrayList<>();
    Handler handler =
        new Handler() {
          @Override
          public void publish(LogRecord record) {
            String message =
                record instanceof ExtLogRecord ext
                    ? ext.getFormattedMessage()
                    : record.getMessage();
            if (message != null && message.startsWith("Login failed")) {
              lines.add(message);
            }
          }

          @Override
          public void flush() {}

          @Override
          public void close() {}
        };
    Logger logger = Logger.getLogger(AuthService.class.getName());
    logger.addHandler(handler);
    try {
      action.run();
    } finally {
      logger.removeHandler(handler);
    }
    return lines;
  }

  // --- RequestPasswordReset tests ---

  @Test
  void requestPasswordReset_shouldCreateTokenAndSendEmail() {
    createVerifiedUserWithPassword("reset@example.com", "Reset User", "oldpass");
    mailbox.clear();

    authService.requestPasswordReset("reset@example.com");

    var tokens =
        authTokenRepository.findValidByEmailAndType(
            "reset@example.com", AuthTokenType.PASSWORD_RESET, domain.getId());
    assertTrue(tokens.isPresent());
    assertEquals(1, mailbox.getMailsSentTo("reset@example.com").size());
  }

  @Test
  void requestPasswordReset_shouldNotThrowForNonexistentUser() {
    assertDoesNotThrow(() -> authService.requestPasswordReset("ghost@example.com"));
    assertEquals(0, mailbox.getTotalMessagesSent());
  }

  @Test
  void requestPasswordReset_shouldNotSendForUnverifiedUser() {
    dataService.createUser("unverified@example.com", "Unverified");

    authService.requestPasswordReset("unverified@example.com");

    assertEquals(0, mailbox.getTotalMessagesSent());
  }

  // --- ResetPassword tests ---

  @Test
  void resetPassword_shouldUpdatePasswordAndReturnAuthResult() {
    User user = createVerifiedUserWithPassword("reset2@example.com", "Reset2 User", "oldpass");
    createPasswordResetToken(user, "reset2@example.com", "reset-token-123456");

    AuthResult result =
        authService.resetPassword("reset-token-123456", "newpass123", "Agent", "IP");

    assertNotNull(result.response().accessToken());
    assertEquals("reset2@example.com", result.response().user().email());
  }

  @Test
  void resetPassword_withAlreadyUsedToken_shouldThrow() {
    User user = createVerifiedUserWithPassword("reset3@example.com", "Reset3 User", "oldpass");
    createPasswordResetToken(user, "reset3@example.com", "reset-token-777888");

    // First use succeeds
    authService.resetPassword("reset-token-777888", "newpass123", "Agent", "IP");

    // Second use must fail
    assertThrows(
        BadRequestException.class,
        () -> authService.resetPassword("reset-token-777888", "anotherpass", "Agent", "IP"));
  }

  @Test
  void resetPassword_withExpiredToken_shouldThrow() {
    User user = createVerifiedUserWithPassword("reset4@example.com", "Reset4 User", "oldpass");
    createExpiredPasswordResetToken(user, "reset4@example.com", "reset-token-999111");

    assertThrows(
        BadRequestException.class,
        () -> authService.resetPassword("reset-token-999111", "newpass123", "Agent", "IP"));
  }

  // --- Helper methods ---

  @Transactional
  void createVerificationToken(String email, String displayName, String token) {
    String tokenHash = hashToken(token);
    AuthToken authToken =
        new AuthToken(
            email,
            tokenHash,
            AuthTokenType.EMAIL_VERIFICATION,
            Instant.now().plus(24, ChronoUnit.HOURS),
            domain.getId());
    authToken.setPendingDisplayName(displayName);
    authToken.setPendingDomainId(domain.getId());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  void createExpiredVerificationToken(String email, String displayName, String token) {
    String tokenHash = hashToken(token);
    AuthToken authToken =
        new AuthToken(
            email,
            tokenHash,
            AuthTokenType.EMAIL_VERIFICATION,
            Instant.now().minus(1, ChronoUnit.HOURS),
            domain.getId());
    authToken.setPendingDisplayName(displayName);
    authToken.setPendingDomainId(domain.getId());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  User createVerifiedUserWithPassword(String email, String displayName, String password) {
    User user = new User(domain, email, displayName);
    user.markEmailVerified();
    user.setPasswordHash(io.quarkus.elytron.security.common.BcryptUtil.bcryptHash(password));
    userRepository.persistAndFlush(user);
    return user;
  }

  @Transactional
  void createPasswordResetToken(User user, String email, String code) {
    String tokenHash = hashToken(code);
    AuthToken authToken =
        new AuthToken(
            user,
            email,
            tokenHash,
            AuthTokenType.PASSWORD_RESET,
            Instant.now().plus(5, ChronoUnit.MINUTES),
            domain.getId());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  void createExpiredPasswordResetToken(User user, String email, String code) {
    String tokenHash = hashToken(code);
    AuthToken authToken =
        new AuthToken(
            user,
            email,
            tokenHash,
            AuthTokenType.PASSWORD_RESET,
            Instant.now().minus(1, ChronoUnit.HOURS),
            domain.getId());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  void createOtpToken(User user, String code) {
    String tokenHash = hashToken(code);
    AuthToken authToken =
        new AuthToken(
            user,
            user.getEmail(),
            tokenHash,
            AuthTokenType.OTP,
            Instant.now().plus(5, ChronoUnit.MINUTES),
            domain.getId());
    authTokenRepository.persist(authToken);
  }

  private String hashToken(String token) {
    try {
      java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
      byte[] hash = digest.digest(token.getBytes(java.nio.charset.StandardCharsets.UTF_8));
      return java.util.Base64.getEncoder().encodeToString(hash);
    } catch (java.security.NoSuchAlgorithmException e) {
      throw new RuntimeException("SHA-256 not available", e);
    }
  }
}
