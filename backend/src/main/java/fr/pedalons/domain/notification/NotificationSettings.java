package fr.pedalons.domain.notification;

import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

/**
 * A member's settings that are not a (type, channel) cell. At most one row per user; absent means
 * every default. Hard delete.
 */
@Setter
@Getter
@Entity
@Table(
    name = "notification_settings",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_notification_settings_user",
          columnNames = {"user_id"})
    })
@NoArgsConstructor
public class NotificationSettings {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  /** Non-urgent e-mails wait for one daily digest instead of leaving one by one. */
  @Column(name = "email_digest", nullable = false)
  private boolean emailDigest;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  public NotificationSettings(User user) {
    this.user = user;
  }
}
