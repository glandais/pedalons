package fr.pedalons.dto.router.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/** The relief of straight lines, as the route editor loads it: nothing is stored. */
@Schema(description = "The relief of straight lines, processed with the FAST elevations")
@ValidateSchema
public record LineElevationResponse(
    @Schema(
            description =
                "One track per requested line, in the same order, from its start to its end",
            required = true)
        List<GpxImportTrack> lines,
    @Schema(
            description =
                "True when part of the elevations could not be read from the elevation source",
            required = true)
        boolean elevationFallback) {}
