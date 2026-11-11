package fr.pedalons.dto.ads.response;

import fr.pedalons.common.CoarseLocation;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ad.Ad;
import fr.pedalons.dto.common.GeoJsonPoint;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.tags.response.TagDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.AdType;
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
public record AdEditDto(
    @Schema(description = "Team", required = true) TeamPublicationDto team,
    @Schema(description = "Ad ID (TSID)", required = true) String id,
    @Schema(description = "Ad URL slug", required = true) String slug,
    @Schema(description = "Ad name", required = true) String name,
    @Schema(description = "Ad media", required = true) MediaDto media,
    @Schema(description = "Ad status", required = true) Status status,
    @Schema(description = "Visibility level", required = true) Visibility visibility,
    @Schema(description = "Ad type", required = true) AdType adType,
    @Schema(description = "Price") @Nullable BigDecimal price,
    @Schema(description = "Rental period") @Nullable RentalPeriod rentalPeriod,
    @Nullable
        @Schema(
            description =
                "Location coordinates [longitude, latitude]. Exact for the ad's author only; any"
                    + " other editor (a team admin, a platform admin) gets the same blurred point"
                    + " as AdDto, the centre of a cell about 1 km across. Sending that blurred"
                    + " point back unchanged in an update by a non-author keeps the stored exact"
                    + " point; any other value replaces it.",
            implementation = GeoJsonPoint.class)
        Point<G2D> locationGeometry,
    @Schema(description = "Location description") @Nullable String locationDescription,
    @Schema(description = "Creation timestamp", required = true) Instant createdAt,
    @Schema(description = "Creation timestamp", required = true) Instant updatedAt,
    @Schema(description = "Creator ID (TSID)", required = true) String createdById,
    @Schema(description = "Whether the ad is soft-deleted", required = true) boolean deleted,
    @Schema(
            description =
                "The team's AD tags the ad carries, sorted by label — what the edit form's tagIds"
                    + " starts from.",
            required = true)
        List<TagDto> tags) {

  /**
   * @param exactLocation whether the caller is the ad's author: only the seller sees the exact
   *     point, anyone else editing the ad gets the blurred one (docs/LEDGER_*.md SEC-26)
   */
  public static AdEditDto from(
      Ad ad, AssetService assetService, boolean exactLocation, List<TagDto> tags) {
    return new AdEditDto(
        TeamPublicationDto.ofMember(ad.getTeam()),
        TsidUtils.toString(ad.getId()),
        ad.getSlug(),
        ad.getName(),
        MediaDto.from(ad, assetService),
        ad.getStatus(),
        ad.getVisibility(),
        ad.getAdType(),
        ad.getPrice(),
        ad.getRentalPeriod(),
        exactLocation ? ad.getLocationGeometry() : CoarseLocation.blur(ad.getLocationGeometry()),
        ad.getLocationDescription(),
        ad.getCreatedAt(),
        ad.getUpdatedAt(),
        TsidUtils.toString(ad.getCreatedBy().getId()),
        ad.isDeleted(),
        tags);
  }
}
