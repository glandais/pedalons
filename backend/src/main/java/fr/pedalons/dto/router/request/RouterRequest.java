package fr.pedalons.dto.router.request;

import fr.pedalons.common.GeoPoint;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

public record RouterRequest(
    @Schema(required = true) @Valid GeoPoint from,
    @Schema(required = true) @Valid GeoPoint to,
    @Schema(required = true) RouterProfile profile,
    @Schema(
            description =
                "Slug of the team the route is being drawn for. When present, the team must have"
                    + " the route planner enabled and the caller must be allowed to create routes"
                    + " in it. When absent, the domain's GPX planner must be enabled.")
        @Size(max = 250)
        @Nullable String teamSlug,
    @Schema(
            description =
                "Propensity to climb, 0 (avoid hills) to 1 (no fear). Absent: the profile's value."
                    + " Bicycle profiles only; ignored otherwise.")
        @DecimalMin("0.0")
        @DecimalMax("1.0")
        @Nullable Double useHills,
    @Schema(
            description =
                "Propensity to ride with traffic, 0 (cycleways and paths) to 1 (roads). Absent:"
                    + " the profile's value (1 for FASTBIKE). Bicycle profiles only; ignored"
                    + " otherwise.")
        @DecimalMin("0.0")
        @DecimalMax("1.0")
        @Nullable Double useRoads) {}
