package fr.pedalons.dto.users.export;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.comment.Comment;
import fr.pedalons.domain.common.Publication;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ridetemplate.RideTemplate;
import fr.pedalons.domain.ridetemplate.RideTemplateGroup;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

/**
 * Content the user authored, i.e. everything reachable by {@code created_by_id}.
 *
 * <p>Geometry fields are typed as geolatte {@code Point} and serialize as GeoJSON — {@code
 * PedalonsJacksonConfig} registers {@code GeolatteGeomModule}, so this costs nothing here.
 */
public final class ContentExport {

  private ContentExport() {}

  /** Fields every {@link TeamEntity} carries, flattened into each record below. */
  public record TeamEntityEntry(
      String id,
      String teamSlug,
      String name,
      String slug,
      String markdown,
      String visibility,
      String status,
      Instant dateTime,
      @Nullable Instant publishAt,
      boolean deleted,
      Instant createdAt,
      Instant updatedAt) {

    public static TeamEntityEntry from(TeamEntity e) {
      return new TeamEntityEntry(
          TsidUtils.toString(e.getId()),
          e.getTeam().getSlug(),
          e.getName(),
          e.getSlug(),
          e.getMarkdown(),
          e.getVisibility().name(),
          e.getStatus().name(),
          e.getDateTime(),
          e.getPublishAt(),
          e.isDeleted(),
          e.getCreatedAt(),
          e.getUpdatedAt());
    }
  }

  /** {@code content/teams.json} — teams the user created (not teams they merely belong to). */
  public record TeamEntry(
      String id,
      String name,
      String slug,
      String visibility,
      @Nullable Point<G2D> geometry,
      boolean deleted,
      Instant createdAt,
      Instant updatedAt) {

    public static TeamEntry from(Team t) {
      return new TeamEntry(
          TsidUtils.toString(t.getId()),
          t.getName(),
          t.getSlug(),
          t.getVisibility().name(),
          t.getGeometry(),
          t.isDeleted(),
          t.getCreatedAt(),
          t.getUpdatedAt());
    }
  }

  /**
   * {@code content/publications.json} — rides, posts and trips in one file, matching the
   * single-table inheritance they already share. {@code type} is the discriminator.
   */
  public record PublicationEntry(String type, TeamEntityEntry entity, @Nullable String routeSlug) {

    public static PublicationEntry from(Publication p) {
      return switch (p) {
        case Ride ride ->
            new PublicationEntry(
                "RIDE",
                TeamEntityEntry.from(ride),
                ride.getRoute() == null ? null : ride.getRoute().getSlug());
        case Trip trip ->
            new PublicationEntry(
                "TRIP",
                TeamEntityEntry.from(trip),
                trip.getRoute() == null ? null : trip.getRoute().getSlug());
        default -> new PublicationEntry("POST", TeamEntityEntry.from(p), null);
      };
    }
  }

  /** {@code content/trip-stages.json}. */
  public record TripStageEntry(
      TeamEntityEntry entity,
      @Nullable String tripSlug,
      @Nullable String routeSlug,
      @Nullable Float averageSpeed,
      int sortOrder) {

    public static TripStageEntry from(TripStage s) {
      return new TripStageEntry(
          TeamEntityEntry.from(s),
          s.getTrip() == null ? null : s.getTrip().getSlug(),
          s.getRoute() == null ? null : s.getRoute().getSlug(),
          s.getAverageSpeed(),
          s.getSortOrder());
    }
  }

