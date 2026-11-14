package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "A route proposed by the generator, every metre of it on a team road")
@ValidateSchema
public record GeneratedRouteDto(
    @Schema(
            description =
                "Geometry as a polyline of precision 6 (latitude then longitude), the encoding of"
                    + " the planner's GPX import",
            required = true)
        String polyline,
    @Schema(description = "Distance in metres", required = true) double distanceM,
    @Schema(description = "Elevation gain in metres", required = true) double ascentM,
    @Schema(description = "Elevation loss in metres", required = true) double descentM,
    @Nullable
        @Schema(
            description =
                "Angle in degrees between the wished bearing and the route's. Absent when the"
                    + " bearing did not apply")
        Double bearingDeviationDeg,
    @Schema(description = "How often the team rides these roads, 0 to 1", required = true)
        double familiarity,
    @Schema(description = "Share of the distance on unpaved roads, 0 to 1", required = true)
        double unpavedShare,
    @Schema(
            description = "Metres ridden twice (the way to and from the loop), counted once",
            required = true)
        double sharedM,
    @Schema(
            description = "Junctions crossed more than once outside the shared part",
            required = true)
        int crossings,
    @Schema(description = "Map frame of the route", required = true) BoundsDto bounds) {}
