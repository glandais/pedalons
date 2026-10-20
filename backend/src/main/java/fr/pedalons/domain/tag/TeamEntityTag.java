package fr.pedalons.domain.tag;

import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/**
 * A tag on a ride, a post, a trip, a route or an ad — the five live in {@code team_entities}, so one
 * link table serves them all. That the tag's type matches the content's, and that both belong to
 * the same team, is {@code TagService}'s job, not the schema's.
 *
 * <p>Hard delete; the row's presence is the tagging. Deliberately no collection on {@code
 * TeamEntity}: a list resolves its tags per page through {@code TagLookup}, never by walking a lazy
 * collection row by row.
 */
@Setter
@Getter
@Entity
@Table(
    name = "team_entity_tags",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_team_entity_tags_entity_tag",
          columnNames = {"team_entity_id", "tag_id"})
    },
    indexes = {@Index(name = "idx_team_entity_tags_tag", columnList = "tag_id")})
@NoArgsConstructor
public class TeamEntityTag {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_entity_id", nullable = false)
  @OnDelete(action = OnDeleteAction.CASCADE)
  private TeamEntity teamEntity;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "tag_id", nullable = false)
  @OnDelete(action = OnDeleteAction.CASCADE)
  private Tag tag;

  public TeamEntityTag(TeamEntity teamEntity, Tag tag) {
    this.teamEntity = teamEntity;
    this.tag = tag;
  }
}
