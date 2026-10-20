package fr.pedalons.domain.route;

import fr.pedalons.domain.common.BaseEntity;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@Table(
    name = "gpx_waypoints",
    indexes = {@Index(name = "idx_gpx_waypoints_route", columnList = "route_id")})
@NoArgsConstructor
public class GpxWaypoint extends BaseEntity {

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "route_id", nullable = false)
  private Route route;

  @Column(name = "name", nullable = false, length = 250)
  protected String name;

  @Column(name = "geometry", columnDefinition = "geometry(Point,4326)", nullable = false)
  private Point<G2D> geometry;

  /**
   * What the waypoint is. Null marks a row written before C3c, or by the previous release during a
   * rolling deploy: {@code WaypointBackfill} types it INFO and places it (docs/LEDGER_*.md WEB-100,
   * C3c). Use {@link #typeOrInfo} to read it.
   */
  @Enumerated(EnumType.STRING)
  @Column(name = "type", length = 16)
  private @Nullable WaypointType type;

  @Column(name = "description", length = 500)
  private @Nullable String description;

  /**
   * Metres from the start along the tracks in order (the axis of the profile and the FIT); null
   * for a point more than 50 m from the track, kept where its author put it.
   */
  @Column(name = "distance_m")
  private @Nullable Double distanceM;

  @Enumerated(EnumType.STRING)
  @Column(name = "origin", length = 16, nullable = false)
  private WaypointOrigin origin = WaypointOrigin.IMPORTED;

  public GpxWaypoint(User createdBy, String name, Point<G2D> geometry) {
    super(createdBy);
    this.name = name;
    this.geometry = geometry;
  }

  public GpxWaypoint(
      User createdBy,
      String name,
      @Nullable String description,
      Point<G2D> geometry,
      WaypointType type,
      WaypointOrigin origin,
      @Nullable Double distanceM) {
    this(createdBy, name, geometry);
    this.description = description;
    this.type = type;
    this.origin = origin;
    this.distanceM = distanceM;
  }

  public WaypointType typeOrInfo() {
    return type == null ? WaypointType.INFO : type;
  }
}
