package fr.pedalons.domain.common;

import fr.pedalons.domain.team.Team;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.Hibernate;
import org.hibernate.annotations.CreationTimestamp;

@Setter
@Getter
@Entity
@Table(
    name = "team_entity_slug_redirects",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_team_entity_slug_redirect",
          columnNames = {"team_id", "entity_type", "old_slug"})
    },
    indexes = {@Index(columnList = "team_id, entity_type, old_slug")})
@NoArgsConstructor
public class TeamEntitySlugRedirect {

  @Id @Tsid private Long id;

  @Column(name = "old_slug", nullable = false, length = 250)
  private String oldSlug;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_id", nullable = false)
  private Team team;

  @Column(name = "entity_type", nullable = false)
  private Integer entityType;

  @Column(name = "entity_id", nullable = false)
  private Long entityId;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  public TeamEntitySlugRedirect(String oldSlug, Team team, Integer entityType, Long entityId) {
    this.oldSlug = oldSlug;
    this.team = team;
    this.entityType = entityType;
    this.entityId = entityId;
  }

  @Override
  public final boolean equals(Object o) {
    if (this == o) return true;
    if (o == null) return false;
    Class<?> oEffectiveClass = Hibernate.getClassLazy(o);
    Class<?> thisEffectiveClass = Hibernate.getClassLazy(this);
    if (thisEffectiveClass != oEffectiveClass) return false;
    TeamEntitySlugRedirect that = (TeamEntitySlugRedirect) o;
    return getId() != null && Objects.equals(getId(), that.getId());
  }

  @Override
  public final int hashCode() {
    return Hibernate.getClassLazy(this).hashCode();
  }
}
