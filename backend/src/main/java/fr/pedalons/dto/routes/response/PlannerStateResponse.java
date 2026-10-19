package fr.pedalons.dto.routes.response;

import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * The editing state of the planner of a route or a preview, for its edit page (docs/LEDGER_*.md
 * WEB-100, C4a). Always a 200: {@code state} is null when there is nothing to read back (never
 * saved with one, track saved again without it, several tracks), and the editor then opens the
 * saved track as an import.
 */
@Schema(description = "Editing state of the planner of a route or a preview, if any")
@ValidateSchema
public record PlannerStateResponse(
    @Nullable @Schema(description = "The state; absent when there is none to read back")
        PlannerState state) {}
