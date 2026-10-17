package fr.pedalons.dto.publications.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Team information")
@ValidateSchema
public record TeamPublicationDto(
    @Schema(description = "Team ID (TSID)", examples = "0h4a8xzk8jv80", required = true) String id,
    @Schema(description = "Team name", required = true) String name,
    @Schema(description = "Team URL slug", required = true) String slug,
    @Schema(description = "Whether the team is public", required = true) Visibility visibility,
    @Nullable
        @Schema(
            description =
                "URL template of the team's logo (with a {size} placeholder), when it has one."
                    + " Same value as TeamDetailDto.logoUrl, so a publication can show its team's"
                    + " logo without loading the team. Opaque URL: may carry a query string;"
                    + " substitute {size} only.")
        String logoUrl) {
  public static TeamPublicationDto from(Team team) {
    return new TeamPublicationDto(
        TsidUtils.toString(team.getId()),
        team.getName(),
        team.getSlug(),
        team.getVisibility(),
        logoUrl(team));
  }

  /**
   * Built from the two formula columns of {@link Team}, never from the about page itself: a list
   * row must not load it (docs/LEDGER_*.md API-2).
   */
  private static @Nullable String logoUrl(Team team) {
    Long assetId = team.getLogoAssetId();
    String aboutVisibility = team.getAboutPageVisibility();
    Long fileId = team.getLogoFileId();
    if (assetId == null || fileId == null || aboutVisibility == null) {
      return null;
    }
    return AssetService.buildImageUrl(
        team.getSlug(), Visibility.valueOf(aboutVisibility), assetId, fileId);
  }
}
