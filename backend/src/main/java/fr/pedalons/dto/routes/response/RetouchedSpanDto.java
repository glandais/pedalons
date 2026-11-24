package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "The stretch of a retouched route that changed")
@ValidateSchema
public record RetouchedSpanDto(
    @Schema(
            description =
                "Where on the ORIGINAL route, in metres from its start, the replaced stretch"
                    + " begins",
            required = true)
        double fromM,
    @Schema(
            description =
                "Where on the original route the replaced stretch ends; its length for MOVE_END"
                    + " and TRUNCATE (the rest is dropped)",
            required = true)
        double toM,
    @Schema(description = "Length of the new stretch in metres, 0 for TRUNCATE", required = true)
        double newM,
    @Schema(
            description =
                "Index in the polyline of the first point of the new stretch (up to it the"
                    + " polyline is the original route)",
            required = true)
        int startIndex,
    @Schema(
            description = "Index in the polyline of the last point of the new stretch",
            required = true)
        int endIndex,
    @Schema(
            description =
                "Share of the new stretch on the team's roads, 0 to 1 (measured on that stretch"
                    + " alone)",
            required = true)
        double teamShare,
    @Schema(
            description = "Share of the new stretch off pavement, 0 to 1 (as the route page)",
            required = true)
        double unpavedShare,
    @Schema(description = "Junctions the new stretch crosses more than once", required = true)
        int crossings) {}
