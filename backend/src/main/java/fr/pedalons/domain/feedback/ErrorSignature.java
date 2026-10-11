package fr.pedalons.domain.feedback;

import fr.pedalons.enums.ClientPlatform;
import fr.pedalons.enums.GithubSyncStatus;
import io.hypersistence.utils.hibernate.id.Tsid;
import io.hypersistence.utils.hibernate.type.json.JsonBinaryType;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.DynamicUpdate;
import org.hibernate.annotations.Type;
import org.jspecify.annotations.Nullable;

/**
 * One distinct unhandled error, as {@code ErrorFingerprint} tells them apart, and its GitHub issue.
 *
 * <p>Deliberately <em>not</em> scoped to a domain: a bug lives in the code, and every tenant runs
 * the same code. Its {@link ErrorOccurrence}s carry the domain. It is read by the GitHub worker only
 * and never exposed by the API.
 *
 * <p>{@code @DynamicUpdate}: two writers share the row, {@code FeedbackService.reportError} (the
 * counters, {@code versions}, {@code regression_version}) and {@code FeedbackGithubWorker} (the
 * GitHub fields). A full-row UPDATE made each write back the other's columns as it had read them,
 * losing a concurrent occurrence (docs/LEDGER_*.md ISSUE-9). Each one now writes only what it
 * changed, and both lock the row before a read-modify-write.
 */
@Setter
@Getter
@Entity
@Table(
    name = "error_signatures",
    uniqueConstraints = {
      @UniqueConstraint(name = "uk_error_signatures_fingerprint", columnNames = "fingerprint")
    },
    indexes = {
      @Index(
          name = "idx_error_signatures_github_status",
          columnList = "github_status, first_seen_at")
    })
@DynamicUpdate
@NoArgsConstructor
public class ErrorSignature {

  @Id @Tsid private Long id;

  /** Hex SHA-256, see {@code ErrorFingerprint}. */
  @Column(name = "fingerprint", nullable = false, length = 64)
  private String fingerprint;

  @Enumerated(EnumType.STRING)
  @Column(name = "platform", nullable = false, length = 20)
  private ClientPlatform platform;

  /** Error class and message of the first occurrence, redacted — the issue title. */
  @Column(name = "title", nullable = false, length = 300)
  private String title;

  @Column(name = "first_seen_at", nullable = false)
  private Instant firstSeenAt;

  @Column(name = "last_seen_at", nullable = false)
  private Instant lastSeenAt;

  @Column(name = "occurrence_count", nullable = false)
  private long occurrenceCount;

  /** Every client version it was seen on, in order of appearance. */
  @Type(JsonBinaryType.class)
  @Column(name = "versions", columnDefinition = "jsonb", nullable = false)
  private List<String> versions = new ArrayList<>();

  @Enumerated(EnumType.STRING)
  @Column(name = "github_status", nullable = false, length = 20)
  private GithubSyncStatus githubStatus = GithubSyncStatus.PENDING;

  @Column(name = "github_attempts", nullable = false)
  private int githubAttempts;

  @Column(name = "github_issue_number")
  private @Nullable Integer githubIssueNumber;

  @Column(name = "github_created_at")
  private @Nullable Instant githubCreatedAt;

  /**
   * The lease of the worker that is calling GitHub for this signature, so that the second backend
   * of a rolling deploy does not open, reopen or summarize the same issue meanwhile (docs/LEDGER_*.md
   * ISSUE-8). Null when free; an expired lease is free too.
   */
  @Column(name = "github_claimed_until")
  private @Nullable Instant githubClaimedUntil;

  /** Occurrences up to this instant are summed up in a comment of the issue already. */
  @Column(name = "summarized_until")
  private @Nullable Instant summarizedUntil;

  /** Set when the worker finds the issue closed on GitHub, cleared if it is reopened there. */
  @Column(name = "issue_closed", nullable = false)
  private boolean issueClosed;

  /**
   * The versions seen when the issue was found closed. An occurrence on any other version is a
   * regression and reopens the issue; one on these versions is a client that was never updated.
   */
  @Type(JsonBinaryType.class)
  @Column(name = "versions_at_close", columnDefinition = "jsonb", nullable = false)
  private List<String> versionsAtClose = new ArrayList<>();

  /** The version that reproduced the error after its issue was closed, until it is reopened. */
  @Column(name = "regression_version", length = 50)
  private @Nullable String regressionVersion;
}
