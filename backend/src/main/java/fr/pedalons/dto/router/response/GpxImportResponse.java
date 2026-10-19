package fr.pedalons.dto.router.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/** A GPX file turned into what the route editor loads: nothing is stored. */
@Schema(description = "A GPX file processed for the route editor")
@ValidateSchema
public record GpxImportResponse(
    @Schema(
            description =
                "Name of the file: its metadata, else its first track, else its file name",
            required = true)
        String name,
    @Schema(description = "Tracks in the order of the file, 1 to 8", required = true)
        List<GpxImportTrack> tracks,
    @Schema(
            description = "Number of waypoints of the file, which the editor does not keep",
            required = true)
        int waypointCount,
    @Schema(
            description =
                "True when the elevations of a track could not all be read from the elevation"
                    + " source and part of them are the file's own",
            required = true)
        boolean elevationFallback) {}
