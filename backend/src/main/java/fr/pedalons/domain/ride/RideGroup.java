package fr.pedalons.domain.ride;

import fr.pedalons.domain.common.BaseEntity;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.user.User;
import jakarta.persistence.*;
import java.time.Instant;
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
    name = "ride_groups",
    indexes = {
      @Index(columnList = "ride_id"),
    })
@NoArgsConstructor
public class RideGroup extends BaseEntity {

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "ride_id", nullable = false)
  private Ride ride;

  @Column(name = "name", nullable = false, length = 250)
  private String name;

  /**
   * When the group leaves: the time the request gives it on the ride's local date, in the ride's
   * zone; the ride's own start when it gives none. Written on every save of the ride, so a date
   * change moves every group. The one value every reader takes (docs/LEDGER_*.md API-60): the time
   * a client edits is read back from it ({@code EventTimezoneResolver.ownTime}).
   */
  @Column(name = "start_at", nullable = false)
  private Instant startAt;

  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "route_id")
  @Nullable
  private Route route;

  @Column(name = "average_speed")
  @Nullable
  private Float averageSpeed;

  @Column(name = "max_participants")
  @Nullable
  private Integer maxParticipants;

  @Column(name = "sort_order", nullable = false)
  private int sortOrder = 0;

  /**
   * The member who leads this group, when one is designated.
   *
   * <p>Distinct from {@link BaseEntity#createdBy}, which holds whoever created the <em>ride</em>
   * and is therefore identical across all its groups — reading it as a leader would be wrong on
   * almost every group. Null means "not designated", not "unknown": clients render no pill rather
   * than falling back on anything.
   *
   * <p>Lazy, like every other to-one here: a ride's groups are mapped in one pass, so batch fetch
   * resolves the whole set in a single query rather than one per group.
   */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "leader_id")
  @Nullable
  private User leader;

  @OneToMany(mappedBy = "rideGroup", cascade = CascadeType.ALL, orphanRemoval = true)
  private List<RideParticipation> participations = new ArrayList<>();

  public RideGroup(User creator, Ride ride, String name) {
    super(creator);
    this.ride = ride;
    this.name = name;
    // It leaves with its ride until the ride's save gives it its own time.
    this.startAt = ride.getDateTime();
  }

  /**
   * Whether the group has left at {@code now}: from then on it takes no new registration ({@code
   * RIDE_PAST}). The one test of the join endpoints ({@code RideService.checkJoinable}) and of the
   * {@code canRegister} of a ride detail ({@code ContentPermissions}), docs/LEDGER_*.md API-170,
   * API-176.
   */
  public boolean hasLeft(Instant now) {
    return startAt.isBefore(now);
  }

  public void addParticipation(RideParticipation participation) {
    participations.add(participation);
    participation.setRideGroup(this);
  }

  public int getCurrentParticipants() {
    return participations.size();
  }

  public boolean hasCapacity() {
    return maxParticipants == null || getCurrentParticipants() < maxParticipants;
  }
}
