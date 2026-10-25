package fr.pedalons.domain.gps;

import fr.pedalons.domain.platform.Domain;
import fr.pedalons.enums.GpsOAuthVersion;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.jspecify.annotations.Nullable;

/**
 * Stores GPS service OAuth credentials (client_id/client_secret) per domain.
 * Enables white-label GPS integrations where each domain has its own OAuth app.
 */
@Setter
@Getter
@Entity
@Table(
    name = "domain_gps_credentials",
    uniqueConstraints = @UniqueConstraint(columnNames = {"domain_id", "service_type"}))
@NoArgsConstructor
public class DomainGpsCredential {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  @Enumerated(EnumType.STRING)
  @Column(name = "service_type", nullable = false, length = 20)
  private GpsServiceType serviceType;

  @Column(name = "client_id", nullable = false, length = 255)
  private String clientId;

  /**
   * Encrypted client secret (the consumer secret for OAuth 1.0a). Every client this backend talks
   * to requires one, Garmin's PKCE flow included.
   */
  @Column(name = "client_secret_encrypted", columnDefinition = "bytea")
  private byte @Nullable [] clientSecretEncrypted;

  /**
   * Which OAuth protocol {@link #clientId} and the secret belong to — for OAuth 1.0a they are the
   * consumer key and secret. Only Garmin may be {@link GpsOAuthVersion#OAUTH1}.
   */
  @Enumerated(EnumType.STRING)
  @Column(name = "oauth_version", nullable = false, length = 10)
  private GpsOAuthVersion oauthVersion = GpsOAuthVersion.OAUTH2;

  @Column(name = "active", nullable = false)
  private boolean active = true;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @Version private Long version;

  public DomainGpsCredential(Domain domain, GpsServiceType serviceType, String clientId) {
    this.domain = domain;
    this.serviceType = serviceType;
    this.clientId = clientId;
  }
}
