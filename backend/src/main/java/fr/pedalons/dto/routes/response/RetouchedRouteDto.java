package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.RetouchKind;
import fr.pedalons.enums.RetouchVariant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "A route retouched by the generator's engine")
@ValidateSchema
public record RetouchedRouteDto(
    @Schema(
            description =
                "The WHOLE retouched route as a polyline of precision 6 (latitude then longitude),"
                    + " the encoding of the planner's GPX import",
            required = true)
        String polyline,
    @Schema(description = "Distance in metres", required = true) double distanceM,
    @Nullable
        @Schema(
            description =
                "Elevation gain in metres, measured as the original's (originalAscentM). Absent"
                    + " when the profile was not ready in time")
        Double ascentM,
    @Nullable @Schema(description = "Elevation loss in metres. Absent like the gain")
        Double descentM,
    @Schema(description = "What changed", required = true) RetouchKind kind,
    @Nullable @Schema(description = "Which choice a MOVE_END route makes. Absent for the others")
        RetouchVariant variant,
    @Schema(
            description = "Share of the original route kept as it was drawn, 0 to 1",
            required = true)
        double keptShare,
    @Schema(
            description =
                "Metres of the kept parts that the engine could not match to its map: there, the"
                    + " route may ride a road twice and nothing was checked",
            required = true)
        double unmatchedM,
    @Nullable
        @Schema(
            description =
                "MOVE_END and TRUNCATE: distance in metres from the asked finish to the last point"
                    + " of the route")
        Double endSnapM,
    @Schema(description = "The stretch that changed", required = true) RetouchedSpanDto changed,
    @Schema(description = "Map frame of the whole route", required = true) BoundsDto bounds) {}
