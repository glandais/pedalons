package fr.pedalons.domain.notification;

import fr.pedalons.domain.user.User;
import fr.pedalons.enums.PushPlatform;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

/**
 * One app install that may receive pushes. Hard delete: a device is unregistered on sign-out, and
 * purged when FCM answers {@code UNREGISTERED} — the table must not grow with tokens nobody can
 * reach.
 *
 * <p>The token is unique on its own. Registering a token already held by someone else moves the
 * row, which is what signing in on a shared phone should do.
 */
@Setter
@Getter
@Entity
@Table(
    name = "push_devices",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_push_devices_token",
          columnNames = {"token"})
    },
    indexes = {@Index(name = "idx_push_devices_user", columnList = "user_id")})
@NoArgsConstructor
public class PushDevice {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Enumerated(EnumType.STRING)
  @Column(name = "platform", nullable = false, length = 20)
  private PushPlatform platform;

  @Column(name = "token", nullable = false, length = 512)
  private String token;

  /** What the member sees in a future "your devices" list. Free text from the client. */
  @Column(name = "device_name", length = 120)
  private @Nullable String deviceName;

  @Column(name = "app_version", length = 40)
  private @Nullable String appVersion;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  /** Bumped at every registration: the app re-registers on launch, so this dates the last launch. */
  @Column(name = "last_seen_at", nullable = false)
  private Instant lastSeenAt;

  @Version private Long version;

  public PushDevice(User user, PushPlatform platform, String token, Instant now) {
    this.user = user;
    this.platform = platform;
    this.token = token;
    this.createdAt = now;
    this.lastSeenAt = now;
  }
}
