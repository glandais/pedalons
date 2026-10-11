package fr.pedalons.service.device;

import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.auth.AuthSession;
import fr.pedalons.domain.auth.DeviceCode;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.device.response.DeviceCodeResponse;
import fr.pedalons.dto.device.response.DeviceTokenResponse;
import fr.pedalons.dto.device.response.PendingDeviceCode;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.repository.auth.DeviceCodeRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.auth.AuthThrottle;
import fr.pedalons.service.auth.RefreshTokenRotation;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Objects;
import java.util.Optional;
import org.jboss.logging.Logger;

/**
 * Service handling device code OAuth flow (RFC 8628) for GPS devices (Karoo, Garmin, etc.).
 *
 * <p>Flow:
 *
 * <ol>
 *   <li>Device calls POST /api/device/oauth/device → gets device_code + user_code
 *   <li>Device displays user_code and QR for verification_uri_complete
 *   <li>User scans QR → opens /karoo?code=ABC123 (or /garmin) on phone
 *   <li>User authenticates via OTP email on frontend
 *   <li>Frontend calls POST /api/device/oauth/complete to mark code as authorized
 *   <li>Device polls POST /api/device/oauth/token until authorized
 *   <li>Device receives access + refresh tokens
 * </ol>
 */
@ApplicationScoped
public class DeviceAuthService {

  private static final Logger LOG = Logger.getLogger(DeviceAuthService.class);
  private static final SecureRandom SECURE_RANDOM = new SecureRandom();

  private static final int DEVICE_CODE_EXPIRY_MINUTES = 10;
  private static final int POLLING_INTERVAL_SECONDS = 5;
  private static final String USER_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  private static final int USER_CODE_LENGTH = 6;

  @Inject DeviceJwtService deviceJwtService;
  @Inject AuthSessionRepository authSessionRepository;
  @Inject DeviceCodeRepository deviceCodeRepository;
  @Inject UserRepository userRepository;
  @Inject DomainResolver domainResolver;
  @Inject PedalonsQueryContext pedalonsQueryContext;
  @Inject AuthThrottle authThrottle;
  @Inject RefreshTokenRotation refreshTokenRotation;

  @Public
  public String getFrontendBaseUrl() {
    return domainResolver.getEffectiveBaseUrl();
  }

  /**
   * Start the device code flow. Returns codes for the device to display and poll with.
   *
   * @param clientId The client identifier (e.g., "karoo", "garmin")
   * @return Device code response with user code and verification URLs
   */
  @Public
  @Transactional
  public DeviceCodeResponse initiateDeviceCodeFlow(String clientId) {
    Long domainId = domainResolver.getDomain().getId();

    // Generate device code (long, for polling)
    String deviceCode = generateSecureToken();
    String deviceCodeHash = hashToken(deviceCode);

    // Generate user code (short, human-readable)
    String userCode = generateUserCode();

    // Build verification URLs
    String baseUrl = getFrontendBaseUrl();
    String verificationUri = baseUrl + verificationPath(clientId);
    String verificationUriComplete = verificationUri + "?code=" + userCode;

    // Store device code in database
    Instant expiresAt = Instant.now().plus(Duration.ofMinutes(DEVICE_CODE_EXPIRY_MINUTES));
    DeviceCode entity = new DeviceCode(deviceCodeHash, userCode, clientId, domainId, expiresAt);
    deviceCodeRepository.persist(entity);

    LOG.infov("Initiated device code flow for client={0}, user_code={1}", clientId, userCode);

    return DeviceCodeResponse.builder()
        .deviceCode(deviceCode)
        .userCode(userCode)
        .verificationUri(verificationUri)
        .verificationUriComplete(verificationUriComplete)
        .expiresIn(DEVICE_CODE_EXPIRY_MINUTES * 60)
        .interval(POLLING_INTERVAL_SECONDS)
        .build();
  }

  /**
   * The page the user opens on their phone. Each device has its own: the Karoo one asks for a
   * Hammerhead connection, which means nothing to a Garmin user. Any other client keeps /karoo, the
   * only page there was before Garmin.
   */
  static String verificationPath(String clientId) {
    return "garmin".equals(clientId) ? "/garmin" : "/karoo";
  }

