package fr.pedalons.domain.auth;

import fr.pedalons.domain.user.User;
import fr.pedalons.enums.WebAuthnChallengeType;
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
@Table(name = "webauthn_challenges")
@NoArgsConstructor
public class WebAuthnChallenge {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id")
  private @Nullable User user;

  @Column(name = "email", length = 250)
  private @Nullable String email;

  @Column(name = "challenge", nullable = false, length = 100)
  private String challenge;

  @Enumerated(EnumType.STRING)
  @Column(name = "challenge_type", nullable = false, length = 20)
  private WebAuthnChallengeType challengeType;

  @Column(name = "expires_at", nullable = false)
  private Instant expiresAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  public WebAuthnChallenge(
      @Nullable User user,
      @Nullable String email,
      String challenge,
      WebAuthnChallengeType challengeType,
      Instant expiresAt) {
    this.user = user;
    this.email = email;
    this.challenge = challenge;
    this.challengeType = challengeType;
    this.expiresAt = expiresAt;
  }

  public boolean isValid() {
    return expiresAt.isAfter(Instant.now());
  }
}
