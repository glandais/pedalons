package fr.pedalons.domain.notification;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.enums.NotificationChange;
import fr.pedalons.enums.NotificationEventStatus;
import fr.pedalons.enums.NotificationSubjectType;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.infrastructure.hibernate.JsonNodeMutabilityPlan;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.Mutability;
import org.hibernate.type.SqlTypes;
import org.jspecify.annotations.Nullable;

/**
 * One business event waiting to be — or having been — turned into notifications: the outbox.
 *
 * <p>Written by {@code NotificationPublisher} inside the business transaction, with only the typed
 * payload (identifiers) and the dedup key. Never persisted through JPA: the publisher issues an
 * {@code INSERT … ON CONFLICT DO NOTHING}, because a duplicate must not throw inside a transaction
 * that is busy cancelling a ride.
 *
 * <p>The {@code subject*}, {@code team*}, {@code actorName}, {@code excerpt}, {@code baseUrl} and
 * {@code siteName} columns are the snapshot taken by the dispatcher when it fans the event out.
 * They are what the inbox renders, joined once per page — not a per-row lookup of rides, trips and
 * teams — and they describe the subject as it was when the notification was sent, which is also
 * what an e-mail already in someone's mailbox says. They stay null for an event that never got past
 * {@link NotificationEventStatus#PENDING} or was {@link NotificationEventStatus#SKIPPED}.
 *
 * <p>Standalone (hard delete, no {@code BaseEntity}): it has no creator in the {@code createdBy}
 * sense — the actor may be absent (a scheduler) — and it is purged by the retention sweep.
 */
@Setter
@Getter
@Entity
@Table(
    name = "notification_events",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_notification_events_dedup_key",
          columnNames = {"dedup_key"})
    },
    indexes = {
      @Index(name = "idx_notification_events_queue", columnList = "status, next_attempt_at"),
      @Index(name = "idx_notification_events_created", columnList = "created_at")
    })
@NoArgsConstructor
public class NotificationEventEntry {

  @Id @Tsid private Long id;

  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  @Enumerated(EnumType.STRING)
  @Column(name = "type", nullable = false, length = 40)
  private NotificationType type;

  @Enumerated(EnumType.STRING)
  @Column(name = "status", nullable = false, length = 20)
  private NotificationEventStatus status = NotificationEventStatus.PENDING;

  /**
   * {@code TYPE:subjectId} for the types of the first pass — see {@code NotificationEvent}. An event
   * that notified nobody — {@link NotificationEventStatus#SKIPPED} or {@link
   * NotificationEventStatus#FAILED} — has its key suffixed with its id, which releases it: a ride
   * unpublished before dispatch and published again later must still be announced.
   */
  @Column(name = "dedup_key", nullable = false, length = 200)
  private String dedupKey;

  /** The event record, serialized. Read back into its record class by {@code type}. */
  @JdbcTypeCode(SqlTypes.JSON)
  @Mutability(JsonNodeMutabilityPlan.class)
  @Column(name = "payload", columnDefinition = "jsonb", nullable = false)
  private JsonNode payload;

  /** Who caused it — excluded from the recipients. Null when a scheduler did. */
  @Column(name = "actor_id")
  private @Nullable Long actorId;

  @Column(name = "team_id")
  private @Nullable Long teamId;

  @Column(name = "attempts", nullable = false)
  private int attempts;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  /** Not claimed before this: set on insert, pushed back by a failed attempt. */
  @Column(name = "next_attempt_at", nullable = false)
  private Instant nextAttemptAt;

  @Column(name = "started_at")
  private @Nullable Instant startedAt;

  @Column(name = "processed_at")
  private @Nullable Instant processedAt;

  /** Operator diagnostics. Never returned by the API. */
  @Column(name = "error_message", length = 500)
  private @Nullable String errorMessage;

  // ------------------------------------------------------------------ snapshot, set on fan-out

  @Column(name = "actor_name", length = 250)
  private @Nullable String actorName;

  @Column(name = "team_slug", length = 250)
  private @Nullable String teamSlug;

  @Column(name = "team_name", length = 250)
  private @Nullable String teamName;

  @Enumerated(EnumType.STRING)
  @Column(name = "subject_type", length = 20)
  private @Nullable NotificationSubjectType subjectType;

  @Column(name = "subject_slug", length = 250)
  private @Nullable String subjectSlug;

  @Column(name = "subject_name", length = 250)
  private @Nullable String subjectName;

  @Column(name = "subject_date_time")
  private @Nullable Instant subjectDateTime;

  /**
   * The IANA zone the subject's rendezvous reads in, frozen with {@code subjectDateTime}: null for a
   * TEAM or REPORT subject, and on a row fanned out by a backend that predates the column
   * (docs/LEDGER_*.md API-60).
   */
  @Column(name = "subject_timezone", length = 64)
  private @Nullable String subjectTimezone;

  /** A short quote — the reply, for {@code COMMENT_REPLY}. */
  @Column(name = "excerpt", length = 500)
  private @Nullable String excerpt;

  /** The site the links point to: the alias pinned on the team if any, else the domain. */
  @Column(name = "base_url", length = 500)
  private @Nullable String baseUrl;

  @Column(name = "site_name", length = 250)
  private @Nullable String siteName;

  /** What a {@code RIDE_UPDATED} says changed: {@link NotificationChange} names, comma-separated. */
  @Column(name = "changes", length = 100)
  private @Nullable String changes;

  public List<NotificationChange> changeList() {
    if (changes == null || changes.isBlank()) {
      return List.of();
    }
    return Arrays.stream(changes.split(",")).map(NotificationChange::valueOf).toList();
  }

  public void setChangeList(List<NotificationChange> list) {
    this.changes =
        list.isEmpty()
            ? null
            : String.join(",", list.stream().map(NotificationChange::name).toList());
  }

  @Version private Long version;
}
