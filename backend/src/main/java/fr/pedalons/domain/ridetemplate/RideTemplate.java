package fr.pedalons.domain.ridetemplate;

import fr.pedalons.domain.common.BaseEntity;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import jakarta.persistence.*;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@Table(
    name = "ride_templates",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_ride_template_slug",
          columnNames = {"team_id", "slug"})
    },
    indexes = {
      @Index(columnList = "team_id"),
      @Index(columnList = "team_id, slug"),
    })
@NoArgsConstructor
public class RideTemplate extends BaseEntity {

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_id", nullable = false)
  private Team team;

  @Column(name = "name", nullable = false, length = 250)
  private String name;

  @Column(name = "slug", nullable = false, length = 250)
  private String slug;

  @Column(name = "markdown", nullable = false, columnDefinition = "TEXT")
  private String markdown;

  @Enumerated(EnumType.STRING)
  @Column(name = "visibility", nullable = false, length = 20)
  private Visibility visibility = Visibility.TEAM;

  @Enumerated(EnumType.STRING)
  @Column(name = "status", nullable = false, length = 20)
  private Status status = Status.PUBLISHED;

  /**
   * The number the next ride created from this template takes (« Sortie du jeudi #42 »), raised by
   * one each time; null when the template numbers nothing (docs/LEDGER_*.md API-108).
   */
  @Column(name = "next_number")
  @Nullable
  private Integer nextNumber;

  // Without it the groups come back in whatever order the table holds them, which an update
  // reshuffles: a renamed group moves to the end.
  @OneToMany(mappedBy = "template", cascade = CascadeType.ALL, orphanRemoval = true)
  @OrderBy("sortOrder ASC")
  private List<RideTemplateGroup> groups = new ArrayList<>();

  public RideTemplate(
      User creator,
      Team team,
      String name,
      String slug,
      String markdown,
      Visibility visibility,
      Status status) {
    super(creator);
    this.team = team;
    this.name = name;
    this.slug = slug;
    this.markdown = markdown;
    this.visibility = visibility;
    this.status = status;
  }

  public void addGroup(RideTemplateGroup group) {
    groups.add(group);
    group.setTemplate(this);
  }
}
