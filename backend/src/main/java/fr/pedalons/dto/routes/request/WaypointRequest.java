package fr.pedalons.dto.routes.request;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.dto.validation.AcceptableText;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/** A waypoint of the list that replaces a route's (or a preview's) waypoints. */
@Schema(description = "A waypoint of a route, as sent by the editor")
@ValidateSchema
public record WaypointRequest(
    @Nullable
        @Schema(
            description =
                "Identifier of an existing waypoint, as returned by the API: it keeps its origin."
                    + " Omitted or unknown: a new waypoint. Malformed or repeated: 400")
        String id,
    @Schema(description = "Where the waypoint is", required = true) @NotNull @Valid
        GeoPoint position,
    @Schema(description = "What the waypoint is", required = true) @NotNull WaypointType type,
    @Schema(
            description =
                "Name, possibly empty (the type's label then shows on a device). The editor limits"
                    + " it to 40 characters; the API accepts what an import can bring, up to 250",
            required = true)
        @NotNull
        @Size(max = 250)
        @AcceptableText
        String name,
    @Nullable
        @Schema(description = "Free text, at most 500 characters")
        @Size(max = 500)
        @AcceptableText
        String description,
    @Nullable
        @Schema(
            description =
                "The distance in metres the editor shows the waypoint at. Only used to pick which"
                    + " passage of a route that goes by twice the waypoint belongs to: the server"
                    + " recomputes the distance itself")
        @PositiveOrZero
        Double distance,
    @Nullable
        @Schema(
            description =
                "Origin of a new waypoint, AUTHOR by default. Ignored for a waypoint that exists:"
                    + " it keeps its own")
        WaypointOrigin origin) {}
