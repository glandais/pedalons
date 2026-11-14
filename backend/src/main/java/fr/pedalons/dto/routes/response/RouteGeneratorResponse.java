package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Routes proposed by the team's route generator")
@ValidateSchema
public record RouteGeneratorResponse(
    @Schema(
            description = "One to three routes, best first, different from each other",
            required = true)
        List<GeneratedRouteDto> candidates,
    @Schema(description = "What the team's network is made of", required = true)
        RouteGeneratorNetworkDto network,
    @Schema(
            description =
                "True when the team rides too few routes of the requested type nearby, so the"
                    + " familiarity of all kinds was used instead",
            required = true)
        boolean familiarityFallback) {}
