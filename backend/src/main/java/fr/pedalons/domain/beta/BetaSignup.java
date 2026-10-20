package fr.pedalons.domain.beta;

import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

/**
 * A request to be added to a beta program (TestFlight, Play Console, Garmin Connect IQ) once one
 * opens.
 *
 * <p>Not tied to a user or a team: someone can sign up before ever creating an account, and the
 * apps being advertised aren't scoped to a single team. {@code domainId} is captured only for
 * reporting on a white-labelled deployment, never for access control.
 */
@Setter
@Getter
@Entity
@Table(name = "beta_signups")
@NoArgsConstructor
public class BetaSignup {

  @Id @Tsid private Long id;

  @Column(name = "email", nullable = false)
  private String email;

  @Column(name = "domain_id")
  private @Nullable Long domainId;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt = Instant.now();

  public BetaSignup(String email, @Nullable Long domainId) {
    this.email = email;
    this.domainId = domainId;
  }
}
