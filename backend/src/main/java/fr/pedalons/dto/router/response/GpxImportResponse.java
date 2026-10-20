package fr.pedalons.dto.router.response;

import fr.pedalons.dto.routes.response.WaypointDto;
import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

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
            description = "Number of waypoints of the file (the first 500 are in waypoints)",
            required = true)
        int waypointCount,
    @Schema(
            description =
                "True when the elevations of a track could not all be read from the elevation"
                    + " source and part of them are the file's own",
            required = true)
        boolean elevationFallback,
    @Nullable
        @Schema(
            description =
                "The waypoints of the file, typed from their symbol, at most 500, in file order:"
                    + " imported, with no identifier and no distance (the server places them when"
                    + " the route is saved)")
        List<WaypointDto> waypoints) {

  /** Without the waypoints: the shape this record had before WEB-100 (C3c). */
  public GpxImportResponse(
      String name, List<GpxImportTrack> tracks, int waypointCount, boolean elevationFallback) {
    this(name, tracks, waypointCount, elevationFallback, null);
  }
}
