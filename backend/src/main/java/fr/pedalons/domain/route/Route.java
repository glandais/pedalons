package fr.pedalons.domain.route;

import fr.pedalons.domain.common.NotNullableDbValue;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WindDirection;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@DiscriminatorValue("2")
@NoArgsConstructor
public class Route extends TeamEntity {

  @Column(name = "distance")
  @NotNullableDbValue
  private Float distance;

  @Column(name = "elevation_gain")
  @NotNullableDbValue
  private Float elevationGain;

  @Column(name = "hilliness")
  @NotNullableDbValue
  private Float hilliness;

  @Column(name = "elevation_loss")
  @NotNullableDbValue
  private Float elevationLoss;

  @Enumerated(EnumType.STRING)
  @Column(name = "surface_type", length = 20)
  @NotNullableDbValue
  private SurfaceType surfaceType;

  @Column(name = "`start`", columnDefinition = "geometry(Point,4326)")
  @NotNullableDbValue
  private Point<G2D> start;

  @Column(name = "`end`", columnDefinition = "geometry(Point,4326)")
  @NotNullableDbValue
  private Point<G2D> end;

  @Enumerated(EnumType.ORDINAL)
  @Column(name = "wind_direction", length = 20)
  @NotNullableDbValue
  private WindDirection windDirection;

  /**
   * Where the stored profile stands: PENDING, HD or FAST. Null means HD: a route computed before the column
   * existed, or saved by the previous release during a rolling deploy (docs/LEDGER_*.md API-131).
   * Use {@link ElevationState#orHd} to read it.
   */
  @Enumerated(EnumType.STRING)
  @Column(name = "elevation_state", length = 8)
  private @Nullable ElevationState elevationState;

  // Ordered: the distances of the waypoints are cumulated over the tracks in this order
  // (docs/LEDGER_*.md WEB-100, C3c)
  @OneToMany(mappedBy = "route", cascade = CascadeType.ALL, orphanRemoval = true)
  @OrderBy("id")
  private List<GpxTrack> tracks = new ArrayList<>();

  @OneToMany(mappedBy = "route", cascade = CascadeType.ALL, orphanRemoval = true)
  private List<GpxWaypoint> waypoints = new ArrayList<>();

  public Route(
      User createdBy,
      Team team,
      String name,
      String slug,
      Visibility visibility,
      SurfaceType surfaceType) {
    super(createdBy, team, Instant.now(), name, slug, visibility);
    this.surfaceType = surfaceType;
  }

  public void addTrack(GpxTrack track) {
    tracks.add(track);
    track.setRoute(this);
  }

  public void addWaypoint(GpxWaypoint waypoint) {
    waypoints.add(waypoint);
    waypoint.setRoute(this);
  }

  /**
   * Removes a waypoint (orphan removal deletes the row). Waypoints are replaced one by one, never
   * by a clear and refill: a query between the two deletes the elements for good (HHH90032003).
   */
  public void removeWaypoint(GpxWaypoint waypoint) {
    waypoints.remove(waypoint);
  }

  @Override
  public EntityType getEntityType() {
    return EntityType.ROUTE;
  }
}
