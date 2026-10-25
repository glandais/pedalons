package fr.pedalons.domain.auth;

import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

/**
 * Entity for device code OAuth flow (RFC 8628). Stores pending device authorizations for GPS
 * devices (Karoo, Garmin, etc.).
 */
@Setter
@Getter
@Entity
@Table(name = "device_codes")
@NoArgsConstructor
public class DeviceCode {

  @Id @Tsid private Long id;

  /** SHA-256 hash of the device code (secret used for polling). */
  @Column(name = "device_code_hash", nullable = false, unique = true, length = 100)
  private String deviceCodeHash;

  /** Human-readable code displayed on device (e.g., "ABC123"). */
  @Column(name = "user_code", nullable = false, unique = true, length = 10)
  private String userCode;

  /** Client identifier (e.g., "karoo", "garmin"). */
  @Column(name = "client_id", nullable = false, length = 50)
  private String clientId;

  /** Domain ID for multi-tenancy. */
  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  /** User who authorized this device code. Null until authorization completes. */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id")
  private @Nullable User user;

  /** Whether the user has completed authorization. */
  @Column(name = "authorized", nullable = false)
  private boolean authorized = false;

  /** When this device code expires. */
  @Column(name = "expires_at", nullable = false)
  private Instant expiresAt;

  /** When this device code was created. */
  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  public DeviceCode(
      String deviceCodeHash, String userCode, String clientId, Long domainId, Instant expiresAt) {
    this.deviceCodeHash = deviceCodeHash;
    this.userCode = userCode;
    this.clientId = clientId;
    this.domainId = domainId;
    this.expiresAt = expiresAt;
  }

  /** Mark this device code as authorized by the given user. */
  public void authorize(User user) {
    this.user = user;
    this.authorized = true;
  }

  /** Check if this device code is still valid (not expired). */
  public boolean isValid() {
    return expiresAt.isAfter(Instant.now());
  }
}
