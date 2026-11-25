package fr.pedalons.domain.moderation;

import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

/**
 * A member who no longer wants to see another's comments, posts and ads. Domain-wide, one-way and
 * silent: the blocked member is never told, and sees nothing change. Hard delete; the row's
 * presence is the setting.
 */
@Setter
@Getter
@Entity
@Table(
    name = "user_blocks",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_user_blocks_blocker_blocked",
          columnNames = {"blocker_id", "blocked_id"})
    },
    indexes = {@Index(name = "idx_user_blocks_blocked", columnList = "blocked_id")})
@NoArgsConstructor
public class UserBlock {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "blocker_id", nullable = false)
  private User blocker;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "blocked_id", nullable = false)
  private User blocked;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();

  public UserBlock(User blocker, User blocked) {
    this.blocker = blocker;
    this.blocked = blocked;
  }
}
