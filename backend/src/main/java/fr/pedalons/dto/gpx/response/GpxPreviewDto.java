package fr.pedalons.dto.gpx.response;

import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;

import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.dto.routes.response.TrackDto;
import fr.pedalons.dto.routes.response.WaypointDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.service.route.ClimbNaming.NamedPoint;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * An analysed GPX file, shaped like the route detail payload so the frontend map and elevation
 * chart can render it unchanged.
 */
@Schema(description = "Analysed GPX file, not attached to any team")
@ValidateSchema
public record GpxPreviewDto(
    @Schema(description = "Public identifier used in URLs", required = true) String id,
    @Schema(description = "Track name", required = true) String name,
    @Schema(description = "Distance in meters", required = true) Float distance,
    @Schema(description = "Total elevation gain in meters", required = true) Float elevationGain,
    @Schema(description = "Total elevation loss in meters", required = true) Float elevationLoss,
    @Schema(description = "Elevation gain per kilometer", required = true) Float hilliness,
    @Schema(
            description =
                "Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is"
                    + " stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the"
                    + " precise profile. FAST: the fast profile is kept, the HD recomputation"
                    + " failed.",
            required = true)
        ElevationState elevationState,
    @Schema(description = "Whether the current user created this preview", required = true)
        boolean owned,
    @Schema(description = "Creation timestamp", required = true) Instant createdAt,
    @Schema(
            description =
                "Rendered map thumbnail template URL (with a {size} placeholder), used for link"
                    + " previews; null when no thumbnail was generated. Opaque URL: may carry a"
                    + " query string; substitute {size} only.")
        @Nullable String thumbnailUrl,
    @Schema(description = "URL to download the analysed GPX file", required = true) String gpxUrl,
    @Schema(description = "URL to download the analysed track as a FIT file", required = true)
        String fitUrl,
    @Schema(
            description =
                "Whether the track was drawn in the route planner (true) rather than imported from"
                    + " a GPX file. A drawn preview can only become a route of a team whose route"
                    + " planner is enabled; false when the origin is unknown",
            required = true)
        boolean drawn,
    @Schema(description = "Tracks", required = true) List<TrackDto> tracks,
    @Schema(description = "Waypoints", required = true) List<WaypointDto> waypoints) {

  public static GpxPreviewDto from(GpxPreview preview, boolean owned) {
    String publicId = preview.getPublicId().toString();
    return new GpxPreviewDto(
        publicId,
        preview.getName(),
        preview.getDistance(),
        preview.getElevationGain(),
        preview.getElevationLoss(),
        preview.getHilliness(),
        ElevationState.orHd(preview.getElevationState()),
        owned,
        preview.getCreatedAt(),
        preview.isHasThumbnail() ? "/api/gpx-previews/" + publicId + "/thumbnail/{size}" : null,
        "/api/gpx-previews/" + publicId + "/gpx",
        "/api/gpx-previews/" + publicId + "/fit",
        preview.isDrawn(),
        preview.getTracks().stream()
            .map(
                t ->
                    TrackDto.of(
                        t.trackPoints(),
                        t.climbs(),
                        preview.getWaypoints().stream()
                            .map(w -> new NamedPoint(w.name(), w.lat(), w.lng()))
                            .toList()))
            .toList(),
        preview.getWaypoints().stream()
            .map(w -> new WaypointDto(point(WGS84, g(w.lng(), w.lat())), w.name()))
            .toList());
  }
}
