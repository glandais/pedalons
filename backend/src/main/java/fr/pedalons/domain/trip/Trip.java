package fr.pedalons.domain.trip;

import fr.pedalons.domain.common.Publication;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Visibility;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@DiscriminatorValue("5")
@NoArgsConstructor
public class Trip extends Publication {

  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "route_id")
  @Nullable
  private Route route;

  @OneToMany(mappedBy = "trip", cascade = CascadeType.ALL, orphanRemoval = true)
  private List<TripStage> stages = new ArrayList<>();

  @OneToMany(mappedBy = "trip", cascade = CascadeType.ALL, orphanRemoval = true)
  private List<TripParticipation> participations = new ArrayList<>();

  public Trip(
      User createdBy,
      Team team,
      Instant dateTime,
      String name,
      String slug,
      Visibility visibility) {
    super(createdBy, team, dateTime, name, slug, visibility);
  }

  public void addStage(TripStage stage) {
    stages.add(stage);
    stage.setTrip(this);
  }

  public void addParticipation(TripParticipation participation) {
    participations.add(participation);
    participation.setTrip(this);
  }

  public int getParticipantCount() {
    return participations.size();
  }

  public int getStageCount() {
    return (int) stages.stream().filter(s -> !s.isDeleted()).count();
  }

  /**
   * Whether the trip is over: its last live stage has left, or the trip itself without a stage —
   * the rule behind {@code TripDto.finished} (docs/LEDGER_*.md API-16), here for the services.
   */
  public boolean isFinished(Instant now) {
    Instant end =
        stages.stream()
            .filter(s -> !s.isDeleted())
            .map(TripStage::getDateTime)
            .max(Comparator.naturalOrder())
            .orElse(getDateTime());
    return end.isBefore(now);
  }

  @Override
  public EntityType getEntityType() {
    return EntityType.TRIP;
  }
}
