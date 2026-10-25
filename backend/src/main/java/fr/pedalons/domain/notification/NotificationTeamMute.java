package fr.pedalons.domain.notification;

import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

/**
 * A member who silenced a team: none of its broadcast notifications reach them, inbox included.
 * Personal ones — a cancellation of a ride they joined, a reply — still do. Hard delete; the row's
 * presence is the setting.
 */
@Setter
@Getter
@Entity
@Table(
    name = "notification_team_mutes",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_notification_team_mutes_user_team",
          columnNames = {"user_id", "team_id"})
    },
    indexes = {@Index(name = "idx_notification_team_mutes_team", columnList = "team_id")})
@NoArgsConstructor
public class NotificationTeamMute {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_id", nullable = false)
  private Team team;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  public NotificationTeamMute(User user, Team team) {
    this.user = user;
    this.team = team;
  }
}
