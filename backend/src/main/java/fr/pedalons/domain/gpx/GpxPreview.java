package fr.pedalons.domain.gpx;

import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.user.User;
import io.hypersistence.utils.hibernate.id.Tsid;
import io.hypersistence.utils.hibernate.type.json.JsonBinaryType;
import jakarta.persistence.*;
import java.io.Serializable;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.Type;
import org.hibernate.annotations.UpdateTimestamp;

/**
 * A GPX file uploaded through the GPX tools page, analysed but not attached to any team.
 *
 * <p>Standalone entity (hard delete, no {@code TeamEntity} hierarchy): a preview belongs to a
 * domain and a user, never to a team. It is purged after 30 days by {@code
 * GpxPreviewCleanupScheduler}.
 *
 * <p>{@code publicId} — and not the TSID — is what appears in URLs. TSIDs are sequential enough to
 * enumerate, and any authenticated user of the domain may open a preview by link, so the
 * identifier itself has to be unguessable.
 */
@Setter
@Getter
@Entity
@Table(
    name = "gpx_previews",
    indexes = {
      @Index(name = "idx_gpx_previews_public_id", columnList = "public_id", unique = true),
      @Index(name = "idx_gpx_previews_created_at", columnList = "created_at")
    })
@NoArgsConstructor
public class GpxPreview {

  @Id @Tsid private Long id;

  @Column(name = "public_id", nullable = false, unique = true)
  private UUID publicId;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "created_by_id", nullable = false)
  private User createdBy;

  @Column(name = "name", nullable = false, length = 250)
  private String name;

  @Column(name = "distance", nullable = false)
  private Float distance;

  @Column(name = "elevation_gain", nullable = false)
  private Float elevationGain;

  @Column(name = "elevation_loss", nullable = false)
  private Float elevationLoss;

  @Column(name = "hilliness", nullable = false)
  private Float hilliness;

  @Type(JsonBinaryType.class)
  @Column(name = "tracks", columnDefinition = "jsonb", nullable = false)
  private List<PreviewTrack> tracks;

  @Type(JsonBinaryType.class)
  @Column(name = "waypoints", columnDefinition = "jsonb", nullable = false)
  private List<PreviewWaypoint> waypoints;

  /**
   * Whether a rendered map thumbnail (gpx-previews/{publicId}/thumbnail-light.png) was produced and
   * stored. Drives the Open Graph {@code og:image}: false previews fall back to the site default.
   */
  @Column(name = "has_thumbnail", nullable = false)
  private boolean hasThumbnail;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @Version private Long version;

  public GpxPreview(
      UUID publicId,
      Domain domain,
      User createdBy,
      String name,
      float distance,
      float elevationGain,
      float elevationLoss,
      float hilliness,
      List<PreviewTrack> tracks,
      List<PreviewWaypoint> waypoints) {
    this.publicId = publicId;
    this.domain = domain;
    this.createdBy = createdBy;
    this.name = name;
    this.distance = distance;
    this.elevationGain = elevationGain;
    this.elevationLoss = elevationLoss;
    this.hilliness = hilliness;
    this.tracks = tracks;
    this.waypoints = waypoints;
  }

  /**
   * A computed track, stored as JSONB. No PostGIS geometry: previews are never queried spatially,
   * only rendered.
   */
  public record PreviewTrack(
      String name,
      List<GpxTrack.TrackPoint> trackPoints,
      List<ClimbData> climbs,
      float distance,
      float elevationGain,
      float elevationLoss)
      implements Serializable {}

  public record PreviewWaypoint(String name, double lat, double lng) implements Serializable {}
}
