package fr.pedalons.domain.team;

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
    name = "team_slug_redirects",
    indexes = {@Index(columnList = "old_slug")})
@NoArgsConstructor
public class TeamSlugRedirect {

  @Id @Tsid private Long id;

  @Column(name = "old_slug", nullable = false, unique = true, length = 250)
  private String oldSlug;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_id", nullable = false)
  private Team team;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  public TeamSlugRedirect(String oldSlug, Team team) {
    this.oldSlug = oldSlug;
    this.team = team;
  }

  @Override
  public final boolean equals(Object o) {
    if (this == o) return true;
    if (o == null) return false;
    Class<?> oEffectiveClass = Hibernate.getClassLazy(o);
    Class<?> thisEffectiveClass = Hibernate.getClassLazy(this);
    if (thisEffectiveClass != oEffectiveClass) return false;
    TeamSlugRedirect that = (TeamSlugRedirect) o;
    return getId() != null && Objects.equals(getId(), that.getId());
  }

  @Override
  public final int hashCode() {
    return Hibernate.getClassLazy(this).hashCode();
  }
}
