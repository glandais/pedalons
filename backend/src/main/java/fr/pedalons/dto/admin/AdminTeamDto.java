package fr.pedalons.dto.admin;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.TeamTier;
import fr.pedalons.enums.Visibility;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Admin team view with domain info")
@ValidateSchema
public record AdminTeamDto(
    @Schema(description = "Team ID (TSID)", examples = "0h4a8xzk8jv80", required = true) String id,
    @Schema(description = "Team name", required = true) String name,
    @Schema(description = "Team URL slug", required = true) String slug,
    @Schema(description = "Domain ID this team belongs to", required = true) String domainId,
    @Schema(description = "Domain hostname", required = true) String domainName,
    @Schema(description = "Team visibility", required = true) Visibility visibility,
    @Schema(description = "Whether visibility is editable by team admins", required = true)
        boolean visibilityEditable,
    @Schema(description = "Whether any domain user can join this team", required = true)
        boolean joinable,
    @Schema(description = "Whether team admins can add members", required = true)
        boolean addMemberAllowed,
    @Schema(
            description = "Whether the interactive route planner is open to this team",
            required = true)
        boolean enableRoutePlanner,
    @Schema(
            description =
                "Whether a private team may publish content as public or unlisted, readable by"
                    + " link only and kept out of every listing",
            required = true)
        boolean publicContentAllowed,
    @Schema(
            description =
                "The team's plan: FREE caps the members and the route planner saves, UNLOCKED"
                    + " lifts both caps",
            required = true)
        TeamTier tier,
    @Nullable @Schema(description = "Why the team has its plan, for the platform admin only")
        String tierNote,
    @Schema(description = "Is team soft-deleted", required = true) boolean deleted,
    @Schema(description = "Number of members", required = true) long memberCount,
    @Schema(description = "Team creation timestamp", required = true) Instant createdAt) {

  public static AdminTeamDto from(Team team, long memberCount) {
    return new AdminTeamDto(
        TsidUtils.toString(team.getId()),
        team.getName(),
        team.getSlug(),
        TsidUtils.toString(team.getDomain().getId()),
        team.getDomain().getDomain(),
        team.getVisibility(),
        team.isVisibilityEditable(),
        team.isJoinable(),
        team.isAddMemberAllowed(),
        team.isEnableRoutePlanner(),
        team.isPublicContentAllowed(),
        team.getTier(),
        team.getTierNote(),
        team.isDeleted(),
        memberCount,
        team.getCreatedAt());
  }
}
