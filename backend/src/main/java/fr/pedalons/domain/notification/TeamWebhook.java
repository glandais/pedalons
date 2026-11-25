package fr.pedalons.domain.notification;

import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.NotificationDeliveryStatus;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.jspecify.annotations.Nullable;

/**
 * A team's outgoing webhook: its announcements, posted to a chat channel or any HTTPS endpoint.
 *
 * <p>The URL is a secret — a Slack or Discord webhook URL is all it takes to post to the channel —
 * so the API only ever returns it masked. Hard delete, one per team.
 */
@Setter
@Getter
@Entity
@Table(
    name = "team_webhooks",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_team_webhooks_team",
          columnNames = {"team_id"})
    })
@NoArgsConstructor
public class TeamWebhook {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_id", nullable = false)
  private Team team;

  @Column(name = "url", nullable = false, length = 1000)
  private String url;

  /** The language the messages are written in: a channel has one audience, not one per reader. */
  @Column(name = "language", nullable = false, length = 10)
  private String language;

  @Column(name = "enabled", nullable = false)
  private boolean enabled;

  /** Outcome of the latest attempt, shown to the team's administrators. */
  @Enumerated(EnumType.STRING)
  @Column(name = "last_status", length = 20)
  private @Nullable NotificationDeliveryStatus lastStatus;

  @Column(name = "last_error", length = 500)
  private @Nullable String lastError;

  @Column(name = "last_attempt_at")
  private @Nullable Instant lastAttemptAt;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  public TeamWebhook(Team team, String url, String language, boolean enabled) {
    this.team = team;
    this.url = url;
    this.language = language;
    this.enabled = enabled;
  }
}
