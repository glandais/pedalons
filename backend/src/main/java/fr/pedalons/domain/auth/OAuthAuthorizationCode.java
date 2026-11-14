package fr.pedalons.domain.auth;

import fr.pedalons.domain.user.User;
import io.hypersistence.utils.hibernate.id.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * An authorization code of the OAuth 2.0 authorization code flow (RFC 6749 §4.1), bound to the
 * PKCE challenge (RFC 7636) the application sent with its request — docs/LEDGER_*.md API-199.
 * Single use and short-lived: the exchange deletes it, whatever its outcome.
 */
@Setter
@Getter
@Entity
@Table(name = "oauth_authorization_codes")
@NoArgsConstructor
public class OAuthAuthorizationCode {

  @Id @Tsid private Long id;

  /** SHA-256 hash of the code handed to the application through the redirection. */
  @Column(name = "code_hash", nullable = false, unique = true, length = 100)
  private String codeHash;

  /** The name the application gave itself: nothing registers it, nothing vouches for it. */
  @Column(name = "client_id", nullable = false, length = 40)
  private String clientId;

  /** Where the code was sent: the exchange must repeat it exactly (RFC 6749 §4.1.3). */
  @Column(name = "redirect_uri", nullable = false, length = 2000)
  private String redirectUri;

  /** {@code BASE64URL(SHA-256(code_verifier))}: only who sent the request can redeem the code. */
  @Column(name = "code_challenge", nullable = false, length = 100)
  private String codeChallenge;

  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Column(name = "expires_at", nullable = false)
  private Instant expiresAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  public OAuthAuthorizationCode(
      String codeHash,
      String clientId,
      String redirectUri,
      String codeChallenge,
      Long domainId,
      User user,
      Instant expiresAt) {
    this.codeHash = codeHash;
    this.clientId = clientId;
    this.redirectUri = redirectUri;
    this.codeChallenge = codeChallenge;
    this.domainId = domainId;
    this.user = user;
    this.expiresAt = expiresAt;
  }

  public boolean isValid() {
    return expiresAt.isAfter(Instant.now());
  }
}
