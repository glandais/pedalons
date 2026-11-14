package fr.pedalons.service.oauth;

import static fr.pedalons.common.TokenUtils.constantTimeEquals;
import static fr.pedalons.common.TokenUtils.generateSecureToken;
import static fr.pedalons.common.TokenUtils.hashToken;

import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.domain.auth.AuthSession;
import fr.pedalons.domain.auth.OAuthAuthorizationCode;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.oauth.OAuthAuthorizeRequest;
import fr.pedalons.dto.oauth.OAuthAuthorizeResponse;
import fr.pedalons.dto.oauth.OAuthTokenResponse;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.repository.auth.OAuthAuthorizationCodeRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.auth.RefreshTokenRotation;
import fr.pedalons.service.device.DeviceJwtService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Locale;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;
import org.eclipse.microprofile.jwt.JsonWebToken;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The OAuth 2.0 authorization code flow (RFC 6749 §4.1) with PKCE (RFC 7636) that lets an external
 * application call the API for a member — docs/LEDGER_*.md API-199.
 *
 * <ol>
 *   <li>The application sends the browser to the site's {@code /oauth/authorize} with {@code
 *       client_id}, {@code redirect_uri}, {@code state} and a PKCE {@code code_challenge}
 *   <li>The member signs in if needed, reads who asks and where the code goes, presses « Autoriser »
 *   <li>The site calls {@link #authorize} and sends the browser to the returned URL
 *   <li>The application exchanges the code with its {@code code_verifier} ({@link #exchangeCode}),
 *       then keeps its access alive with the refresh token ({@link #refresh})
 * </ol>
 *
 * <p>Deliberately minimal. Applications are not registered: {@code client_id} is a name the
 * application gives itself, there is no client secret, and {@code redirect_uri} is not checked
 * against anything — any URL or deep link is accepted. Two things stand in for the registration:
 * the consent screen shows the member where the code is going, and PKCE is mandatory, so a code
 * that reaches the wrong hands is worth nothing without the verifier that never left the
 * application. There are no scopes: the tokens give what the member's own session gives.
 *
 * <p>The access it opens is a session like a paired device's ({@link AuthSession#getDeviceClient}
 * = {@code oauth:<client_id>}): listed with the devices in the profile, revoked from there, and
 * refused at once afterwards by {@code DeviceSessionFilter}.
 */
@ApplicationScoped
public class OAuthService {

  private static final Logger LOG = Logger.getLogger(OAuthService.class);

  /** RFC 6749 §4.1.2 recommends ten minutes at most; the exchange follows the redirection. */
  private static final Duration CODE_EXPIRY = Duration.ofMinutes(5);

  /**
   * Schemes a browser runs or reads locally instead of navigating to: the site assigns the
   * returned URL to {@code window.location}, where {@code javascript:} would run in its origin.
   * Everything else — https, http, any application's own scheme — is accepted.
   */
  private static final Set<String> FORBIDDEN_SCHEMES =
      Set.of("javascript", "data", "vbscript", "blob", "file", "about");

  /**
   * Control and format characters (line breaks, bidi overrides, zero-width): what the member reads
   * on the consent screen must be what was sent, and a name ends up in the logs.
   */
  private static final Pattern INVISIBLE = Pattern.compile("[\\p{Cc}\\p{Cf}]");

  /** RFC 7636 §4.1: 43 to 128 unreserved characters. */
  private static final Pattern CODE_VERIFIER = Pattern.compile("^[A-Za-z0-9._~-]{43,128}$");

  @Inject OAuthAuthorizationCodeRepository authorizationCodeRepository;
  @Inject AuthSessionRepository authSessionRepository;
  @Inject UserRepository userRepository;
  @Inject DeviceJwtService deviceJwtService;
  @Inject RefreshTokenRotation refreshTokenRotation;
  @Inject DomainResolver domainResolver;
  @Inject PedalonsQueryContext pedalonsQueryContext;
  @Inject JsonWebToken jwt;

  /**
   * The signed-in member approved the request: mints the code and builds where the browser goes.
   */
  @Transactional
  @Logged
  public OAuthAuthorizeResponse authorize(OAuthAuthorizeRequest request) {
    // The approval is the member's, on the site: a token that names a session is an
    // application's or a device's, and one of those approving the next would make a consent
    // given once renew itself without anyone pressing anything.
    if (jwt.getClaim(DeviceJwtService.SESSION_CLAIM) != null) {
      throw new ForbiddenException();
    }
    Long domainId = domainResolver.getDomainId();
    Long userId = pedalonsQueryContext.getUserId();
    String clientId = request.clientId().trim();
    String redirectUri = request.redirectUri().trim();
    if (INVISIBLE.matcher(clientId).find()) {
      throw new BadRequestException(ErrorCode.BAD_REQUEST);
    }
    checkRedirectUri(redirectUri);

    User user =
        userRepository
            .findActiveByIdAndDomain(domainId, userId)
            .orElseThrow(() -> new BadRequestException(ErrorCode.TOKEN_INVALID));

    String code = generateSecureToken();
    authorizationCodeRepository.persist(
        new OAuthAuthorizationCode(
            hashToken(code),
            clientId,
            redirectUri,
            request.codeChallenge(),
            domainId,
            user,
            Instant.now().plus(CODE_EXPIRY)));

    LOG.infov("OAuth authorization granted by user {0} to client={1}", userId, clientId);

    return new OAuthAuthorizeResponse(withCode(redirectUri, code, request.state()));
  }

  /**
   * Exchanges an authorization code for tokens. Empty for anything that is not this application's
   * live code — unknown, expired, another site's, another {@code client_id} or {@code
   * redirect_uri}, a wrong verifier: the caller answers {@code invalid_grant} to all of them alike.
   * A code that is found is deleted whatever follows, so one failed attempt burns it.
   */
  @Transactional
  @Public
  public Optional<OAuthTokenResponse> exchangeCode(
      String code, String clientId, String redirectUri, String codeVerifier) {
    Optional<OAuthAuthorizationCode> found =
        authorizationCodeRepository.findByCodeHashForUpdate(hashToken(code));
    if (found.isEmpty()) {
      return Optional.empty();
    }
    OAuthAuthorizationCode authorizationCode = found.get();
    authorizationCodeRepository.delete(authorizationCode);

    User user = authorizationCode.getUser();
    if (!authorizationCode.isValid()
        || !authorizationCode.getDomainId().equals(domainResolver.getDomainId())
        || !authorizationCode.getClientId().equals(clientId.trim())
        || !authorizationCode.getRedirectUri().equals(redirectUri.trim())
        || !CODE_VERIFIER.matcher(codeVerifier).matches()
        || !constantTimeEquals(challengeOf(codeVerifier), authorizationCode.getCodeChallenge())
        || user.isDeleted()) {
      return Optional.empty();
    }

    String sessionClient = AuthSession.OAUTH_CLIENT_PREFIX + authorizationCode.getClientId();
    String refreshToken = generateSecureToken();
    AuthSession session =
        new AuthSession(
            user,
            hashToken(refreshToken),
            Instant.now().plus(Duration.ofDays(deviceJwtService.getRefreshTokenExpiryDays())));
    session.setUserAgent(authorizationCode.getClientId() + " (OAuth)");
    session.setIpAddress("oauth");
    session.setDeviceClient(sessionClient);
    authSessionRepository.persist(session);
    userRepository.recordLogin(user.getId());

    LOG.infov(
        "OAuth session opened for user {0}, client={1}",
        user.getId(), authorizationCode.getClientId());

    // After the persist: the access token names the session, which revoking it ends at once.
    return Optional.of(
        tokenResponse(
            deviceJwtService.generateAccessToken(user, sessionClient, session.getId()),
            refreshToken));
  }

  /**
   * Renews the access of a session this flow opened. Empty for anything else: an unknown token, a
   * session revoked or expired, another site's, or one of the site, the app or a device — those
   * refresh where they were opened.
   */
  @Transactional
  @Public
  public Optional<OAuthTokenResponse> refresh(String refreshToken) {
    Long domainId = domainResolver.getDomainId();
    RefreshTokenRotation.Refresh refresh;
    try {
      // The check runs before anything is written, and never leaves this method: the transaction
      // has nothing to roll back.
      refresh =
          refreshTokenRotation.refresh(
              refreshToken,
              session -> {
                if (!isRefreshable(session, domainId)) {
                  throw new NotRefreshable();
                }
              });
    } catch (NotRefreshable e) {
      return Optional.empty();
    }
    if (refresh.outcome() == RefreshTokenRotation.Outcome.UNKNOWN) {
      return Optional.empty();
    }
    AuthSession session = Objects.requireNonNull(refresh.session());
    return Optional.of(
        tokenResponse(
            deviceJwtService.generateAccessToken(
                session.getUser(),
                Objects.requireNonNull(session.getDeviceClient()),
                session.getId()),
            refresh.nextToken()));
  }

  private static boolean isRefreshable(AuthSession session, Long domainId) {
    User user = session.getUser();
    return session.isValid()
        && session.isOAuthApplication()
        && !user.isDeleted()
        && user.getDomain().getId().equals(domainId);
  }

  private OAuthTokenResponse tokenResponse(String accessToken, @Nullable String refreshToken) {
    return new OAuthTokenResponse(
        accessToken, "Bearer", deviceJwtService.getAccessTokenExpirySeconds(), refreshToken);
  }

  /**
   * An absolute URI without a fragment (RFC 6749 §3.1.2), whose scheme a browser navigates to,
   * and that reads as what it is: no invisible character, no {@code user@} before the host
   * ({@code https://pedalons.fr@elsewhere.example/} goes elsewhere). That is all: which host or
   * application it names is the member's call, on the consent screen.
   */
  private static void checkRedirectUri(String redirectUri) {
    if (INVISIBLE.matcher(redirectUri).find()) {
      throw new BadRequestException(ErrorCode.BAD_REQUEST);
    }
    URI uri;
    try {
      uri = new URI(redirectUri);
    } catch (URISyntaxException e) {
      throw new BadRequestException(ErrorCode.BAD_REQUEST, e);
    }
    String scheme = uri.getScheme();
    if (scheme == null
        || uri.getRawFragment() != null
        || uri.getRawUserInfo() != null
        || FORBIDDEN_SCHEMES.contains(scheme.toLowerCase(Locale.ROOT))) {
      throw new BadRequestException(ErrorCode.BAD_REQUEST);
    }
  }

  /** Appended as text: a deep link is not always a URL a builder would take apart and rebuild. */
  private static String withCode(String redirectUri, String code, @Nullable String state) {
    StringBuilder url = new StringBuilder(redirectUri);
    url.append(redirectUri.contains("?") ? '&' : '?').append("code=").append(encode(code));
    if (state != null) {
      url.append("&state=").append(encode(state));
    }
    return url.toString();
  }

  private static String encode(String value) {
    return URLEncoder.encode(value, StandardCharsets.UTF_8);
  }

  /** {@code BASE64URL(SHA-256(ASCII(code_verifier)))}, RFC 7636 §4.2. */
  private static String challengeOf(String codeVerifier) {
    try {
      byte[] digest =
          MessageDigest.getInstance("SHA-256")
              .digest(codeVerifier.getBytes(StandardCharsets.US_ASCII));
      return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256 not available", e);
    }
  }

  private static final class NotRefreshable extends RuntimeException {
    private static final long serialVersionUID = 1L;
  }
}
