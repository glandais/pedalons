package fr.pedalons.domain.gps;

import fr.pedalons.domain.user.User;
import fr.pedalons.enums.GpsOAuthVersion;
import fr.pedalons.enums.GpsServiceType;
import io.hypersistence.utils.hibernate.id.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@Table(name = "gps_service_connections")
@NoArgsConstructor
public class GpsServiceConnection {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Enumerated(EnumType.STRING)
  @Column(name = "service_type", nullable = false, length = 20)
  private GpsServiceType serviceType;

  @Column(name = "access_token_encrypted", nullable = false, columnDefinition = "bytea")
  private byte[] accessTokenEncrypted;

  /**
   * OAuth 1.0a only: the access token's secret, which signs every request. Its presence is what
   * makes this an OAuth 1.0a connection; such a token neither expires nor refreshes.
   */
  @Column(name = "access_token_secret_encrypted", columnDefinition = "bytea")
  private byte @Nullable [] accessTokenSecretEncrypted;

  @Column(name = "refresh_token_encrypted", columnDefinition = "bytea")
  private byte @Nullable [] refreshTokenEncrypted;

  @Column(name = "token_expires_at")
  private @Nullable Instant tokenExpiresAt;

  @Column(name = "external_user_id", length = 100)
  private @Nullable String externalUserId;

  @Column(name = "connected_at", nullable = false)
  private Instant connectedAt;

  @Column(name = "last_used_at")
  private @Nullable Instant lastUsedAt;

  /**
   * Whether the member asked for the routes of their rides to be sent to this service
   * automatically, and kept in sync (docs/LEDGER_*.md API-120 D1). Per connection: it leaves with
   * the connection.
   */
  @Column(name = "auto_sync", nullable = false)
  private boolean autoSync;

  /**
   * Set when the service refused our token even after a refresh, or (Garmin) the permission was
   * withdrawn: the synchronisation stops for this connection, its rows stay as they are, until a
   * reconnection clears it.
   *
   * <p>This column and the next are written <b>only by bulk updates</b> ({@code
   * GpsServiceConnectionRepository#markSyncReconnectRequired}, {@code #pauseSync}, {@code
   * #clearSyncBlocks}), never by the entity ({@code updatable = false}): the worker sets them while
   * an endpoint, or the other backend, may hold the entity, and the flush of that stale copy would
   * otherwise put the old value back — {@code @Version} does not see a bulk update.
   */
  @Column(name = "sync_reconnect_required_at", updatable = false)
  private @Nullable Instant syncReconnectRequiredAt;

  /** After a 429: no synchronisation call for this connection before then. Bulk-written only. */
  @Column(name = "sync_paused_until", updatable = false)
  private @Nullable Instant syncPausedUntil;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @Version private Long version;

  public GpsServiceConnection(User user, GpsServiceType serviceType) {
    this.user = user;
    this.serviceType = serviceType;
    this.connectedAt = Instant.now();
  }

  public boolean isTokenExpired() {
    if (tokenExpiresAt == null) {
      return false;
    }
    // Consider expired if less than 5 minutes remaining
    return Instant.now().plusSeconds(300).isAfter(tokenExpiresAt);
  }

  /** The protocol this connection's tokens were obtained with. */
  public GpsOAuthVersion oauthVersion() {
    return accessTokenSecretEncrypted != null ? GpsOAuthVersion.OAUTH1 : GpsOAuthVersion.OAUTH2;
  }

  public void markUsed() {
    this.lastUsedAt = Instant.now();
  }
}
