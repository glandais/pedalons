package fr.pedalons.dto.publications.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.common.ContentVisibilityRules;
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
                "URL template of the team's logo (with a {size} placeholder), when it has one"
                    + " and the caller may download it. Same value as TeamDetailDto.logoUrl, so a"
                    + " publication can show its team's logo without loading the team. Absent when"
                    + " accessible is false and the private team does not publish content by link:"
                    + " its logo is then closed to the caller. Opaque URL: may carry a query"
                    + " string; substitute {size} only.")
        String logoUrl,
    @Schema(
            description =
                "Whether GET team answers the caller: the team is not private, or the caller is a"
                    + " member of it or a platform admin. A client loads the team, links to it or"
                    + " shows its header only when true; otherwise it renders this summary. The"
                    + " public content of a private team is read by link with this false.",
            required = true)
        boolean accessible) {

  /**
   * @param accessible whether {@code GET team} answers the caller — {@code
   *     ContentPermissions.teamAccessible}, the rule of {@code TeamAccessChecker.READ}
   *     (docs/LEDGER_*.md API-176)
   */
  public static TeamPublicationDto from(Team team, boolean accessible) {
    return new TeamPublicationDto(
        TsidUtils.toString(team.getId()),
        team.getName(),
        team.getSlug(),
        team.getVisibility(),
        // A caller who cannot open the team can download its logo only when the team publishes by
        // link (ContentVisibilityRules.privateTeamLogoIsPublic): otherwise no URL, never a broken
        // image (docs/LEDGER_*.md API-176).
        accessible || ContentVisibilityRules.privateTeamLogoIsPublic(team) ? logoUrl(team) : null,
        accessible);
  }

  /**
   * For a summary only ever served to a member of the team or to a platform admin — a membership,
   * a team the caller administers, a template only organizers read: {@code GET team} answers them
   * by construction.
   */
  public static TeamPublicationDto ofMember(Team team) {
    return from(team, true);
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
        team.getSlug(), team.getVisibility(), Visibility.valueOf(aboutVisibility), assetId, fileId);
  }
}
