package fr.pedalons.domain.ride;

import fr.pedalons.domain.common.Publication;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Visibility;
import jakarta.persistence.*;
import java.time.*;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@DiscriminatorValue("1")
@NoArgsConstructor
public class Ride extends Publication {

  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "route_id")
  @Nullable
  private Route route;

  @OneToMany(mappedBy = "ride", cascade = CascadeType.ALL, orphanRemoval = true)
  private List<RideGroup> groups = new ArrayList<>();

  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "place_start_id")
  @Nullable
  private Place start;

  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "place_end_id")
  @Nullable
  private Place end;

  public Ride(
      User createdBy,
      Team team,
      Instant dateTime,
      String name,
      String slug,
      Visibility visibility) {
    super(createdBy, team, dateTime, name, slug, visibility);
  }

  public void addGroup(RideGroup group) {
    groups.add(group);
    group.setRide(this);
  }

  /**
   * Whether one of the groups has not left yet at {@code now} — {@link RideGroup#hasLeft}, the test
   * a join applies to the group it is asked for. False for a ride without a group: there is nothing
   * to join. Walks {@link #getGroups()}: for a detail, never a list row (docs/LEDGER_*.md API-176).
   */
  public boolean hasGroupStillToLeave(Instant now) {
    return groups.stream().anyMatch(group -> !group.hasLeft(now));
  }

  public int getParticipantCount() {
    return groups.stream().mapToInt(RideGroup::getCurrentParticipants).sum();
  }

  public int getGroupCount() {
    return groups.size();
  }

  @Override
  public EntityType getEntityType() {
    return EntityType.RIDE;
  }
}
