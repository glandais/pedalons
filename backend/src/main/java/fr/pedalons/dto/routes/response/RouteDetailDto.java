package fr.pedalons.dto.routes.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.GeoJsonPoint;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.dto.tags.response.TagDto;
import fr.pedalons.dto.users.response.PublicUserDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.route.ClimbNaming.NamedPoint;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

/**
 * Route DTO for detail view with full information.
 */
@Schema(description = "Detailed route information")
@ValidateSchema
public record RouteDetailDto(
    @Schema(description = "Route ID (TSID)", required = true) String id,
    @Schema(description = "Route slug", required = true) String slug,
    @Schema(description = "Team", required = true) TeamPublicationDto team,
    @Schema(description = "Route name", required = true) String name,
    @Schema(description = "Media", required = true) MediaDto media,
    @Schema(description = "Distance in meters", required = true) Float distance,
    @Schema(description = "Total elevation gain in meters", required = true) Float elevationGain,
    @Schema(description = "Total elevation loss in meters", required = true) Float elevationLoss,
    @Schema(
            description =
                "Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is"
                    + " stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the"
                    + " precise profile. FAST: the fast profile is kept, the HD recomputation"
                    + " failed.",
            required = true)
        ElevationState elevationState,
    @Schema(description = "Surface type", required = true) SurfaceType surfaceType,
    @Schema(description = "Whether the route is public", required = true) Visibility visibility,
    @Schema(implementation = GeoJsonPoint.class) Point<G2D> start,
    @Schema(implementation = GeoJsonPoint.class) Point<G2D> end,
    @Schema(description = "Creator user", required = true) PublicUserDto createdBy,
    @Schema(description = "Creation timestamp", required = true) Instant createdAt,
    @Schema(description = "Last update timestamp", required = true) Instant updatedAt,
    @Schema(
            description =
                "Tracks, with the stored geometry untouched — every coordinate carries longitude,"
                    + " latitude, elevation and cumulative distance in meters. Empty when the bulk"
                    + " endpoint was called with 'geometry=false'.",
            required = true)
        List<TrackDto> tracks,
    @Schema(description = "Waypoints", required = true) List<WaypointDto> waypoints,
    @Schema(description = "Whether the route is soft-deleted", required = true) boolean deleted,
    @Nullable
        @Schema(
            description =
                "Number of comments, replies included. Absent when the caller may not read the"
                    + " comments of this route — comments are members-only, so an outsider is told"
                    + " nothing, not even zero.")
        Integer commentCount,
    @Schema(
            description =
                "The team's ROUTE tags the route carries, sorted by label. Empty when it carries"
                    + " none.",
            required = true)
        List<TagDto> tags) {

  /**
   * The route detail.
   *
   * <p>{@code withGeometry} false yields an empty {@code tracks} list rather than tracks holding
   * empty lines — a GeoJSON {@code LineString} with no coordinate is not a valid geometry. It
   * exists for the screens that show a route's name and figures without drawing it; everything
   * else about the payload is identical.
   *
   * @param tags the tags of the route — of the whole batch on the bulk path — from {@code
   *     TagLookup}
   */
  public static RouteDetailDto from(
      Route route,
      AssetService assetService,
      CommentCounts commentCounts,
      ContentTags tags,
      boolean withGeometry) {
    return new RouteDetailDto(
        TsidUtils.toString(route.getId()),
        route.getSlug(),
        TeamPublicationDto.from(route.getTeam()),
        route.getName(),
        MediaDto.from(route, assetService),
        route.getDistance(),
        route.getElevationGain(),
        route.getElevationLoss(),
        ElevationState.orHd(route.getElevationState()),
        route.getSurfaceType(),
        route.getVisibility(),
        route.getStart(),
        route.getEnd(),
        PublicUserDto.from(route.getCreatedBy()),
        route.getCreatedAt(),
        route.getUpdatedAt(),
        withGeometry
            ? route.getTracks().stream().map(t -> TrackDto.from(t, namedPoints(route))).toList()
            : List.of(),
        route.getWaypoints().stream().map(WaypointDto::from).toList(),
        route.isDeleted(),
        commentCounts.forEntity(route.getId()),
        tags.forContent(route.getId()));
  }

  /** The route's waypoints, to name the climbs they mark (docs/LEDGER_*.md API-10). */
  private static List<NamedPoint> namedPoints(Route route) {
    return route.getWaypoints().stream()
        .map(
            w ->
                new NamedPoint(
                    w.getName(),
                    w.getGeometry().getPosition().getLat(),
                    w.getGeometry().getPosition().getLon()))
        .toList();
  }
}