  /**
   * Complete the device code flow after user authenticates. Called by frontend after OTP
   * verification.
   *
   * <p>An unknown code counts against the account and the domain, and past either limit the call
   * answers 429 before looking the code up: six characters are guessable online otherwise
   * (docs/LEDGER_*.md SEC-4, audit H5).
   *
   * @param userCode The user code displayed on device
   */
  @Transactional
  @Logged
  public void completeDeviceCodeFlow(String userCode) {
    Long userId = pedalonsQueryContext.getUserId();
    Long domainId = domainResolver.getDomainId();

    // Counted before the lookup, taken back once the code is known (docs/LEDGER_*.md SEC-36).
    Long guessId = authThrottle.admitDeviceCode(domainId, userId);
    // Locked: "the first approval stands" below is a check-then-act, and two accounts confirming
    // the same code at once would otherwise both read it unauthorized (docs/LEDGER_*.md AUD-16).
    DeviceCode deviceCode =
        deviceCodeRepository
            .findValidByUserCodeForUpdate(domainId, userCode)
            .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));
    authThrottle.forgetDeviceCode(guessId);

    if (!deviceCode.isValid()) {
      throw new BadRequestException(ErrorCode.TOKEN_EXPIRED);
    }

    // Get user and authorize device code
    User user =
        userRepository
            .findActiveByIdAndDomain(domainId, userId)
            .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));

    // The first approval stands until the device collects its tokens (docs/LEDGER_*.md AUD-16):
    // a second account confirming the same code would otherwise swap itself in, and the device
    // would open on someone else's account. The same user confirming twice changes nothing.
    if (deviceCode.isAuthorized()) {
      User approver = deviceCode.getUser();
      if (approver != null && approver.getId().equals(userId)) {
        return;
      }
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }

    deviceCode.authorize(user);

    LOG.infov(
        "Device code authorized for user {0}, client={1}, user_code={2}",
        userId, deviceCode.getClientId(), userCode);
  }

  /**
   * Exchange device code for tokens. Returns error codes per RFC 8628 if not yet authorized.
   *
   * @param deviceCodeValue The device code to exchange
   * @return Token response if authorized
   * @throws BadRequestException with specific error codes for polling states
   */
  @Transactional
  @Public
  public DeviceTokenResponse exchangeDeviceCode(String deviceCodeValue) {
    String deviceCodeHash = hashToken(deviceCodeValue);
    DeviceCode deviceCode =
        deviceCodeRepository
            .findByDeviceCodeHash(deviceCodeHash)
            .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));

    if (!deviceCode.isValid()) {
      // Expired - delete it
      deviceCodeRepository.delete(deviceCode);
      throw new BadRequestException(ErrorCode.TOKEN_EXPIRED);
    }

    if (!deviceCode.isAuthorized() || deviceCode.getUser() == null) {
      // Not yet authorized - return authorization_pending error per RFC 8628
      throw new BadRequestException(ErrorCode.AUTHORIZATION_PENDING);
    }

    // Authorization successful - get user and delete code
    User user = deviceCode.getUser();
    String clientId = deviceCode.getClientId();
    deviceCodeRepository.delete(deviceCode);

    return createTokenResponse(user, clientId);
  }

  /**
   * Refresh an access token using a refresh token.
   *
   * @param refreshToken The refresh token
   * @param clientId The client identifier for the new access token
   * @return Token response with new access token
   */
  @Transactional
  @Public
  public DeviceTokenResponse refreshToken(String refreshToken, String clientId) {
    // Rotated like the site's and the app's (docs/LEDGER_*.md SEC-11, SEC-27): the device keeps the
    // refreshToken of the answer, and a device whose refresh raced another keeps the one it has.
    RefreshTokenRotation.Refresh refresh =
        refreshTokenRotation.refresh(
            refreshToken,
            session -> {
              if (!session.isValid()) {
                throw new BadRequestException(ErrorCode.SESSION_EXPIRED);
              }
            });
    if (refresh.outcome() == RefreshTokenRotation.Outcome.UNKNOWN) {
      throw new BadRequestException(ErrorCode.TOKEN_INVALID);
    }
    AuthSession session = Objects.requireNonNull(refresh.session());
    User user = session.getUser();

    return DeviceTokenResponse.builder()
        .accessToken(deviceJwtService.generateAccessToken(user, clientId, session.getId()))
        .tokenType("Bearer")
        .expiresIn(deviceJwtService.getAccessTokenExpirySeconds())
        .refreshToken(refresh.nextToken())
        .build();
  }

  /**
   * Look up device code by user code (for frontend display during verification).
   *
   * @param userCode The user code
   * @return Device code entity if valid, empty otherwise
   */
  @Public
  public Optional<DeviceCode> getDeviceCodeByUserCode(String userCode) {
    return deviceCodeRepository.findValidByUserCode(domainResolver.getDomainId(), userCode);
  }

  /**
   * The pending code {@code userCode} names on this domain, for the confirmation screen.
   *
   * <p>Anonymous, so only the domain's budget bounds it: without one, this lookup alone would find
   * the pending codes that completeDeviceCodeFlow then needs a single try to take (SEC-4).
   */
  @Transactional // takes back the guess of a known code (docs/LEDGER_*.md SEC-36)
  @Public
  public Optional<PendingDeviceCode> findPendingUserCode(String userCode) {
    Long domainId = domainResolver.getDomainId();
    Long guessId = authThrottle.admitDeviceCode(domainId, null);
    Optional<DeviceCode> deviceCode = deviceCodeRepository.findValidByUserCode(domainId, userCode);
    if (deviceCode.isPresent()) {
      authThrottle.forgetDeviceCode(guessId);
    }
    return deviceCode.map(
        code ->
            new PendingDeviceCode(code.isAuthorized(), code.getClientId(), code.getCreatedAt()));
  }

  /**
   * The signed-in user refused to pair the device showing {@code userCode} (docs/LEDGER_*.md
   * SEC-2). The code expires rather than disappears: the device polling {@code /token} then hears
   * {@code TOKEN_EXPIRED}, which Karoo and Garmin already handle by starting over, and whoever
   * sent the link cannot offer the same code to someone else. Unknown codes count like on {@link
   * #completeDeviceCodeFlow}.
   */
  @Transactional
  @Logged
  public void denyDeviceCodeFlow(String userCode) {
    Long userId = pedalonsQueryContext.getUserId();
    Long domainId = domainResolver.getDomainId();

    Long guessId = authThrottle.admitDeviceCode(domainId, userId);
    DeviceCode deviceCode =
        deviceCodeRepository
            .findValidByUserCode(domainId, userCode)
            .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));
    authThrottle.forgetDeviceCode(guessId);
    deviceCode.setExpiresAt(Instant.now());

    LOG.infov(
        "Device code denied by user {0}, client={1}, user_code={2}",
        userId, deviceCode.getClientId(), userCode);
  }

  private DeviceTokenResponse createTokenResponse(User user, String clientId) {
    String refreshToken = generateSecureToken();
    String refreshTokenHash = hashToken(refreshToken);

    // Create session with device-specific expiry
    AuthSession session =
        new AuthSession(
            user,
            refreshTokenHash,
            Instant.now().plus(Duration.ofDays(deviceJwtService.getRefreshTokenExpiryDays())));
    session.setUserAgent(clientId + " Device");
    session.setIpAddress("device");
    session.setDeviceClient(clientId);
    authSessionRepository.persist(session);
    // After the persist: the access token names the session, which unpairing revokes.
    String accessToken = deviceJwtService.generateAccessToken(user, clientId, session.getId());

    userRepository.recordLogin(user.getId());

    return DeviceTokenResponse.builder()
        .accessToken(accessToken)
        .tokenType("Bearer")
        .expiresIn(deviceJwtService.getAccessTokenExpirySeconds())
        .refreshToken(refreshToken)
        .build();
  }

  private String generateSecureToken() {
    byte[] bytes = new byte[32];
    SECURE_RANDOM.nextBytes(bytes);
    return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
  }

  private String generateUserCode() {
    StringBuilder code = new StringBuilder(USER_CODE_LENGTH);
    for (int i = 0; i < USER_CODE_LENGTH; i++) {
      int index = SECURE_RANDOM.nextInt(USER_CODE_CHARS.length());
      code.append(USER_CODE_CHARS.charAt(index));
    }
    return code.toString();
  }

  private String hashToken(String token) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      byte[] hash = digest.digest(token.getBytes(StandardCharsets.UTF_8));
      return Base64.getEncoder().encodeToString(hash);
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256 not available", e);
    }
  }
}
