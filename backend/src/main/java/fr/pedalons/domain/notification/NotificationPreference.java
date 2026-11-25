package fr.pedalons.domain.notification;

import fr.pedalons.domain.user.User;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

/**
 * A member's choice for one (type, channel) cell. Absent means the type's default — see {@link
 * NotificationType#isEnabledByDefault}. Hard delete.
 */
@Setter
@Getter
@Entity
@Table(
    name = "notification_preferences",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_notification_preferences_user_type_channel",
          columnNames = {"user_id", "type", "channel"})
    })
@NoArgsConstructor
public class NotificationPreference {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Enumerated(EnumType.STRING)
  @Column(name = "type", nullable = false, length = 40)
  private NotificationType type;

  @Enumerated(EnumType.STRING)
  @Column(name = "channel", nullable = false, length = 20)
  private NotificationChannel channel;

  @Column(name = "enabled", nullable = false)
  private boolean enabled;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  public NotificationPreference(
      User user, NotificationType type, NotificationChannel channel, boolean enabled) {
    this.user = user;
    this.type = type;
    this.channel = channel;
    this.enabled = enabled;
  }
}
