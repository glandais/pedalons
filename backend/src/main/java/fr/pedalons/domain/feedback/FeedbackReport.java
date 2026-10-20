package fr.pedalons.domain.feedback;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ClientPlatform;
import fr.pedalons.enums.FeedbackKind;
import fr.pedalons.enums.GithubSyncStatus;
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
 * A bug report or a suggestion a member wrote from the app or the site, with the technical context
 * their client attached. Published as an issue of the private feedback repository by {@code
 * FeedbackGithubWorker}; the row is the source of truth and outlives a GitHub outage.
 *
 * <p>Context, error and log are stored already redacted (see {@code LogRedactor}). The message is
 * stored as written, and redacted only in the issue.
 */
@Setter
@Getter
@Entity
@Table(
    name = "feedback_reports",
    indexes = {
      @Index(name = "idx_feedback_reports_user_created", columnList = "user_id, created_at"),
      @Index(name = "idx_feedback_reports_github_status", columnList = "github_status, created_at")
    })
@NoArgsConstructor
public class FeedbackReport {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Enumerated(EnumType.STRING)
  @Column(name = "kind", nullable = false, length = 20)
  private FeedbackKind kind;

  @Enumerated(EnumType.STRING)
  @Column(name = "platform", nullable = false, length = 20)
  private ClientPlatform platform;

  /** Null for a bug the member did not describe; a suggestion always has one. */
  @Column(name = "message", columnDefinition = "text")
  private @Nullable String message;

  /** {@code ClientContextDto}, serialized. */
  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "context", columnDefinition = "jsonb", nullable = false)
  private JsonNode context;

  /** {@code ClientErrorDto}, serialized — the error the report was opened from, if any. */
  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "error", columnDefinition = "jsonb")
  private @Nullable JsonNode error;

  /** {@code ClientLogEntryDto}s, serialized. Null when the member attached no technical details. */
  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "logs", columnDefinition = "jsonb")
  private @Nullable JsonNode logs;

  /** The automatic report of the same error, when {@link #error} matched a known one. */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "signature_id")
  private @Nullable ErrorSignature signature;

  @Enumerated(EnumType.STRING)
  @Column(name = "github_status", nullable = false, length = 20)
  private GithubSyncStatus githubStatus = GithubSyncStatus.PENDING;

  @Column(name = "github_attempts", nullable = false)
  private int githubAttempts;

  @Column(name = "github_issue_number")
  private @Nullable Integer githubIssueNumber;

  /**
   * The lease of the worker that is opening the issue, so that the second backend of a rolling
   * deploy does not open another (docs/LEDGER_*.md ISSUE-8). Null when free; an expired lease is free
   * too.
   */
  @Column(name = "github_claimed_until")
  private @Nullable Instant githubClaimedUntil;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
}
