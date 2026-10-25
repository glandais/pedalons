package fr.pedalons.domain.notification;

import fr.pedalons.domain.user.User;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

/**
 * One event, for one recipient: the inbox entry.
 *
 * <p>Carries no content of its own — what it says is the {@link NotificationEventEntry} snapshot,
 * shared by every recipient of the same event. On a 2 000-member team that is one row of text and
 * 2 000 narrow rows, rather than 2 000 copies of a ride's name.
 *
 * <p>{@code type} and {@code domainId} are denormalised from the event so the inbox queries (list,
 * unread count, mark all read) filter on this table alone.
 */
@Setter
@Getter
@Entity
@Table(
    name = "notifications",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_notifications_event_recipient",
          columnNames = {"event_id", "recipient_id"})
    },
    indexes = {
      @Index(name = "idx_notifications_recipient_created", columnList = "recipient_id, created_at"),
      @Index(name = "idx_notifications_recipient_read", columnList = "recipient_id, read_at")
    })
@NoArgsConstructor
public class Notification {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "event_id", nullable = false)
  private NotificationEventEntry event;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "recipient_id", nullable = false)
  private User recipient;

  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  @Enumerated(EnumType.STRING)
  @Column(name = "type", nullable = false, length = 40)
  private NotificationType type;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  /** Null while unread. */
  @Column(name = "read_at")
  private @Nullable Instant readAt;

  public Notification(NotificationEventEntry event, User recipient, Instant createdAt) {
    this.event = event;
    this.recipient = recipient;
    this.domainId = event.getDomainId();
    this.type = event.getType();
    this.createdAt = createdAt;
  }
}
