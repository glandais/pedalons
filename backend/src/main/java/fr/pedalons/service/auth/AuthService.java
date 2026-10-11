package fr.pedalons.service.auth;

import static fr.pedalons.common.TokenUtils.generateOtpCode;
import static fr.pedalons.common.TokenUtils.generateSecureToken;
import static fr.pedalons.common.TokenUtils.hashToken;

import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.InternalException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.auth.AuthSession;
import fr.pedalons.domain.auth.AuthToken;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.auth.request.OtpRequest;
import fr.pedalons.dto.auth.request.RegisterRequest;
import fr.pedalons.dto.auth.response.AuthResponse;
import fr.pedalons.dto.auth.response.AuthResult;
import fr.pedalons.dto.auth.response.EmailLinkPreviewResponse;
import fr.pedalons.dto.auth.response.RefreshResult;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AuthTokenType;
import fr.pedalons.enums.EmailLinkKind;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.repository.auth.AuthTokenRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import fr.pedalons.service.user.UserService;
import io.quarkus.elytron.security.common.BcryptUtil;
import io.quarkus.logging.Log;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class AuthService {

  @Inject UserRepository userRepository;
  @Inject AuthSessionRepository authSessionRepository;
  @Inject RefreshTokenRotation refreshTokenRotation;
  @Inject AuthTokenRepository authTokenRepository;
  @Inject JwtService jwtService;
  @Inject AuthEmailService authEmailService;
  @Inject PasskeyService passkeyService;
  @Inject DomainResolver domainResolver;
  @Inject fr.pedalons.repository.platform.DomainRepository domainRepository;
  @Inject PedalonsQueryContext queryContext;
  @Inject AuthThrottle authThrottle;
  @Inject UserService userService;

  @ConfigProperty(name = "pedalons.auth.refresh-token.expiry-days", defaultValue = "30")
  int refreshTokenExpiryDays;

  @ConfigProperty(name = "pedalons.auth.otp.expiry-minutes", defaultValue = "5")
  int otpExpiryMinutes;

  @ConfigProperty(name = "pedalons.auth.otp.max-attempts", defaultValue = "3")
  int otpMaxAttempts;

  @ConfigProperty(name = "pedalons.auth.otp.rate-limit-window-minutes", defaultValue = "5")
  int otpRateLimitWindowMinutes;

  /**
   * Wrong codes a login OTP survives. With {@code otp.max-attempts} codes per window, a guesser gets
   * 3 × 5 tries out of a million every 5 minutes instead of an unbounded run.
   */
  @ConfigProperty(name = "pedalons.auth.otp.max-verify-attempts", defaultValue = "5")
  int otpMaxVerifyAttempts;

  @ConfigProperty(name = "pedalons.auth.email-verification.expiry-hours", defaultValue = "24")
  int emailVerificationExpiryHours;

  @ConfigProperty(name = "pedalons.auth.password-reset.expiry-hours", defaultValue = "1")
  int passwordResetExpiryHours;

  /**
   * Not {@code @Transactional}, like the three other methods that e-mail a token: the token is
   * committed first and the mail sent after. Sent inside the transaction, a slow SMTP relay held it
   * open until the reaper aborted it, and the visitor got a 500 for a failure that was not theirs.
   * A delivery failure still reaches the caller here — a sign-up whose mail never left must say so,
   * and trying again invalidates the orphaned token.
   */
  @Public
  public void register(RegisterRequest request) {
    String token =
        QuarkusTransaction.joiningExisting().call(() -> createPendingRegistration(request));
    sendVerification(request.email(), request.displayName(), token);
  }

  /**
   * The verification mail of a sign-up or an address change, whose failure the visitor must hear
   * about — named, not as a bare 500: nothing was created (the account only exists once the address
   * is verified), and trying again works, the new token replacing the orphaned one.
   */
  private void sendVerification(String email, String displayName, String token) {
    try {
      authEmailService.sendVerificationEmail(email, displayName, token);
    } catch (RuntimeException e) {
      throw new InternalException(ErrorCode.EMAIL_NOT_SENT, e);
    }
  }

  private String createPendingRegistration(RegisterRequest request) {
    Domain domain = domainResolver.getDomain();

    // Check if email already exists in this domain
    if (userRepository.findByEmailAndDomain(domain.getId(), request.email()).isPresent()) {
      throw new BadRequestException(ErrorCode.EMAIL_ALREADY_EXISTS);
    }

    // Invalidate any existing verification tokens for this email
    authTokenRepository.invalidateByEmailAndType(
        request.email(), AuthTokenType.EMAIL_VERIFICATION, domain.getId());

    // Generate verification token
    String token = generateSecureToken();
    String tokenHash = hashToken(token);

    // Create pending registration token with domain info
    AuthToken authToken =
        new AuthToken(
            request.email(),
            tokenHash,
            AuthTokenType.EMAIL_VERIFICATION,
            Instant.now().plus(Duration.ofHours(emailVerificationExpiryHours)),
            domain.getId());
    authToken.setPendingDisplayName(request.displayName());
    authToken.setPendingDomainId(domain.getId());
    // Bean Validation refuses a request without acceptTerms: reaching here means they were
    // accepted.
    authToken.setPendingTermsAcceptedAt(authToken.getCreatedAt());
    authTokenRepository.persist(authToken);
    return token;
  }

  /**
   * What a mailed link is about, without spending it. The page shows this address before anything
   * happens: the link alone never signs anyone in, so a link someone forwards cannot land its reader
   * in an account that is not theirs unaware (docs/LEDGER_*.md SEC-9, audit M5).
   */
  @Transactional
  @Public
  public EmailLinkPreviewResponse previewEmailLink(String token) {
    AuthToken authToken = findEmailLinkToken(token);
    EmailLinkKind kind =
        authToken.getTokenType() == AuthTokenType.EMAIL_CHANGE
            ? EmailLinkKind.EMAIL_CHANGE
            : EmailLinkKind.SIGN_UP;
    return new EmailLinkPreviewResponse(authToken.getEmail(), kind);
  }

  /**
   * Creates the account a sign-up link verifies, with the password chosen now, by whoever holds the
   * mailbox. Chosen at sign-up, it belonged to whoever typed the address — someone else's, possibly
   * — and survived its owner's click (docs/LEDGER_*.md SEC-24, audit L4). A token issued before this
   * change still carries a pending hash in a column the entity no longer maps (docs/LEDGER_*.md
   * API-57): it is never read.
   */
  @Transactional
  @Public
  public AuthResult activateAccount(
      String token, String password, String userAgent, String ipAddress) {
    AuthToken authToken = findEmailLinkToken(token);
    if (authToken.getTokenType() != AuthTokenType.EMAIL_VERIFICATION) {
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }

    authToken.markUsed();

    // Get the domain from the token
    Long domainId =
        Objects.requireNonNull(
            authToken.getPendingDomainId(), "Pending domain ID should not be null");
    Domain domain =
        domainRepository
            .findByIdOptional(domainId)
            .orElseThrow(() -> new BadRequestException(ErrorCode.DOMAIN_NOT_FOUND));

    // Create user from pending data
    String displayName =
        Objects.requireNonNull(
            authToken.getPendingDisplayName(), "Pending display name should not be null");
    User user = new User(domain, authToken.getEmail(), displayName);
    user.setPasswordHash(BcryptUtil.bcryptHash(password));
    user.markEmailVerified();
    user.recordLogin();
    // Accepted on the sign-up form, recorded on the token by register. A token issued before the
    // form asked carries none, and the account records none.
    user.setTermsAcceptedAt(authToken.getPendingTermsAcceptedAt());
    userRepository.persist(user);

    return createAuthResult(user, userAgent, ipAddress);
  }

  /**
   * Applies an address change once its link is followed. Opens no session: the member asked for it
   * signed in, and a session here would sign whoever follows the link into the account that asked
   * — the login CSRF of audit M5 (docs/LEDGER_*.md SEC-9). A signed-in client refreshes its user.
   */
  @Transactional
  @Public
  public void confirmEmailChange(String token) {
    AuthToken authToken = findEmailLinkToken(token);
    if (authToken.getTokenType() != AuthTokenType.EMAIL_CHANGE) {
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }

    authToken.markUsed();

    User user = authToken.getUser();
    if (user == null) {
      throw new BadRequestException(ErrorCode.USER_NOT_FOUND);
    }

    Long domainId = user.getDomain().getId();
    String newEmail = authToken.getEmail();

    // Re-check collision at verify time (another account may have claimed it meanwhile).
    userRepository
        .findByEmailAndDomain(domainId, newEmail)
        .ifPresent(
            existing -> {
              if (!existing.getId().equals(user.getId())) {
                throw new fr.pedalons.common.exception.ConflictException(
                    ErrorCode.EMAIL_ALREADY_EXISTS);
              }
            });

    user.setEmail(newEmail);
    user.markEmailVerified();
    userRepository.persist(user);
  }

  /** A sign-up or address-change link, unspent, on the site that mailed it. */
  private AuthToken findEmailLinkToken(String token) {
    AuthToken authToken =
        authTokenRepository
            .findValidByTokenHashAndDomain(hashToken(token), domainResolver.getDomainId())
            .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));
    if (authToken.getTokenType() != AuthTokenType.EMAIL_VERIFICATION
        && authToken.getTokenType() != AuthTokenType.EMAIL_CHANGE) {
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }
    return authToken;
  }

  /**
   * Starts changing the signed-in user's email address. Sends a verification link to the new
   * address; the change is only applied once that link is followed. Rejects an address already
   * used by another account in the domain.
   *
   * <p>The mail leaves after the commit, and its failure reaches the caller — see {@link
   * #register}.
   */
  @Logged
  public void requestEmailChange(String newEmail) {
    String normalized = newEmail.toLowerCase(java.util.Locale.ROOT).trim();
    EmailChange change =
        QuarkusTransaction.joiningExisting().call(() -> createEmailChangeToken(normalized));
    if (change != null) {
      sendVerification(normalized, change.displayName(), change.token());
    }
  }

  private record EmailChange(String displayName, String token) {}

  /** Null when the rate limit withholds the mail. */
  private @Nullable EmailChange createEmailChangeToken(String normalized) {
    User user = queryContext.getUser();
    Long domainId = user.getDomain().getId();

    // Collision: reject if the address belongs to a different account (decision: no auto-merge).
    userRepository
        .findByEmailAndDomain(domainId, normalized)
        .ifPresent(
            existing -> {
              if (!existing.getId().equals(user.getId())) {
                throw new fr.pedalons.common.exception.ConflictException(
                    ErrorCode.EMAIL_ALREADY_EXISTS);
              }
            });

    // Rate limit (mirrors OTP/password-reset). Silent to avoid probing which emails are taken.
    long recentCount =
        authTokenRepository.countRecentByEmailAndType(
            normalized, AuthTokenType.EMAIL_CHANGE, otpRateLimitWindowMinutes, domainId);
    if (recentCount >= otpMaxAttempts) {
      Log.warnf("Email-change rate limit exceeded for user=%d domain=%d", user.getId(), domainId);
      return null;
    }

    authTokenRepository.invalidateByEmailAndType(normalized, AuthTokenType.EMAIL_CHANGE, domainId);

    String token = generateSecureToken();
    AuthToken authToken =
        new AuthToken(
            user,
            normalized,
            hashToken(token),
            AuthTokenType.EMAIL_CHANGE,
            Instant.now().plus(Duration.ofHours(emailVerificationExpiryHours)),
            domainId);
    authTokenRepository.persist(authToken);
    return new EmailChange(user.getDisplayName(), token);
  }

  /**
   * The code is committed before the mail leaves, and a delivery failure is only logged: the answer
   * is the same whether or not the address has an account (anti-enumeration), and the visitor can
   * ask for another code. Sent inside the transaction, a slow SMTP relay would let the reaper abort
   * it — a 500 despite the catch, and no code at all.
   */
  @Public
  public void requestOtp(OtpRequest request) {
    String otpCode = QuarkusTransaction.joiningExisting().call(() -> createOtp(request));
    if (otpCode == null) {
      return;
    }
    try {
      authEmailService.sendOtpEmail(request.email(), otpCode);
    } catch (Exception e) {
      Log.errorf(
          e,
          "Failed to send OTP email to email=%s domain=%d",
          request.email(),
          domainResolver.getDomain().getId());
    }
  }

  /** Null when no code is issued: unknown or unverified address, or rate limit. */
  private @Nullable String createOtp(OtpRequest request) {
    Domain domain = domainResolver.getDomain();
    // The account row stays locked until the commit: the count, the invalidation and the insert
    // below are a check-then-act, which two concurrent requests would each pass blind to the
    // other's uncommitted code — more codes than the rate limit, several live at once
    // (docs/LEDGER_*.md SEC-35).
    User user =
        userRepository.findByEmailAndDomainForUpdate(domain.getId(), request.email()).orElse(null);

    // Always respond success to prevent email enumeration
    if (user == null || !user.isEmailVerified()) {
      return null;
    }

    // Rate limiting: check if too many OTP requests in the window
    long recentCount =
        authTokenRepository.countRecentByEmailAndType(
            request.email(), AuthTokenType.OTP, otpRateLimitWindowMinutes, domain.getId());
    if (recentCount >= otpMaxAttempts) {
      Log.warnf("OTP rate limit exceeded for email=%s domain=%d", request.email(), domain.getId());
      return null;
    }

    // Invalidate any existing OTPs for this email
    authTokenRepository.invalidateByEmailAndType(
        request.email(), AuthTokenType.OTP, domain.getId());

    // Generate 6-digit OTP code
    String otpCode = generateOtpCode();
    String tokenHash = hashToken(otpCode);

    AuthToken authToken =
        new AuthToken(
            user,
            request.email(),
            tokenHash,
            AuthTokenType.OTP,
            Instant.now().plus(Duration.ofMinutes(otpExpiryMinutes)),
            domain.getId());
    authTokenRepository.persist(authToken);
    return otpCode;
  }

  // A wrong code throws, and the default rollback would erase the failed attempt it just counted.
  @Transactional(dontRollbackOn = BadRequestException.class)
  @Public
  public AuthResult verifyOtp(String email, String code, String userAgent, String ipAddress) {
    Long domainId = domainResolver.getDomainId();
    String tokenHash = hashToken(code);
    // Account row first, then the code: createOtp locks in the same order (docs/LEDGER_*.md
    // SEC-35). Taking the code first would deadlock a login against a request for a new code — the
    // login holding the code and waiting on the account for recordLogin, the request holding the
    // account and waiting on the code to invalidate it. An address without an account locks
    // nothing here: it has no code either.
    userRepository.findByEmailAndDomainForUpdate(domainId, email);
    // Locked: concurrent guesses would otherwise each write back a stale counter (docs/LEDGER_*.md
    // SEC-34).
    AuthToken authToken =
        authTokenRepository
            .findValidByEmailAndTypeForUpdate(email, AuthTokenType.OTP, domainId)
            .orElse(null);
    if (authToken == null) {
      logFailedLogin("otp", "no_valid_code", email, domainId, ipAddress);
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }

    // Verify the code matches (constant-time comparison to prevent timing attacks)
    if (!MessageDigest.isEqual(
        authToken.getTokenHash().getBytes(StandardCharsets.UTF_8),
        tokenHash.getBytes(StandardCharsets.UTF_8))) {
      authToken.recordFailedAttempt(otpMaxVerifyAttempts);
      logFailedLogin("otp", "wrong_code", email, domainId, ipAddress);
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }

    authToken.markUsed();

    User user = authToken.getUser();
    if (user == null) {
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }

    userRepository.recordLogin(user.getId());

    return createAuthResult(user, userAgent, ipAddress);
  }

  /**
   * Past {@code pedalons.auth.password.max-failures} wrong passwords for the address, answers 429
   * without looking further (docs/LEDGER_*.md SEC-7, audit M4). Every failure counts, an unknown
   * address's too: the limit must not tell which addresses have an account.
   */
  @Transactional
  @Public
  public AuthResult loginWithPassword(
      String email, String password, String userAgent, String ipAddress) {
    Domain domain = domainResolver.getDomain();
    authThrottle.checkPassword(domain.getId(), email);
    User user = userRepository.findByEmailAndDomain(domain.getId(), email).orElse(null);
    if (user == null) {
      logFailedLogin("password", "unknown_account", email, domain.getId(), ipAddress);
      throw invalidPassword(domain, email);
    }

    if (user.getPasswordHash() == null) {
      // Return INVALID_CREDENTIALS to avoid leaking whether the account exists
      // (same response as user-not-found above)
      logFailedLogin("password", "no_password", email, domain.getId(), ipAddress);
      throw invalidPassword(domain, email);
    }

    if (!BcryptUtil.matches(password, user.getPasswordHash())) {
      logFailedLogin("password", "wrong_password", email, domain.getId(), ipAddress);
      throw invalidPassword(domain, email);
    }

    authThrottle.clearPassword(domain.getId(), email);
    userRepository.recordLogin(user.getId());
    return createAuthResult(user, userAgent, ipAddress);
  }

  /** Same shape as {@link #requestOtp}: token committed first, delivery failure only logged. */
  @Public
  public void requestPasswordReset(String email) {
    String token = QuarkusTransaction.joiningExisting().call(() -> createPasswordResetToken(email));
    if (token == null) {
      return;
    }
    try {
      authEmailService.sendPasswordResetEmail(email, token);
    } catch (Exception e) {
      Log.errorf(
          e,
          "Failed to send password reset email to email=%s domain=%d",
          email,
          domainResolver.getDomain().getId());
    }
  }

  /** Null when no token is issued: unknown or unverified address, or rate limit. */
  private @Nullable String createPasswordResetToken(String email) {
    Domain domain = domainResolver.getDomain();
    User user = userRepository.findByEmailAndDomain(domain.getId(), email).orElse(null);

    // Always respond success to prevent email enumeration
    if (user == null || !user.isEmailVerified()) {
      return null;
    }

    // Rate limit
    long recentCount =
        authTokenRepository.countRecentByEmailAndType(
            email, AuthTokenType.PASSWORD_RESET, otpRateLimitWindowMinutes, domain.getId());
    if (recentCount >= otpMaxAttempts) {
      Log.warnf("Password reset rate limit exceeded for email=%s domain=%d", email, domain.getId());
      return null;
    }

    // Invalidate existing reset tokens
    authTokenRepository.invalidateByEmailAndType(
        email, AuthTokenType.PASSWORD_RESET, domain.getId());

    String token = generateSecureToken();
    String tokenHash = hashToken(token);

    AuthToken authToken =
        new AuthToken(
            user,
            email,
            tokenHash,
            AuthTokenType.PASSWORD_RESET,
            Instant.now().plus(Duration.ofHours(passwordResetExpiryHours)),
            domain.getId());
    authTokenRepository.persist(authToken);
    return token;
  }

  @Transactional
  @Public
  public AuthResult resetPassword(
      String token, String newPassword, String userAgent, String ipAddress) {
    String tokenHash = hashToken(token);

    AuthToken authToken =
        authTokenRepository
            .findValidByTokenHash(tokenHash)
            .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));

    if (authToken.getTokenType() != AuthTokenType.PASSWORD_RESET) {
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }

    authToken.markUsed();

    User user = authToken.getUser();
    if (user == null) {
      throw new BadRequestException(ErrorCode.USER_NOT_FOUND);
    }

    user.setPasswordHash(BcryptUtil.bcryptHash(newPassword));
    user.recordLogin();
    // A reset is what someone does when the password leaked: every session opened with it —
    // browsers, the app, paired GPS devices — ends here, and only the one below survives
    // (docs/LEDGER_*.md SEC-12, audit L1). Before it, not after: this bulk update would revoke it.
    authSessionRepository.revokeAllByUserId(user.getId());

    return createAuthResult(user, userAgent, ipAddress);
  }

  @Transactional
  @Public
  public AuthResult authenticateWithPasskey(
      Map<String, Object> response, String userAgent, String ipAddress) {
    // Resolved before the verification: once it has failed, the transaction can no longer reach
    // the database, and resolving the domain then turned a refused passkey into a 500.
    Long domainId = domainResolver.getDomainId();
    User user;
    try {
      user = passkeyService.verifyAuthentication(response);
    } catch (PedalonsException e) {
      // No address here: the assertion names a credential, and a failed one names nobody sure.
      logFailedLogin("passkey", e.getErrorCode().name(), null, domainId, ipAddress);
      throw e;
    }
    userRepository.recordLogin(user.getId());
    return createAuthResult(user, userAgent, ipAddress);
  }

  /**
   * A new access token, and a new refresh token in place of the one presented (audit M7,
   * docs/LEDGER_*.md SEC-27) — see {@link RefreshTokenRotation} for the grace and the replay.
   *
   * <p>Inside the grace of a rotation made by another refresh, no new refresh token: the winner's is
   * already in the shared cookie or the app's storage.
   */
  @Transactional
  @Public
  public RefreshResult refreshToken(String refreshToken) {
    Domain domain = domainResolver.getDomain();
    RefreshTokenRotation.Refresh refresh =
        refreshTokenRotation.refresh(refreshToken, session -> checkRefreshable(session, domain));
    return switch (refresh.outcome()) {
      case ROTATED, IN_GRACE ->
          new RefreshResult(
              refreshResponse(Objects.requireNonNull(refresh.session()).getUser()),
              refresh.nextToken());
      case REPLAYED, UNKNOWN -> throw new ForbiddenException();
    };
  }

  /** Refuses a session that is no longer alive, or that belongs to another site. */
  private static void checkRefreshable(AuthSession session, Domain domain) {
    if (!session.isValid()) {
      throw new BadRequestException(ErrorCode.SESSION_EXPIRED);
    }
    if (!session.getUser().getDomain().getId().equals(domain.getId())) {
      throw new ForbiddenException();
    }
  }

  private AuthResponse refreshResponse(User user) {
    return AuthResponse.builder()
        .accessToken(jwtService.generateAccessToken(user))
        .expiresIn(jwtService.getAccessTokenExpirySeconds())
        .user(userService.toDto(user))
        .build();
  }

  @Transactional
  @Public
  public void logout(@Nullable String refreshToken) {
    if (refreshToken == null || refreshToken.isBlank()) {
      return;
    }

    String tokenHash = hashToken(refreshToken);
    // The previous token too: a client that signs out with the token a concurrent refresh has just
    // rotated away still means to end its session (docs/LEDGER_*.md SEC-27).
    authSessionRepository
        .findByRefreshTokenHash(tokenHash)
        .or(() -> authSessionRepository.findByPreviousRefreshTokenHash(tokenHash))
        .ifPresent(AuthSession::revoke);
  }

  @Transactional
  @Logged
  public void logoutAll() {
    Long userId = queryContext.getUserId();
    authSessionRepository.revokeAllByUserId(userId);
  }

  /**
   * One WARN line per failed sign-in, so that brute force and credential stuffing show up in Loki
   * (docs/LEDGER_*.md SEC-23, audit L14). The answer to the visitor stays the same whatever the
   * reason — only this line tells an unknown account from a wrong password. Never the password nor
   * the code: the privacy policy promises no credential in the logs, and a typo'd password is often
   * one digit away from the real one. The caller passes the domain it resolved before failing:
   * this line must not touch the database, whose transaction a failed verification may have
   * broken.
   */
  private void logFailedLogin(
      String method, String reason, @Nullable String email, Long domainId, String ipAddress) {
    Log.warnf(
        "Login failed method=%s reason=%s email=%s domain=%d ip=%s",
        method, reason, email, domainId, ipAddress);
  }

  private BadRequestException invalidPassword(Domain domain, String email) {
    authThrottle.recordPasswordFailure(domain.getId(), email);
    return new BadRequestException(ErrorCode.INVALID_CREDENTIALS);
  }

  public User getUserByEmail(String email) {
    Domain domain = domainResolver.getDomain();
    return userRepository
        .findByEmailAndDomain(domain.getId(), email)
        .orElseThrow(NotFoundException::new);
  }

  /**
   * Creates an auth result for the given user, including access token, refresh token, and session.
   */
  public AuthResult createAuthResult(User user, String userAgent, String ipAddress) {
    // Generate tokens
    String accessToken = jwtService.generateAccessToken(user);
    String refreshToken = generateSecureToken();
    String refreshTokenHash = hashToken(refreshToken);

    // Create session
    AuthSession session =
        new AuthSession(
            user, refreshTokenHash, Instant.now().plus(Duration.ofDays(refreshTokenExpiryDays)));
    session.setUserAgent(userAgent);
    session.setIpAddress(ipAddress);
    authSessionRepository.persist(session);

    AuthResponse response =
        AuthResponse.builder()
            .accessToken(accessToken)
            .expiresIn(jwtService.getAccessTokenExpirySeconds())
            .user(userService.toDto(user))
            .refreshToken(refreshToken)
            .build();

    return new AuthResult(response, refreshToken);
  }
}
