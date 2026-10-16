package fr.pedalons.dto.users.export;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.auth.AuthSession;
import fr.pedalons.domain.auth.AuthToken;
import fr.pedalons.domain.auth.DeviceCode;
import fr.pedalons.domain.auth.Passkey;
import fr.pedalons.domain.auth.WebAuthnChallenge;
import fr.pedalons.domain.calendar.CalendarToken;
import fr.pedalons.domain.gps.GpsOAuthState;
import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.user.User;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * Account and authentication data, redacted.
 *
 * <p>The rule applied throughout: <b>anything that is a credential verifier is omitted; anything
 * that is an observation about the user is exported.</b> A SHA-256 of a live refresh token is still
 * credential material in a file the user may forward to themselves, so hashes go too — not just
 * plaintext secrets.
 */
public final class AccountExport {

  private AccountExport() {}

  /** {@code account/profile.json}. {@code passwordHash} is replaced by {@code hasPassword}. */
  public record Profile(
      String id,
      String email,
      String displayName,
      @Nullable String avatarUrl,
      @Nullable String unitSystem,
      @Nullable String theme,
      @Nullable String language,
      boolean emailVerified,
      @Nullable Instant emailVerifiedAt,
      @Nullable String platformRole,
      boolean hasPassword,
      boolean deleted,
      @Nullable Instant lastLoginAt,
      Instant createdAt,
      Instant updatedAt) {

    public static Profile from(User user) {
      return new Profile(
          TsidUtils.toString(user.getId()),
          user.getEmail(),
          user.getDisplayName(),
          user.getAvatarUrl(),
          user.getUnitSystem() == null ? null : user.getUnitSystem().name(),
          user.getTheme() == null ? null : user.getTheme().name(),
          user.getLanguage(),
          user.isEmailVerified(),
          user.getEmailVerifiedAt(),
          user.getPlatformRole() == null ? null : user.getPlatformRole().name(),
          user.getPasswordHash() != null,
          user.isDeleted(),
          user.getLastLoginAt(),
          user.getCreatedAt(),
          user.getUpdatedAt());
    }
  }

  /**
   * {@code account/sessions.json}. Omits {@code refreshTokenHash}.
   *
   * <p>{@code ipAddress} and {@code userAgent} are exported deliberately: under Article 15 an IP
   * address held about the data subject is their personal data, and these are among the few fields
   * a user might actually want to check.
   */
  public record Session(
      String id,
      Instant createdAt,
      @Nullable Instant lastUsedAt,
      Instant expiresAt,
      @Nullable String userAgent,
      @Nullable String ipAddress,
      boolean revoked,
      @Nullable Instant revokedAt) {

    public static Session from(AuthSession s) {
      return new Session(
          TsidUtils.toString(s.getId()),
          s.getCreatedAt(),
          s.getLastUsedAt(),
          s.getExpiresAt(),
          s.getUserAgent(),
          s.getIpAddress(),
          s.isRevoked(),
          s.getRevokedAt());
    }
  }

  /**
   * {@code account/passkeys.json}. Omits the raw {@code credentialId} and {@code publicKey}.
   *
   * <p>{@code credentialFingerprint} is a truncated digest of the credential id, present only so a
   * user can correlate an entry with a device. {@code aaguid} identifies the authenticator
   * <em>model</em> (e.g. "an iCloud Keychain passkey"), not the user, so it stays.
   */
  public record PasskeyEntry(
      String id,
      @Nullable String deviceName,
      @Nullable List<String> transports,
      long signCount,
      @Nullable String aaguid,
      String credentialFingerprint,
      Instant createdAt,
      @Nullable Instant lastUsedAt) {

    public static PasskeyEntry from(Passkey p) {
      byte[] aaguid = p.getAaguid();
      return new PasskeyEntry(
          TsidUtils.toString(p.getId()),
          p.getDeviceName(),
          p.getTransports(),
          p.getSignCount(),
          aaguid == null ? null : HexFormat.of().formatHex(aaguid),
          fingerprint(p.getCredentialId()),
          p.getCreatedAt(),
          p.getLastUsedAt());
    }

    private static String fingerprint(byte[] credentialId) {
      try {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(credentialId);
        return HexFormat.of().formatHex(digest, 0, 8);
      } catch (NoSuchAlgorithmException e) {
        throw new IllegalStateException("SHA-256 not available", e);
      }
    }
  }

  /**
   * {@code account/calendar-token.json}. Omits {@code token} — it is a bearer credential for the
   * user's entire calendar feed, and it is re-readable any time from {@code GET /api/calendar/token}.
   */
  public record CalendarTokenEntry(
      String id, boolean tokenPresent, Instant createdAt, Instant updatedAt) {

    public static CalendarTokenEntry from(CalendarToken t) {
      return new CalendarTokenEntry(
          TsidUtils.toString(t.getId()), true, t.getCreatedAt(), t.getUpdatedAt());
    }
  }

