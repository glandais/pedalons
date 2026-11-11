package fr.pedalons.dto.pages.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.dto.common.ContentPermissionsDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.common.ContentPermissions;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Team page detail")
@ValidateSchema
public record TeamPageDto(
    @Schema(description = "Team", required = true) TeamPublicationDto team,
    @Schema(description = "Page ID (TSID)", required = true) String id,
    @Schema(description = "Page title", required = true) String title,
    @Schema(description = "Page URL slug", required = true) String slug,
    @Schema(description = "Page content", required = true) MediaDto media,
    @Schema(description = "Visibility level", required = true) Visibility visibility,
    @Schema(description = "Page order", required = true) int order,
    @Schema(description = "Whether the page is soft-deleted", required = true) boolean deleted,
    @Schema(
            description =
                "What the caller may do with the page: edit, delete (never the about page), and"
                    + " the visibilities it may be saved with.",
            required = true)
        ContentPermissionsDto permissions) {

  /**
   * @param permissions the caller's rights on this page (docs/LEDGER_*.md API-176)
   */
  public static TeamPageDto from(
      TeamPage page, AssetService assetService, ContentPermissions permissions) {
    return new TeamPageDto(
        TeamPublicationDto.from(page.getTeam(), permissions.teamAccessible(page.getTeam())),
        TsidUtils.toString(page.getId()),
        page.getName(),
        page.getSlug(),
        MediaDto.from(page, assetService),
        page.getVisibility(),
        page.getPageOrder() != null ? page.getPageOrder() : 0,
        page.isDeleted(),
        permissions.of(page));
  }
}
