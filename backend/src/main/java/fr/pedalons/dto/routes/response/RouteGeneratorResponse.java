package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Routes proposed by the route generator")
@ValidateSchema
public record RouteGeneratorResponse(
    @Schema(
            description = "One to three routes, best first, different from each other",
            required = true)
        List<GeneratedRouteDto> candidates,
    @Nullable
        @Schema(
            description =
                "When the team's roads were last prepared for the generator (the night before at"
                    + " best). Absent when the request did not use them (discovery)")
        Instant networkPreparedAt,
    @Schema(
            description =
                "True when part of the area around the start leaves the region the generator"
                    + " covers: proposals are rarer there",
            required = true)
        boolean partialCoverage) {}
