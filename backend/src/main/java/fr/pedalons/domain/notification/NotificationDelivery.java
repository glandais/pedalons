package fr.pedalons.domain.notification;

import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

/**
 * One notification on one out-of-app channel. The row is the send queue of that channel: a sender
 * tick claims the due {@link NotificationDeliveryStatus#PENDING} rows, sends outside any
 * transaction, then marks them.
 *
 * <p>Never created for {@code IN_APP} — the notification row already is that delivery — nor for a
 * channel the server cannot send on (not implemented, or disabled by configuration), where rows
 * would only pile up.
 */
@Setter
@Getter
@Entity
@Table(
    name = "notification_deliveries",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_notification_deliveries_notification_channel",
          columnNames = {"notification_id", "channel"})
    },
    indexes = {
      @Index(
          name = "idx_notification_deliveries_queue",
          columnList = "channel, status, next_attempt_at"),
      @Index(
          name = "idx_notification_deliveries_digest",
          columnList = "digest, status, next_attempt_at")
    })
@NoArgsConstructor
public class NotificationDelivery {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "notification_id", nullable = false)
  private Notification notification;

  @Enumerated(EnumType.STRING)
  @Column(name = "channel", nullable = false, length = 20)
  private NotificationChannel channel;

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

  /**
   * Held for the recipient's daily digest: skipped by the ordinary sender, sent with the recipient's
   * other due digest e-mails as one message. {@code nextAttemptAt} is then the digest time.
   */
  @Column(name = "digest", nullable = false)
  private boolean digest;

  @Version private Long version;

  public NotificationDelivery(Notification notification, NotificationChannel channel, Instant now) {
    this.notification = notification;
    this.channel = channel;
    this.nextAttemptAt = now;
    this.createdAt = now;
  }
}
