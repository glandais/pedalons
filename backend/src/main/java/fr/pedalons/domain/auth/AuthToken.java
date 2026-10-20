package fr.pedalons.domain.auth;

import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AuthTokenType;
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
@Table(name = "auth_tokens")
@NoArgsConstructor
public class AuthToken {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id")
  private @Nullable User user;

  @Column(name = "email", nullable = false, length = 250)
  private String email;

  @Column(name = "token_hash", nullable = false, unique = true, length = 100)
  private String tokenHash;

  @Enumerated(EnumType.STRING)
  @Column(name = "token_type", nullable = false, length = 20)
  private AuthTokenType tokenType;

  @Column(name = "expires_at", nullable = false)
  private Instant expiresAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  @Column(name = "used_at")
  private @Nullable Instant usedAt;

  @Column(name = "pending_display_name", length = 250)
  private @Nullable String pendingDisplayName;

  @Column(name = "pending_domain_id")
  private @Nullable Long pendingDomainId;

  /**
   * When the sign-up form's terms checkbox was accepted — set by register, copied to the account by
   * verifyEmail. Null on a verification token issued before the form asked: the account it creates
   * records no consent that was never given.
   */
  @Column(name = "pending_terms_accepted_at")
  private @Nullable Instant pendingTermsAcceptedAt;

  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  /** Wrong codes tried against this token — only a login OTP counts them. */
  @Column(name = "failed_attempts", nullable = false)
  private int failedAttempts;

  public AuthToken(
      String email, String tokenHash, AuthTokenType tokenType, Instant expiresAt, Long domainId) {
    this.email = email;
    this.tokenHash = tokenHash;
    this.tokenType = tokenType;
    this.expiresAt = expiresAt;
    this.domainId = domainId;
  }

  public AuthToken(
      User user,
      String email,
      String tokenHash,
      AuthTokenType tokenType,
      Instant expiresAt,
      Long domainId) {
    this.user = user;
    this.email = email;
    this.tokenHash = tokenHash;
    this.tokenType = tokenType;
    this.expiresAt = expiresAt;
    this.domainId = domainId;
  }

  public void markUsed() {
    this.usedAt = Instant.now();
  }

  /** Records a wrong code, and burns the token once {@code maxAttempts} have been tried. */
  public void recordFailedAttempt(int maxAttempts) {
    failedAttempts++;
    if (failedAttempts >= maxAttempts) {
      markUsed();
    }
  }

  public boolean isValid() {
    return usedAt == null && expiresAt.isAfter(Instant.now());
  }
}
