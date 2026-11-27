package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Teams and memberships")
@ValidateSchema
public record AdminTeamStatsDto(
    @Schema(description = "Teams that are not deleted", required = true) long active,
    @Schema(description = "Teams deleted", required = true) long deleted,
    @Schema(description = "Active teams per plan (FREE, UNLOCKED…)", required = true)
        List<AdminKeyCountDto> byTier,
    @Schema(
            description =
                "Memberships per role (MEMBER, ORGANIZER, ADMIN), active teams and accounts that"
                    + " are not deleted",
            required = true)
        List<AdminKeyCountDto> membershipsByRole,
    @Schema(
            description =
                "Accounts that are not deleted per number of active teams they belong to: keys"
                    + " \"0\", \"1\", \"2\", \"3+\"",
            required = true)
        List<AdminKeyCountDto> usersByTeamCount) {}
