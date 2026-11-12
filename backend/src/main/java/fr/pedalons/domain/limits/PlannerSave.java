package fr.pedalons.domain.limits;

import io.hypersistence.utils.hibernate.id.Tsid;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.jspecify.annotations.Nullable;

/**
 * One save of a track drawn in the route planner (docs/LEDGER_*.md BILL-10): the journal the
 * planner quotas count. {@code teamId} null is a save in the GPX tools, counted against the user's
 * personal quota. {@code targetId} names the route or the preview for a diagnosis only — no foreign
 * key, so deleting what was drawn never gives the save back.
 */
@Getter
@Entity
@Table(
    name = "planner_saves",
    indexes = {
      @Index(name = "idx_planner_saves_team", columnList = "team_id, saved_at"),
      @Index(name = "idx_planner_saves_user", columnList = "user_id, saved_at"),
      @Index(name = "idx_planner_saves_saved_at", columnList = "saved_at")
    })
@NoArgsConstructor
public class PlannerSave {

  @Id @Tsid private Long id;

  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  @Column(name = "user_id", nullable = false)
  private Long userId;

  @Column(name = "team_id")
  private @Nullable Long teamId;

  @Column(name = "saved_at", nullable = false)
  private Instant savedAt;

  @Column(name = "target_id")
  private @Nullable Long targetId;

  public PlannerSave(
      Long domainId, Long userId, @Nullable Long teamId, Instant savedAt, @Nullable Long targetId) {
    this.domainId = domainId;
    this.userId = userId;
    this.teamId = teamId;
    this.savedAt = savedAt;
    this.targetId = targetId;
  }
}
