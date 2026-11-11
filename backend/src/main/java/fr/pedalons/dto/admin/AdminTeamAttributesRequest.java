package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.TeamTier;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Platform admin request to update team governance attributes")
@ValidateSchema
public record AdminTeamAttributesRequest(
    @Schema(
            description = "Whether team admins can change visibility",
            examples = "false",
            required = true)
        boolean visibilityEditable,
    @Schema(
            description = "Whether any domain user can join this public team",
            examples = "false",
            required = true)
        boolean joinable,
    @Schema(
            description = "Whether team admins can add members",
            examples = "false",
            required = true)
        boolean addMemberAllowed,
    @Schema(
            description = "Whether the interactive route planner is open to this team",
            examples = "false",
            required = true)
        boolean enableRoutePlanner,
    // Optional so that a client unaware of the flag never withdraws it: a primitive would read an
    // omitted field as false (docs/LEDGER_*.md API-176).
    @Nullable
        @Schema(
            description =
                "Whether a private team may publish content as public or unlisted, readable by"
                    + " link only and kept out of every listing. Omitted: left as it is (off for a"
                    + " new team).",
            examples = "false")
        Boolean publicContentAllowed,
    // Optional for the same reason: a client unaware of the plan never downgrades a team
    // (docs/LEDGER_*.md BILL-10).
    @Nullable
        @Schema(
            description =
                "The team's plan: FREE caps the members and the route planner saves, UNLOCKED"
                    + " lifts both caps. Omitted: left as it is (FREE for a new team).",
            examples = "UNLOCKED")
        TeamTier tier,
    @Nullable
        @Size(max = 500)
        @Schema(
            description =
                "Why the team has its plan, for the platform admin only (« club pilote »,"
                    + " « offert par … »). Omitted: left as it is; blank clears it.",
            maxLength = 500)
        String tierNote) {}
