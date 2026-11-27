package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "State of the automatic catch-up that redraws outdated map thumbnails")
@ValidateSchema
public record ThumbnailCatchUpStatus(
    @Schema(description = "Current version of the thumbnail drawing", required = true) int version,
    @Schema(description = "Whether the scheduled catch-up is switched on", required = true)
        boolean enabled,
    @Schema(description = "Entities the catch-up redraws per hour, per backend", required = true)
        int perHour,
    @Schema(
            description =
                "Entities with thumbnails drawn before the current version that the catch-up"
                    + " still has to redraw, those waiting for a retry included",
            required = true)
        int behind,
    @Schema(
            description = "Among the entities behind, those waiting for the next attempt",
            required = true)
        int waiting,
    @Schema(
            description = "Entities the catch-up gave up on after repeated failures",
            required = true)
        int givenUp) {}
