package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "What the team's generator network is made of. Lengths in metres")
@ValidateSchema
public record RouteGeneratorNetworkDto(
    @Nullable
        @Schema(
            description =
                "Length of the road the search can reach around the start and the end. Absent when"
                    + " no route was generated")
        Double lengthM,
    @Schema(description = "Length of the whole network of the team", required = true)
        double totalLengthM,
    @Schema(description = "Routes the network is made of", required = true) int routeCount,
    @Schema(
            description =
                "Routes whose roads are still being analysed and are not in the network yet",
            required = true)
        int pendingRouteCount,
    @Schema(
            description = "Routes ticked \"ne pas utiliser pour générer des parcours\"",
            required = true)
        int excludedRouteCount,
    @Schema(
            description = "True when pendingRouteCount is above zero: the network may still grow",
            required = true)
        boolean incomplete) {}
