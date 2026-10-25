package fr.pedalons.domain.migration;

import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.BiketeamMigrationStatus;
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
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;
import org.jspecify.annotations.Nullable;
import tools.jackson.databind.JsonNode;

/**
 * One confirmed biketeam migration request. The row is first a <em>grant</em> — a single-use
 * credential, stored hashed, that a Pédalons user hands biketeam through the browser — and, once
 * biketeam redeems it over HTTPS, the <em>job</em> the worker runs. Same "row is the queue" shape
 * as {@link fr.pedalons.domain.user.UserExport}.
 *
 * <p>Standalone entity (no {@code BaseEntity}): it belongs to a domain and a user, never to a team —
 * the target team may not exist yet, and a reset trashes the one it pointed at.
 *
 * <p>{@code baseUrl} is {@code domains.base_url} snapshotted at confirmation: the worker runs with
 * no HTTP request, and the URL table it builds for biketeam must use the parent domain, never an
 * alias the user happened to confirm on.
 *
 * <p>See docs/plans/2026-09-22-biketeam-live-migration.md §8.1.
 */
@Setter
@Getter
@Entity
@Table(
    name = "biketeam_migrations",
    indexes = {
      @Index(name = "idx_biketeam_migrations_status", columnList = "status, next_attempt_at")
    })
@NoArgsConstructor
public class BiketeamMigrationJob {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  /** The Pédalons account that confirmed: it becomes ADMIN and author of the migrated team. */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  /** Biketeam team id — also the target team slug. */
  @Column(name = "biketeam_team_id", nullable = false, length = 255)
  private String biketeamTeamId;

  @Column(name = "biketeam_team_name", nullable = false, length = 250)
  private String biketeamTeamName;

  /** Biketeam's {@code pedalons_migration.id}, the {@code jti} of the signed request. */
  @Column(name = "request_id", nullable = false, unique = true, length = 64)
  private String requestId;

  @Column(name = "dry_run", nullable = false)
  private boolean dryRun;

  @Column(name = "reset", nullable = false)
  private boolean reset;

  @Column(name = "return_url", nullable = false, length = 1000)
  private String returnUrl;

  @Column(name = "base_url", nullable = false, length = 500)
  private String baseUrl;

  /** SHA-256 of the grant, Base64. The plaintext only ever lives in the browser and in biketeam. */
  @Column(name = "grant_hash", nullable = false, unique = true, length = 100)
  private String grantHash;

  @Column(name = "grant_expires_at", nullable = false)
  private Instant grantExpiresAt;

  @Enumerated(EnumType.STRING)
  @Column(name = "status", nullable = false, length = 20)
  private BiketeamMigrationStatus status = BiketeamMigrationStatus.GRANTED;

  @Column(name = "attempts", nullable = false)
  private int attempts;

  @Column(name = "next_attempt_at")
  private @Nullable Instant nextAttemptAt;

  @Column(name = "heartbeat_at")
  private @Nullable Instant heartbeatAt;

  /** {@code {phase, done, total}}. */
  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "progress", columnDefinition = "jsonb")
  private @Nullable JsonNode progress;

  @Column(name = "target_team_id")
  private @Nullable Long targetTeamId;

  /** {@code {counts, warnings, warningsTruncated, urlMap}} — urlMap only once SUCCEEDED. */
  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "result", columnDefinition = "jsonb")
  private @Nullable JsonNode result;

  @Column(name = "error_code", length = 60)
  private @Nullable String errorCode;

  /** Operator diagnostics, also relayed to biketeam's admin page. */
  @Column(name = "error_message", length = 1000)
  private @Nullable String errorMessage;

  @Column(name = "queued_at")
  private @Nullable Instant queuedAt;

  @Column(name = "started_at")
  private @Nullable Instant startedAt;

  @Column(name = "finished_at")
  private @Nullable Instant finishedAt;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @Version private Long version;

  public BiketeamMigrationJob(
      Domain domain,
      User user,
      String biketeamTeamId,
      String biketeamTeamName,
      String requestId,
      boolean dryRun,
      boolean reset,
      String returnUrl,
      String baseUrl,
      String grantHash,
      Instant grantExpiresAt) {
    this.domain = domain;
    this.user = user;
    this.biketeamTeamId = biketeamTeamId;
    this.biketeamTeamName = biketeamTeamName;
    this.requestId = requestId;
    this.dryRun = dryRun;
    this.reset = reset;
    this.returnUrl = returnUrl;
    this.baseUrl = baseUrl;
    this.grantHash = grantHash;
    this.grantExpiresAt = grantExpiresAt;
  }
}
