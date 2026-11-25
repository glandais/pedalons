package fr.pedalons.domain.auth;

import fr.pedalons.enums.AuthFailureKind;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * One failed guess at a secret, kept a day so the next ones can be refused (docs/LEDGER_*.md SEC-4,
 * SEC-7). Holds no identifier in clear: see {@code AuthThrottle} for what {@link #subject} is.
 */
@Getter
@Entity
@Table(name = "auth_failures")
@NoArgsConstructor
public class AuthFailure {

  @Id @Tsid private Long id;

  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  @Enumerated(EnumType.STRING)
  @Column(name = "kind", nullable = false, length = 20)
  private AuthFailureKind kind;

  @Column(name = "subject", nullable = false, length = 64)
  private String subject;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  public AuthFailure(Long domainId, AuthFailureKind kind, String subject) {
    this.domainId = domainId;
    this.kind = kind;
    this.subject = subject;
  }
}
