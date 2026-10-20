package fr.pedalons.dto.routes.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.dto.common.GeoJsonPoint;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "A waypoint of a route. Its geometry is where the author put it: its own position, never"
            + " its projection on the track")
@ValidateSchema
public record WaypointDto(
    @Schema(implementation = GeoJsonPoint.class, required = true) Point<G2D> geometry,
    @Schema(description = "Name, possibly empty", required = true) String name,
    @Nullable
        @Schema(
            description =
                "Identifier (TSID) of the waypoint, to send back in the request so that it keeps"
                    + " its origin. Null for a waypoint of a GPX file not saved yet")
        String id,
    @Schema(description = "What the waypoint is", required = true) WaypointType type,
    @Nullable @Schema(description = "Free text, at most 500 characters") String description,
    @Nullable
        @Schema(
            description =
                "Metres from the start along the tracks in order (cumulated from one track to the"
                    + " next, in the order of their ids). Null for a waypoint more than 50 m from"
                    + " the track")
        Double distance,
    @Schema(
            description =
                "Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED"
                    + " from. A new GPX file replaces the imported ones and keeps the author's",
            required = true)
        WaypointOrigin origin) {

  public static WaypointDto from(GpxWaypoint waypoint) {
    return new WaypointDto(
        waypoint.getGeometry(),
        waypoint.getName(),
        TsidUtils.toString(waypoint.getId()),
        waypoint.typeOrInfo(),
        waypoint.getDescription(),
        waypoint.getDistanceM(),
        waypoint.getOrigin());
  }
}
