package fr.pedalons.domain.gpx;

import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.io.Serializable;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.LazyGroup;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;
import org.jspecify.annotations.Nullable;

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

  @JdbcTypeCode(SqlTypes.JSON)
  @Column(name = "tracks", columnDefinition = "jsonb", nullable = false)
  private List<PreviewTrack> tracks;

  @JdbcTypeCode(SqlTypes.JSON)
  @Column(name = "waypoints", columnDefinition = "jsonb", nullable = false)
  private List<PreviewWaypoint> waypoints;

  /**
   * Whether a rendered map thumbnail (gpx-previews/{publicId}/thumbnail-light.png) was produced and
   * stored. Drives the Open Graph {@code og:image}: false previews fall back to the site default.
   */
  @Column(name = "has_thumbnail", nullable = false)
  private boolean hasThumbnail;

  /**
   * Whether the track was drawn in the planner (from points) rather than read from an imported GPX
   * file. Only a drawing is governed by the team's {@code enableRoutePlanner} when the preview
   * becomes a route. Previews that predate the column are false: their origin is unknown.
   */
  @Column(name = "drawn", nullable = false)
  private boolean drawn;

  /**
   * Where the stored profile stands (PENDING, HD or FAST); null means HD (docs/LEDGER_*.md API-131). Use
   * {@link ElevationState#orHd} to read it.
   */
  @Enumerated(EnumType.STRING)
  @Column(name = "elevation_state", length = 8)
  private @Nullable ElevationState elevationState;

  /**
   * Token of the track files ({@code gpx-previews/{publicId}/{filesRevision}/…}); null is the flat
   * layout of the existing previews. Every save of the track writes a new one; the HD catch-up (docs/LEDGER_*.md API-131) switches it.
   */
  @Column(name = "files_revision")
  private @Nullable Long filesRevision;

  /**
   * Editing state of the planner, read by its creator on the edit page only (docs/LEDGER_*.md WEB-100). Valid
   * while its track revision is {@link #filesRevision}. Lazy: up
   * to a few MB, and every path that loads the track must not pay for it.
   */
  @Basic(fetch = FetchType.LAZY)
  @JdbcTypeCode(SqlTypes.JSON)
  @Column(name = "planner_state", columnDefinition = "jsonb")
  private @Nullable PlannerStateDocument plannerState;

  /**
   * Surface along the tracks (docs/LEDGER_*.md WEB-100, C1b), valid while its revision is {@link
   * #filesRevision}. Lazy, in a group of its own, like {@link #plannerState}: read through
   * projections ({@code GpxPreviewRepository#findSurfaces}). Deliberately not a field of {@link
   * PreviewTrack}, which the JSONB reader of the previous release does not tolerate.
   */
  @Basic(fetch = FetchType.LAZY)
  @LazyGroup("surfaces")
  @JdbcTypeCode(SqlTypes.JSON)
  @Column(name = "surfaces", columnDefinition = "jsonb")
  private @Nullable PreviewSurfacesDocument surfaces;

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
