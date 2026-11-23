package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(
    description =
        "Activation of new accounts per sign-up week and domain, newest week first (ledger"
            + " API-213)")
@ValidateSchema
public record AdminActivationResponse(
    @Schema(
            description =
                "One row per week and domain that has at least one sign-up; a week without any is"
                    + " absent",
            required = true)
        List<AdminActivationWeekDto> weeks,
    @Schema(description = "How many weeks back the rows go", required = true) int weeksBack) {}
