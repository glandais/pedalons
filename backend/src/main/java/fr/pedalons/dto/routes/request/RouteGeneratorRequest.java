package fr.pedalons.dto.routes.request;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.CompassPoint;
import fr.pedalons.enums.RouteGeneratorType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "What to ask the team's route generator for")
@ValidateSchema
public record RouteGeneratorRequest(
    @Nullable
        @Schema(description = "Start. Absent: the team's location (400 VALIDATION if it has none)")
        @Valid
        GeoPoint start,
    @Nullable
        @Schema(
            description =
                "End. Absent: a loop, the route ends where it starts. Present: a one-way route"
                    + " from start to end")
        @Valid
        GeoPoint end,
    @Nullable
        @Schema(
            description =
                "Wished direction, only used when the end is closer than half the distance (a"
                    + " loop included)")
        CompassPoint bearing,
    @Schema(description = "Wished distance in kilometres, 10 to 300", required = true)
        @DecimalMin("10")
        @DecimalMax("300")
        double distanceKm,
    @Nullable
        @Schema(
            description =
                "0 prefers roads the team rides rarely, 1 the ones it rides often. Absent: 0.5")
        @DecimalMin("0")
        @DecimalMax("1")
        Double familiarity,
    @Nullable @Schema(description = "What to ride. Absent: ROAD") RouteGeneratorType type,
    @Nullable
        @Schema(
            description =
                "Makes \"other proposals\" reproducible: the same seed gives the same routes."
                    + " Absent: 0")
        Integer seed) {}
