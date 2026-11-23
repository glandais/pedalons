package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "A route proposed by the generator")
@ValidateSchema
public record GeneratedRouteDto(
    @Schema(
            description =
                "Geometry as a polyline of precision 6 (latitude then longitude), the encoding of"
                    + " the planner's GPX import",
            required = true)
        String polyline,
    @Schema(description = "Distance in metres", required = true) double distanceM,
    @Nullable
        @Schema(
            description =
                "Elevation gain in metres. Absent when the profile was not ready in time: the"
                    + " editor computes it")
        Double ascentM,
    @Nullable @Schema(description = "Elevation loss in metres. Absent like the gain")
        Double descentM,
    @Nullable
        @Schema(
            description =
                "Angle in degrees between the wished bearing and the route's. Absent when the"
                    + " bearing did not apply")
        Double bearingDeviationDeg,
    @Schema(
            description =
                "Share of the distance on the team's roads, short gaps between them included, 0"
                    + " to 1",
            required = true)
        double teamShare,
    @Schema(
            description =
                "Share of the distance off pavement, 0 to 1, as the route page of a saved route"
                    + " measures it (surface tag, then track type, then road class)",
            required = true)
        double unpavedShare,
    @Nullable
        @Schema(
            description =
                "The share of unpaved asked for, 0 to 1. Absent when no target was sent: a road"
                    + " ride, a request without it, or an engine that does not steer")
        Double unpavedTarget,
    @Nullable
        @Schema(
            description =
                "Whether unpavedShare is within the engine's tolerance of unpavedTarget. Absent"
                    + " like unpavedTarget. False: the area has no better route, compare the two"
                    + " to tell more from less")
        Boolean unpavedTargetReached,
    @Schema(
            description = "Metres ridden twice (the way to and from the loop), counted once",
            required = true)
        double sharedM,
    @Schema(
            description = "Junctions crossed more than once outside the shared part",
            required = true)
        int crossings,
    @Schema(description = "Map frame of the route", required = true) BoundsDto bounds) {}
