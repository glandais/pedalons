package fr.pedalons.dto.routes.response;

import fr.pedalons.common.MarkdownExcerpt;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.dto.tags.response.TagDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * Route DTO for list view.
 */
@Schema(description = "Route summary data")
@ValidateSchema
public record RouteDto(
    @Schema(description = "Route ID (TSID)", required = true) String id,
    @Schema(description = "Route slug", required = true) String slug,
    @Schema(description = "Team", required = true) TeamPublicationDto team,
    @Schema(description = "Route name", required = true) String name,
    @Schema(description = "Route description", required = true) MediaDto media,
    @Nullable
        @Schema(
            description =
                "Plain-text opening of the description, flattened (links become their label) and"
                    + " cut on a word boundary at about 200 characters. Null when the description"
                    + " holds no text. Lets a list row render its two lines without the description"
                    + " being sent at all — see the 'view' parameter.")
        String excerpt,
    @Nullable
        @Schema(
            description =
                "URL template of the route's thumbnail, light variant if there is one, else dark."
                    + " Saves a compact row from carrying media.assets just to find the map"
                    + " preview. Opaque URL: may carry a query string; substitute {size} only.")
        String thumbnailUrl,
    @Schema(description = "Distance in meters", required = true) Float distance,
    @Schema(description = "Total elevation gain in meters", required = true) Float elevationGain,
    @Schema(description = "Total elevation loss in meters", required = true) Float elevationLoss,
    @Schema(description = "Surface type", required = true) SurfaceType surfaceType,
    @Schema(description = "Whether the route is public", required = true) Visibility visibility,
    @Schema(description = "Creation timestamp", required = true) Instant createdAt,
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

  public static RouteDto from(
      Route route, AssetService assetService, CommentCounts commentCounts, ContentTags tags) {
    return from(route, assetService, commentCounts, tags, ListViewMode.FULL);
  }

  /**
   * @param tags the tags of this whole page, resolved in one query by {@code TagLookup}
   * @param view {@link ListViewMode#COMPACT} leaves the description and the asset inventory out of the
   *     row; {@code excerpt} and {@code thumbnailUrl} carry what it renders instead
   */
  public static RouteDto from(
      Route route,
      AssetService assetService,
      CommentCounts commentCounts,
      ContentTags tags,
      @Nullable ListViewMode view) {
    return new RouteDto(
        TsidUtils.toString(route.getId()),
        route.getSlug(),
        TeamPublicationDto.from(route.getTeam()),
        route.getName(),
        MediaDto.from(route, assetService, view),
        MarkdownExcerpt.of(route.getMarkdown()),
        thumbnailUrl(route, assetService),
        route.getDistance(),
        route.getElevationGain(),
        route.getElevationLoss(),
        route.getSurfaceType(),
        route.getVisibility(),
        route.getCreatedAt(),
        route.isDeleted(),
        commentCounts.forEntity(route.getId()),
        tags.forContent(route.getId()));
  }

  /** The route's own thumbnail, light preferred over dark — the map preview a card shows. */
  private static @Nullable String thumbnailUrl(Route route, AssetService assetService) {
    String light = null;
    String dark = null;
    for (var asset : route.getAssets()) {
      switch (asset.getType()) {
        case ROUTE_THUMBNAIL_LIGHT -> light = assetService.getImageUrl(asset);
        case ROUTE_THUMBNAIL_DARK -> dark = assetService.getImageUrl(asset);
        default -> {}
      }
    }
    return light != null ? light : dark;
  }
}
