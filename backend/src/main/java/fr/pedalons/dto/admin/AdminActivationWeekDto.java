package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import java.time.LocalDate;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(
    description =
        "Activation of the accounts created in one sign-up week on one domain: counts only, no"
            + " person named. The rates are the client's to compute, over signedUp.")
@ValidateSchema
public record AdminActivationWeekDto(
    @Schema(description = "Domain ID (TSID)", required = true) String domainId,
    @Schema(description = "Domain name", required = true) String domainName,
    @Schema(description = "Monday of the sign-up week (ISO week, UTC)", required = true)
        LocalDate weekStart,
    @Schema(
            description =
                "Whether every account of the week has had its 7 days: the counts of a week"
                    + " that is not complete can still grow",
            required = true)
        boolean complete,
    @Schema(description = "Accounts created that week, deleted ones left out", required = true)
        long signedUp,
    @Schema(description = "Of those, accounts whose address is verified", required = true)
        long verified,
    @Schema(
            description =
                "Of those, accounts that joined a team (or created one) within 7 days of their"
                    + " creation, and still belong to it",
            required = true)
        long joinedTeam,
    @Schema(
            description =
                "Of those, accounts that signed up to a ride within 7 days of their creation, and"
                    + " are still signed up",
            required = true)
        long joinedRide) {}
