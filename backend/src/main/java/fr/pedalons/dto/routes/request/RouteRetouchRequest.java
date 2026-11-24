package fr.pedalons.dto.routes.request;

import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.PositiveOrZero;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "What to change in a saved route: exactly one of targetDistanceKm (aim at a total"
            + " distance) and end (move the finish)")
@ValidateSchema
public record RouteRetouchRequest(
    @Nullable
        @Schema(
            description =
                "The total distance aimed at, in kilometres (not the change). The bounds of the"
                    + " field are the offer's (GET .../retouch): minDistanceKm to maxDistanceKm")
        @DecimalMin("1")
        @DecimalMax("1000")
        Double targetDistanceKm,
    @Nullable @Schema(description = "The new finish") @Valid RouteRetouchEnd end,
    @Nullable
        @Schema(
            description =
                "From the team's roads (0) to discovery (1); rounded to the hundredth by the"
                    + " engine. Absent: 0.25")
        @DecimalMin("0")
        @DecimalMax("1")
        Double discovery,
    @Nullable
        @Schema(
            description =
                "Makes \"other proposals\" reproducible: the same seed gives the same routes."
                    + " Absent: 0")
        @PositiveOrZero
        Integer seed) {}
