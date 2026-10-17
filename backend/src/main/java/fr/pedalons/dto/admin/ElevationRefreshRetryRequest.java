package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "Which abandoned HD elevation recomputations to start again: the routes and GPX-tool"
            + " previews whose request used up its attempts and stay on the fast profile.")
@ValidateSchema
public record ElevationRefreshRetryRequest(
    @Schema(
            description = "List what would be retried, without changing anything",
            examples = "true",
            required = true)
        boolean dryRun,
    @Schema(
            description = "Retry at most this many targets, oldest first (default 100)",
            examples = "100",
            minimum = "1",
            maximum = "1000")
        @Nullable Integer limit,
    @Schema(description = "Only this kind of target (default: both)")
        @Nullable ElevationRefreshKind kind) {}
