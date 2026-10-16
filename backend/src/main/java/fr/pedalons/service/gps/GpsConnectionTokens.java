package fr.pedalons.service.gps;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.GpsOAuthVersion;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.gps.GarminClient;
import fr.pedalons.infrastructure.gps.GarminOAuth1Client;
import fr.pedalons.infrastructure.gps.GpsAuth;
import fr.pedalons.infrastructure.gps.GpsServiceClient;
import fr.pedalons.infrastructure.gps.HammerheadClient;
import fr.pedalons.infrastructure.gps.TokenResponse;
import fr.pedalons.infrastructure.gps.WahooClient;
import fr.pedalons.infrastructure.security.TokenEncryptionService;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.Arrays;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * A connection's tokens made usable: decrypted, refreshed when expired (OAuth 2.0), turned into the
 * {@link GpsAuth} the route calls take. With the credential passed explicitly, never resolved from
 * the request — the background route sync (docs/LEDGER_*.md API-120) has none.
 *
 * <p>Every method works on a <b>managed</b> connection, in the caller's transaction, which should
 * do nothing else that may fail: the refreshed tokens are stored only when it commits, and a
 * provider that rotates its refresh tokens (Wahoo) has already invalidated the old one by then.
 * Refreshes are <b>serialised per connection</b>: the row is locked ({@code SELECT … FOR UPDATE})
 * and re-read before the token endpoint is called, so a second caller — another worker thread, the
 * other backend of a rolling deploy, a manual upload — waits, then finds the token already
 * refreshed and uses it instead of spending the same refresh token a second time. {@link
 * #forceRefresh} likewise recognises a token another caller already replaced.
 */
@ApplicationScoped
public class GpsConnectionTokens {

  private static final Logger LOG = Logger.getLogger(GpsConnectionTokens.class);

  @Inject TokenEncryptionService encryptionService;
  @Inject GpsServiceConnectionRepository connectionRepository;
  @Inject DomainGpsCredentialService credentialService;
  @Inject HammerheadClient hammerheadClient;
  @Inject GarminClient garminClient;
  @Inject WahooClient wahooClient;

  public GpsServiceClient client(GpsServiceType serviceType) {
    return switch (serviceType) {
      case HAMMERHEAD -> hammerheadClient;
      case GARMIN -> garminClient;
      case WAHOO -> wahooClient;
    };
  }

  /**
   * Whether the connection's tokens belong to the protocol of the domain's credential. When the
   * domain switched (Garmin, OAuth 2.0 ↔ 1.0a), they are worthless: only a reconnection helps.
   */
  public static boolean matches(GpsServiceConnection connection, DomainGpsCredential credential) {
    return connection.oauthVersion() == credential.getOauthVersion();
  }

  /**
   * The authorization for the connection's next call, its OAuth 2.0 token refreshed first when it
   * expires within five minutes and can be.
   */
  public GpsAuth auth(GpsServiceConnection connection, DomainGpsCredential credential) {
    if (connection.oauthVersion() == GpsOAuthVersion.OAUTH1) {
      return oauth1(connection, credential);
    }
    if (connection.isTokenExpired() && connection.getRefreshTokenEncrypted() != null) {
      lock(connection);
      // Checked again under the lock: whoever held it may have refreshed it.
      if (connection.isTokenExpired() && connection.getRefreshTokenEncrypted() != null) {
        refresh(connection, credential);
      }
    }
    return bearer(connection);
  }

  /** Locks the connection's row and re-reads it: what another transaction committed is seen. */
  private void lock(GpsServiceConnection connection) {
    connectionRepository.getEntityManager().refresh(connection, LockModeType.PESSIMISTIC_WRITE);
  }

  /**
   * After a 401: a fresh token. If the connection's token is no longer the one {@code used}
   * carried, another caller refreshed it meanwhile and that one is returned as is. Null when it
   * cannot be refreshed (OAuth 1.0a, no refresh token): the caller asks for a reconnection.
   *
   * @throws RuntimeException when the service refuses the refresh
   */
  public @Nullable GpsAuth forceRefresh(
      GpsServiceConnection connection, DomainGpsCredential credential, byte[] used) {
    if (connection.oauthVersion() == GpsOAuthVersion.OAUTH1) {
      return null;
    }
    lock(connection);
    if (!Arrays.equals(connection.getAccessTokenEncrypted(), used)) {
      return bearer(connection);
    }
    if (connection.getRefreshTokenEncrypted() == null) {
      return null;
    }
    refresh(connection, credential);
    return bearer(connection);
  }

  /** Exchanges the refresh token for new tokens and stores them on the (managed) connection. */
  public void refresh(GpsServiceConnection connection, DomainGpsCredential credential) {
    byte[] refreshTokenEncrypted = connection.getRefreshTokenEncrypted();
    if (refreshTokenEncrypted == null) {
      return;
    }
    String refreshToken = encryptionService.decrypt(refreshTokenEncrypted);
    TokenResponse tokens =
        client(connection.getServiceType()).refreshToken(credential, refreshToken);

    connection.setAccessTokenEncrypted(encryptionService.encrypt(tokens.accessToken()));
    if (tokens.refreshToken() != null) {
      connection.setRefreshTokenEncrypted(encryptionService.encrypt(tokens.refreshToken()));
    }
    if (tokens.expiresIn() != null) {
      connection.setTokenExpiresAt(Instant.now().plusSeconds(tokens.expiresIn()));
    }
    connectionRepository.persist(connection);
    LOG.infof(
        "Refreshed access token for user %d on %s",
        connection.getUser().getId(), connection.getServiceType());
  }

  private GpsAuth bearer(GpsServiceConnection connection) {
    return new GpsAuth.Bearer(encryptionService.decrypt(connection.getAccessTokenEncrypted()));
  }

  private GpsAuth oauth1(GpsServiceConnection connection, DomainGpsCredential credential) {
    byte[] secret = connection.getAccessTokenSecretEncrypted();
    String consumerSecret = credentialService.getDecryptedClientSecret(credential);
    if (secret == null || consumerSecret == null) {
      throw new BusinessException(ErrorCode.GPS_SERVICE_NOT_CONFIGURED);
    }
    return GarminOAuth1Client.auth(
        credential,
        consumerSecret,
        encryptionService.decrypt(connection.getAccessTokenEncrypted()),
        encryptionService.decrypt(secret));
  }
}