  /**
   * {@code account/gps-connections.json}. Omits both encrypted token blobs — they are decryptable
   * with the server key, so exporting them would hand out live third-party credentials.
   */
  public record GpsConnection(
      String id,
      String serviceType,
      @Nullable String externalUserId,
      boolean hasRefreshToken,
      @Nullable Instant tokenExpiresAt,
      Instant connectedAt,
      @Nullable Instant lastUsedAt,
      boolean autoSync,
      @Nullable Instant syncReconnectRequiredAt,
      Instant createdAt,
      Instant updatedAt) {

    public static GpsConnection from(GpsServiceConnection c) {
      return new GpsConnection(
          TsidUtils.toString(c.getId()),
          c.getServiceType().name(),
          c.getExternalUserId(),
          c.getRefreshTokenEncrypted() != null,
          c.getTokenExpiresAt(),
          c.getConnectedAt(),
          c.getLastUsedAt(),
          c.isAutoSync(),
          c.getSyncReconnectRequiredAt(),
          c.getCreatedAt(),
          c.getUpdatedAt());
    }
  }

  /**
   * {@code account/gps-route-syncs.json} — the routes Pédalons sent to the member's GPS services
   * and keeps track of (docs/LEDGER_*.md API-120): automatically for a ride, or a manual upload.
   */
  public record GpsRouteSyncEntry(
      String id,
      String serviceType,
      boolean automatic,
      @Nullable String rideId,
      @Nullable String rideGroupId,
      @Nullable String routeId,
      @Nullable String name,
      @Nullable Instant groupStartAt,
      @Nullable String externalRouteId,
      @Nullable Instant syncedAt,
      @Nullable String lastError,
      @Nullable Instant lastErrorAt,
      Instant createdAt,
      Instant updatedAt) {

    public static GpsRouteSyncEntry from(GpsRouteSync s) {
      return new GpsRouteSyncEntry(
          TsidUtils.toString(s.getId()),
          s.getConnection().getServiceType().name(),
          s.isAutomatic(),
          s.getRideId() != null ? TsidUtils.toString(s.getRideId()) : null,
          s.getRideGroupId() != null ? TsidUtils.toString(s.getRideGroupId()) : null,
          s.getDesiredRouteId() != null ? TsidUtils.toString(s.getDesiredRouteId()) : null,
          s.getDesiredName(),
          s.getGroupStartAt(),
          s.getExternalRouteId(),
          s.getSyncedAt(),
          s.getLastError() != null ? s.getLastError().name() : null,
          s.getLastErrorAt(),
          s.getCreatedAt(),
          s.getUpdatedAt());
    }
  }

  /**
   * {@code account/auth-tokens.json} — one-time email/OTP/reset tokens. Omits {@code tokenHash}.
   */
  public record AuthTokenEntry(
      String id,
      String email,
      String tokenType,
      @Nullable String pendingDisplayName,
      Instant createdAt,
      Instant expiresAt,
      @Nullable Instant usedAt) {

    public static AuthTokenEntry from(AuthToken t) {
      return new AuthTokenEntry(
          TsidUtils.toString(t.getId()),
          t.getEmail(),
          t.getTokenType().name(),
          t.getPendingDisplayName(),
          t.getCreatedAt(),
          t.getExpiresAt(),
          t.getUsedAt());
    }
  }

  /**
   * {@code account/device-codes.json} — device-flow pairings (Garmin, Karoo). Omits {@code
   * deviceCodeHash} and {@code userCode}; the user code is a claim credential while the row is live.
   */
  public record DeviceCodeEntry(
      String id, String clientId, boolean authorized, Instant createdAt, Instant expiresAt) {

    public static DeviceCodeEntry from(DeviceCode c) {
      return new DeviceCodeEntry(
          TsidUtils.toString(c.getId()),
          c.getClientId(),
          c.isAuthorized(),
          c.getCreatedAt(),
          c.getExpiresAt());
    }
  }

  /**
   * {@code account/oauth-states.json} — short-lived in-flight handshake rows, both kinds in one file.
   * Each omits its secret: the CSRF {@code state} and PKCE {@code codeVerifier}, and the WebAuthn
   * {@code challenge}.
   */
  public record HandshakeState(
      String kind,
      String id,
      @Nullable String provider,
      @Nullable String purpose,
      @Nullable String redirectUri,
      Instant createdAt,
      Instant expiresAt,
      @Nullable Instant usedAt) {

    public static HandshakeState from(GpsOAuthState s) {
      return new HandshakeState(
          "gps-oauth",
          TsidUtils.toString(s.getId()),
          s.getServiceType().name(),
          null,
          s.getRedirectUri(),
          s.getCreatedAt(),
          s.getExpiresAt(),
          null);
    }

    public static HandshakeState from(WebAuthnChallenge c) {
      return new HandshakeState(
          "webauthn-challenge",
          TsidUtils.toString(c.getId()),
          null,
          c.getChallengeType().name(),
          null,
          c.getCreatedAt(),
          c.getExpiresAt(),
          null);
    }
  }
}
