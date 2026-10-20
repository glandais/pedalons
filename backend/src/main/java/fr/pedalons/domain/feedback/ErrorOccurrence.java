package fr.pedalons.domain.feedback;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.hibernate.JsonNodeMutabilityPlan;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.Mutability;
import org.hibernate.type.SqlTypes;
import org.jspecify.annotations.Nullable;

/**
 * One automatic report of an unhandled error by a member's client. Stored redacted, purged after
 * {@code FeedbackService#OCCURRENCE_RETENTION_DAYS} days.
 */
@Setter
@Getter
@Entity
@Table(
    name = "error_occurrences",
    indexes = {
      @Index(name = "idx_error_occurrences_signature", columnList = "signature_id, created_at"),
      @Index(name = "idx_error_occurrences_user_created", columnList = "user_id, created_at"),
      @Index(name = "idx_error_occurrences_created", columnList = "created_at")
    })
@NoArgsConstructor
public class ErrorOccurrence {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "signature_id", nullable = false)
  private ErrorSignature signature;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Column(name = "app_version", nullable = false, length = 50)
  private String appVersion;

  /** {@code ClientContextDto}, serialized. */
  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "context", columnDefinition = "jsonb", nullable = false)
  private JsonNode context;

  /** {@code ClientErrorDto}, serialized. */
  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "error", columnDefinition = "jsonb", nullable = false)
  private JsonNode error;

  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "logs", columnDefinition = "jsonb")
  private @Nullable JsonNode logs;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
}
