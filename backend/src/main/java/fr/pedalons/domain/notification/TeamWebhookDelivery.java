package fr.pedalons.domain.notification;

import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

/**
 * One event, posted to one team webhook: the webhook's send queue, with the same life cycle as a
 * {@link NotificationDelivery} — claimed, sent outside any transaction, marked or backed off.
 * Created by the fan-out whether or not the event had any individual recipient.
 */
@Setter
@Getter
@Entity
@Table(
    name = "team_webhook_deliveries",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_team_webhook_deliveries_event_webhook",
          columnNames = {"event_id", "webhook_id"})
    },
    indexes = {
      @Index(name = "idx_team_webhook_deliveries_queue", columnList = "status, next_attempt_at")
    })
@NoArgsConstructor
public class TeamWebhookDelivery {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "event_id", nullable = false)
  private NotificationEventEntry event;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "webhook_id", nullable = false)
  private TeamWebhook webhook;

  @Enumerated(EnumType.STRING)
  @Column(name = "status", nullable = false, length = 20)
  private NotificationDeliveryStatus status = NotificationDeliveryStatus.PENDING;

  @Column(name = "attempts", nullable = false)
  private int attempts;

  @Column(name = "next_attempt_at", nullable = false)
  private Instant nextAttemptAt;

  @Column(name = "last_attempt_at")
  private @Nullable Instant lastAttemptAt;

  @Column(name = "sent_at")
  private @Nullable Instant sentAt;

  /** Operator diagnostics. Never returned by the API. */
  @Column(name = "error_message", length = 500)
  private @Nullable String errorMessage;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @Version private Long version;

  public TeamWebhookDelivery(NotificationEventEntry event, TeamWebhook webhook, Instant now) {
    this.event = event;
    this.webhook = webhook;
    this.nextAttemptAt = now;
    this.createdAt = now;
  }
}