  /**
   * {@code content/routes.json}.
   *
   * <p>Tracks are summarised, not inlined: the full {@code trackPoints} JSONB is already in the GPX
   * file under {@code files/assets/}, and duplicating it here would multiply the JSON size by an
   * order of magnitude for no added information.
   */
  public record RouteEntry(
      TeamEntityEntry entity,
      @Nullable Float distance,
      @Nullable Float elevationGain,
      @Nullable Float elevationLoss,
      @Nullable Float hilliness,
      @Nullable String surfaceType,
      @Nullable Point<G2D> start,
      @Nullable Point<G2D> end,
      List<TrackSummary> tracks,
      List<WaypointEntry> waypoints) {

    public static RouteEntry from(Route r) {
      return new RouteEntry(
          TeamEntityEntry.from(r),
          r.getDistance(),
          r.getElevationGain(),
          r.getElevationLoss(),
          r.getHilliness(),
          r.getSurfaceType() == null ? null : r.getSurfaceType().name(),
          r.getStart(),
          r.getEnd(),
          r.getTracks().stream().map(TrackSummary::from).toList(),
          r.getWaypoints().stream().map(WaypointEntry::from).toList());
    }
  }

  public record TrackSummary(
      String id,
      String name,
      @Nullable Float distance,
      @Nullable Float elevationGain,
      @Nullable Float elevationLoss,
      int pointCount) {

    public static TrackSummary from(GpxTrack t) {
      return new TrackSummary(
          TsidUtils.toString(t.getId()),
          t.getName(),
          t.getDistance(),
          t.getElevationGain(),
          t.getElevationLoss(),
          t.getTrackPoints() == null ? 0 : t.getTrackPoints().size());
    }
  }

  public record WaypointEntry(
      String id,
      String name,
      @Nullable Point<G2D> geometry,
      @Nullable String type,
      @Nullable String description,
      @Nullable Double distance,
      @Nullable String origin) {

    public static WaypointEntry from(GpxWaypoint w) {
      return new WaypointEntry(
          TsidUtils.toString(w.getId()),
          w.getName(),
          w.getGeometry(),
          w.typeOrInfo().name(),
          w.getDescription(),
          w.getDistanceM(),
          w.getOrigin().name());
    }
  }

  /** {@code content/ads.json}. */
  public record AdEntry(
      TeamEntityEntry entity,
      @Nullable BigDecimal price,
      @Nullable String adType,
      @Nullable String rentalPeriod,
      @Nullable String locationDescription,
      @Nullable Point<G2D> locationGeometry) {

    public static AdEntry from(Ad a) {
      return new AdEntry(
          TeamEntityEntry.from(a),
          a.getPrice(),
          a.getAdType() == null ? null : a.getAdType().name(),
          a.getRentalPeriod() == null ? null : a.getRentalPeriod().name(),
          a.getLocationDescription(),
          a.getLocationGeometry());
    }
  }

  /** {@code content/team-pages.json}. */
  public record TeamPageEntry(
      TeamEntityEntry entity, @Nullable Integer pageOrder, boolean aboutPage) {

    public static TeamPageEntry from(TeamPage p) {
      return new TeamPageEntry(TeamEntityEntry.from(p), p.getPageOrder(), p.isAboutPage());
    }
  }

  /** {@code content/places.json}. */
  public record PlaceEntry(
      String id,
      String teamSlug,
      String name,
      @Nullable String address,
      @Nullable String link,
      boolean startPlace,
      boolean endPlace,
      @Nullable Point<G2D> geometry,
      Instant createdAt,
      Instant updatedAt) {

    public static PlaceEntry from(Place p) {
      return new PlaceEntry(
          TsidUtils.toString(p.getId()),
          p.getTeam().getSlug(),
          p.getName(),
          p.getAddress(),
          p.getLink(),
          p.isStartPlace(),
          p.isEndPlace(),
          p.getGeometry(),
          p.getCreatedAt(),
          p.getUpdatedAt());
    }
  }

  /** {@code content/comments.json}. */
  public record CommentEntry(
      String id,
      String content,
      String onEntitySlug,
      String onEntityName,
      @Nullable String parentId,
      Instant createdAt,
      Instant updatedAt) {

    public static CommentEntry from(Comment c) {
      TeamEntity on = c.getTeamEntity();
      return new CommentEntry(
          TsidUtils.toString(c.getId()),
          c.getContent(),
          on.getSlug(),
          on.getName(),
          c.getParent() == null ? null : TsidUtils.toString(c.getParent().getId()),
          c.getCreatedAt(),
          c.getUpdatedAt());
    }
  }

