package fr.pedalons.domain.auth;

import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@Table(name = "auth_sessions")
@NoArgsConstructor
public class AuthSession {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Column(name = "refresh_token_hash", nullable = false, length = 100)
  private String refreshTokenHash;

  /**
   * The token this session held before its last refresh, still honoured for a short grace so that
   * refreshes already in flight (other tabs, the SSR, an app resuming) do not end the session.
   * Presented after that grace, the response carrying its successor was lost: it rotates again,
   * and stays the previous token (docs/LEDGER_*.md SEC-27, API-94).
   */
  @Column(name = "previous_refresh_token_hash", length = 100)
  private @Nullable String previousRefreshTokenHash;

  /** When the refresh token was last rotated — the start of the previous token's grace. */
  @Column(name = "rotated_at")
  private @Nullable Instant rotatedAt;

  @Column(name = "expires_at", nullable = false)
  private Instant expiresAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  @Column(name = "last_used_at")
  private @Nullable Instant lastUsedAt;

  @Column(name = "user_agent", length = 500)
  private @Nullable String userAgent;

  @Column(name = "ip_address", length = 45)
  private @Nullable String ipAddress;

  /**
   * The {@code clientId} of the device whose pairing opened this session ({@code karoo},
   * {@code garmin}…), null for the site and the app. What lists paired devices (docs/LEDGER_*.md
   * API-64) — never parse {@link #userAgent} for it.
   */
  @Column(name = "device_client", length = 50)
  private @Nullable String deviceClient;

  @Column(name = "revoked", nullable = false)
  private boolean revoked = false;

  @Column(name = "revoked_at")
  private @Nullable Instant revokedAt;

  public AuthSession(User user, String refreshTokenHash, Instant expiresAt) {
    this.user = user;
    this.refreshTokenHash = refreshTokenHash;
    this.expiresAt = expiresAt;
  }

  public void revoke() {
    this.revoked = true;
    this.revokedAt = Instant.now();
  }

  public boolean isValid() {
    return !revoked && expiresAt.isAfter(Instant.now());
  }
}
