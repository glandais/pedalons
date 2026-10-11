package fr.pedalons.domain.route;

import fr.pedalons.domain.common.BaseEntity;
import fr.pedalons.domain.common.NotNullableDbValue;
import fr.pedalons.domain.user.User;
import io.hypersistence.utils.hibernate.type.json.JsonBinaryType;
import jakarta.persistence.*;
import java.io.Serializable;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.geolatte.geom.G2D;
import org.geolatte.geom.LineString;
import org.hibernate.annotations.Type;

/**
 * Represents a GPX track associated with a route.
 * Stores both PostGIS geometry for spatial queries and JSONB track points for efficient frontend rendering.
 */
@Setter
@Getter
@Entity
@Table(
    name = "gpx_tracks",
    indexes = {@Index(name = "idx_gpx_tracks_route", columnList = "route_id")})
@NoArgsConstructor
public class GpxTrack extends BaseEntity {

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "route_id", nullable = false)
  private Route route;

  @Column(name = "name", nullable = false, length = 250)
  protected String name;

  @Column(name = "geometry", columnDefinition = "geometry(LineString,4326)", nullable = false)
  private LineString<G2D> geometry;

  @Type(JsonBinaryType.class)
  @Column(name = "track_points", columnDefinition = "jsonb", nullable = false)
  private List<TrackPoint> trackPoints;

  @Type(JsonBinaryType.class)
  @Column(name = "climbs", columnDefinition = "jsonb", nullable = false)
  private List<ClimbData> climbs;

  @Column(name = "distance", nullable = false)
  @NotNullableDbValue
  private Float distance;

  @Column(name = "elevation_gain", nullable = false)
  @NotNullableDbValue
  private Float elevationGain;

  @Column(name = "elevation_loss", nullable = false)
  @NotNullableDbValue
  private Float elevationLoss;

  public GpxTrack(
      User createdBy,
      String name,
      LineString<G2D> geometry,
      List<TrackPoint> trackPoints,
      List<ClimbData> climbs,
      float distance,
      float elevationGain,
      float elevationLoss) {
    super(createdBy);
    this.name = name;
    this.geometry = geometry;
    this.trackPoints = trackPoints;
    this.climbs = climbs;
    this.distance = distance;
    this.elevationGain = elevationGain;
    this.elevationLoss = elevationLoss;
  }

  /**
   * Simplified track point for frontend rendering.
   * Stored as JSONB for efficient queries and minimal data transfer.
   */
  public record TrackPoint(
      double lat,
      double lng,
      double ele, // Elevation in meters
      double dist // Cumulative distance from start in meters
      ) implements Serializable {}
}
