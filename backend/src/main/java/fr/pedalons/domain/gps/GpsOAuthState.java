package fr.pedalons.domain.gps;

import fr.pedalons.domain.user.User;
import fr.pedalons.enums.GpsConnectReturn;
import fr.pedalons.enums.GpsServiceType;
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
@Table(name = "gps_oauth_states")
@NoArgsConstructor
public class GpsOAuthState {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Column(name = "state", nullable = false, unique = true, length = 100)
  private String state;

  @Enumerated(EnumType.STRING)
  @Column(name = "service_type", nullable = false, length = 20)
  private GpsServiceType serviceType;

  @Column(name = "expires_at", nullable = false)
  private Instant expiresAt;

  @Column(name = "code_verifier", length = 200)
  private @Nullable String codeVerifier;

  /**
   * OAuth 1.0a only: the secret of the request token, which is then held in {@link #state} — the
   * callback names the request token, not a state of ours.
   */
  @Column(name = "request_token_secret_encrypted", columnDefinition = "bytea")
  private byte @Nullable [] requestTokenSecretEncrypted;

  @Column(name = "redirect_uri", nullable = false, length = 500)
  private String redirectUri;

  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  /** {@code null} on rows written before API-63: read as {@link GpsConnectReturn#PROFILE}. */
  @Enumerated(EnumType.STRING)
  @Column(name = "return_to", length = 20)
  private @Nullable GpsConnectReturn returnTo;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  public GpsOAuthState(
      User user,
      String state,
      GpsServiceType serviceType,
      Instant expiresAt,
      @Nullable String codeVerifier,
      String redirectUri,
      Long domainId,
      GpsConnectReturn returnTo) {
    this.user = user;
    this.state = state;
    this.serviceType = serviceType;
    this.expiresAt = expiresAt;
    this.codeVerifier = codeVerifier;
    this.redirectUri = redirectUri;
    this.domainId = domainId;
    this.returnTo = returnTo;
  }

  public boolean isValid() {
    return expiresAt.isAfter(Instant.now());
  }
}