  /** {@code content/ride-groups.json}. */
  public record RideGroupEntry(
      String id,
      String rideSlug,
      String name,
      @Nullable LocalTime time,
      Instant startAt,
      @Nullable String routeSlug,
      @Nullable Float averageSpeed,
      @Nullable Integer maxParticipants,
      int sortOrder,
      Instant createdAt,
      Instant updatedAt) {

    public static RideGroupEntry from(RideGroup g) {
      return new RideGroupEntry(
          TsidUtils.toString(g.getId()),
          g.getRide().getSlug(),
          g.getName(),
          EventTimezoneResolver.ownTime(
              g.getRide().getDateTime(), g.getStartAt(), g.getRide().zone()),
          g.getStartAt(),
          g.getRoute() == null ? null : g.getRoute().getSlug(),
          g.getAverageSpeed(),
          g.getMaxParticipants(),
          g.getSortOrder(),
          g.getCreatedAt(),
          g.getUpdatedAt());
    }
  }

  /** {@code content/ride-templates.json}. */
  public record RideTemplateEntry(
      String id,
      String teamSlug,
      String name,
      String slug,
      String markdown,
      String visibility,
      String status,
      List<RideTemplateGroupEntry> groups,
      Instant createdAt,
      Instant updatedAt) {

    public static RideTemplateEntry from(RideTemplate t) {
      return new RideTemplateEntry(
          TsidUtils.toString(t.getId()),
          t.getTeam().getSlug(),
          t.getName(),
          t.getSlug(),
          t.getMarkdown(),
          t.getVisibility().name(),
          t.getStatus().name(),
          t.getGroups().stream().map(RideTemplateGroupEntry::from).toList(),
          t.getCreatedAt(),
          t.getUpdatedAt());
    }
  }

  public record RideTemplateGroupEntry(
      String id,
      String name,
      @Nullable LocalTime time,
      @Nullable Float averageSpeed,
      @Nullable Integer maxParticipants,
      int sortOrder) {

    public static RideTemplateGroupEntry from(RideTemplateGroup g) {
      return new RideTemplateGroupEntry(
          TsidUtils.toString(g.getId()),
          g.getName(),
          g.getTime(),
          g.getAverageSpeed(),
          g.getMaxParticipants(),
          g.getSortOrder());
    }
  }

  /**
   * {@code content/gpx-previews.json} — standalone GPX uploads from the GPX tools page. These never
   * become {@link Asset} rows, so nothing else in the export would find them.
   */
  public record GpxPreviewEntry(
      String id,
      String publicId,
      String name,
      float distance,
      float elevationGain,
      float elevationLoss,
      float hilliness,
      boolean hasThumbnail,
      Instant createdAt) {

    public static GpxPreviewEntry from(GpxPreview p) {
      return new GpxPreviewEntry(
          TsidUtils.toString(p.getId()),
          p.getPublicId().toString(),
          p.getName(),
          p.getDistance(),
          p.getElevationGain(),
          p.getElevationLoss(),
          p.getHilliness(),
          p.isHasThumbnail(),
          p.getCreatedAt());
    }
  }

  /**
   * {@code content/assets.json} — the index for everything under {@code files/}. {@code pathInZip}
   * is what ties a row to its bytes; route GPX and FIT files appear here too, distinguished only by
   * their {@code type}.
   */
  public record AssetEntry(
      String id,
      String type,
      String teamSlug,
      @Nullable String ownerEntitySlug,
      String fileName,
      String contentType,
      @Nullable Integer width,
      @Nullable Integer height,
      String pathInZip,
      Instant createdAt) {

    public static AssetEntry from(Asset a, String pathInZip) {
      TeamEntity owner = a.getTeamEntity();
      return new AssetEntry(
          TsidUtils.toString(a.getId()),
          a.getType().name(),
          a.getTeam().getSlug(),
          owner == null ? null : owner.getSlug(),
          a.getFileName(),
          a.getContentType(),
          a.getWidth(),
          a.getHeight(),
          pathInZip,
          a.getCreatedAt());
    }
  }
}
