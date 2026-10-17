package fr.pedalons.dto.ads.response;

import fr.pedalons.common.CoarseLocation;
import fr.pedalons.common.MarkdownExcerpt;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.dto.common.GeoJsonPoint;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.dto.tags.response.TagDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.RentalPeriod;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

@Schema(description = "Ad data")
@ValidateSchema
public record AdDto(
    @Schema(description = "Team", required = true) TeamPublicationDto team,
    @Schema(description = "Ad ID (TSID)", required = true) String id,
    @Schema(description = "Ad URL slug", required = true) String slug,
    @Schema(description = "Ad name", required = true) String name,
    @Schema(description = "Ad media", required = true) MediaDto media,
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
                "URL template of the ad's first picture, the one a card shows. Saves a compact row"
                    + " from carrying media.assets just to find it. Opaque URL: may carry a query"
                    + " string; substitute {size} only.")
        String thumbnailUrl,
    @Schema(
            description =
                "URL templates of every picture on the ad, in editor order — the gallery. Present"
                    + " whatever the 'view', so a compact row can show a carousel without pulling"
                    + " media.assets. The first entry is the same picture as 'thumbnailUrl'.",
            required = true)
        List<String> images,
    @Schema(description = "Ad status", required = true) Status status,
    @Schema(description = "Visibility level", required = true) Visibility visibility,
    @Schema(description = "Ad type", required = true) AdType adType,
    @Schema(description = "Price") @Nullable BigDecimal price,
    @Schema(
            description =
                "Period the price applies to, for a rental — render as 'price / period'. Null for a"
                    + " sale, and for a rental whose period has not been set.")
        @Nullable RentalPeriod rentalPeriod,
    @Schema(description = "Location description") @Nullable String locationDescription,
    @Nullable
        @Schema(
            description =
                "Approximate location of the ad, deliberately blurred: the point is the centre of a"
                    + " fixed cell about 1 km across, not the seller's address. Enough to tell a"
                    + " nearby ad from a distant one, and the same value on every read so repeated"
                    + " calls cannot be averaged back to the exact position. Null when the ad has"
                    + " no location. The exact point stays on AdEditDto, and only for the seller:"
                    + " the team's admins get this blurred point there too. Proximity filters"
                    + " measure from this blurred"
                    + " point too, never from the exact one.",
            implementation = GeoJsonPoint.class)
        Point<G2D> locationGeometry,
    @Schema(description = "Creation timestamp", required = true) Instant createdAt,
    @Schema(description = "Creation timestamp", required = true) Instant updatedAt,
    @Schema(description = "Creator ID (TSID)", required = true) String createdById,
    @Schema(
            description =
                "Display name of the member who posted the ad. The only thing about them this DTO"
                    + " carries: there is no contact channel on an Ad, and inventing one (an email,"
                    + " a phone number) is a product decision, not a serialisation one.",
            required = true)
        String createdByDisplayName,
    @Schema(description = "Whether the ad is soft-deleted", required = true) boolean deleted,
    @Schema(
            description =
                "The team's AD tags the ad carries, sorted by label. Empty when it carries none.",
            required = true)
        List<TagDto> tags) {

  public static AdDto from(Ad ad, AssetService assetService, ContentTags tags) {
    return from(ad, assetService, tags, ListViewMode.FULL);
  }

  /**
   * @param tags the tags of this whole page, resolved in one query by {@code TagLookup}
   * @param view {@link ListViewMode#COMPACT} leaves the description and the asset inventory out of the
   *     row; {@code excerpt} and {@code thumbnailUrl} carry what it renders instead
   */
  public static AdDto from(
      Ad ad, AssetService assetService, ContentTags tags, @Nullable ListViewMode view) {
    return new AdDto(
        TeamPublicationDto.from(ad.getTeam()),
        TsidUtils.toString(ad.getId()),
        ad.getSlug(),
        ad.getName(),
        MediaDto.from(ad, assetService, view),
        MarkdownExcerpt.of(ad.getMarkdown()),
        assetService.getFirstImageUrl(ad),
        assetService.getImageUrls(ad),
        ad.getStatus(),
        ad.getVisibility(),
        ad.getAdType(),
        ad.getPrice(),
        ad.getRentalPeriod(),
        ad.getLocationDescription(),
        // Blurred here rather than in the query: the exact point is what the owner edits, and one
        // place that decides how coarse a published location is beats two.
        CoarseLocation.blur(ad.getLocationGeometry()),
        ad.getCreatedAt(),
        ad.getUpdatedAt(),
        TsidUtils.toString(ad.getCreatedBy().getId()),
        ad.getCreatedBy().getDisplayName(),
        ad.isDeleted(),
        tags.forContent(ad.getId()));
  }
}
