package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "Which team overlays of the route generator to prepare now: the nightly pass, by hand."
            + " Without force, only the teams whose overlay is absent, stale, changed or about to"
            + " expire.")
@ValidateSchema
public record RouteGeneratorOverlayRefreshRequest(
    @Schema(description = "Only this team (default: every team of every domain)")
        @Nullable String teamId,
    @Schema(
            description =
                "Deposit every team again, whatever its overlay: after a key rotation or a new"
                    + " graph",
            required = true)
        boolean force,
    @Schema(
            description = "Say what would be done, without depositing or deleting anything",
            examples = "true",
            required = true)
        boolean dryRun) {}
