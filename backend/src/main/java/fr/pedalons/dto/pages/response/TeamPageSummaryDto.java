package fr.pedalons.dto.pages.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Team page summary for listings")
@ValidateSchema
public record TeamPageSummaryDto(
    @Schema(description = "Page ID (TSID)", required = true) String id,
    @Schema(description = "Page title", required = true) String title,
    @Schema(description = "Page URL slug", required = true) String slug,
    @Schema(description = "Visibility level", required = true) Visibility visibility,
    @Schema(description = "Page order", required = true) int order,
    @Schema(description = "Whether the page is soft-deleted", required = true) boolean deleted,
    @Schema(
            description =
                "Publication status: a DRAFT is listed only to the team's administrators and the"
                    + " platform admin, who are told it is one (docs/LEDGER_*.md WEB-120)",
            required = true)
        Status status,
    @Schema(
            description =
                "Hidden by moderation: listed only to the team's organisers, administrators and"
                    + " the platform admin (docs/LEDGER_*.md WEB-120)",
            required = true)
        boolean moderationHidden) {

  public static TeamPageSummaryDto from(TeamPage page) {
    return new TeamPageSummaryDto(
        TsidUtils.toString(page.getId()),
        page.getName(),
        page.getSlug(),
        page.getVisibility(),
        page.getPageOrder() != null ? page.getPageOrder() : 0,
        page.isDeleted(),
        page.getStatus(),
        page.getModerationHiddenAt() != null);
  }
}
