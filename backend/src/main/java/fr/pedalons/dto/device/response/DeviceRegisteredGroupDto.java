package fr.pedalons.dto.device.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.time.Instant;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * A ride group the device's user is registered in, with the route to load for it: everything a
 * device needs to fetch the track straight away, without going through the route's detail.
 */
@Schema(
    description =
        "Upcoming ride group the user is registered in, with the route to load on the device")
@Builder
@ValidateSchema
public record DeviceRegisteredGroupDto(
    @Schema(description = "Team slug", required = true) String teamSlug,
    @Schema(description = "Ride slug", required = true) String rideSlug,
    @Schema(description = "Ride name", required = true) String rideName,
    @Schema(description = "Name of the group the user is registered in", required = true)
        String groupName,
    @Schema(
            description =
                "Slug of the route to load: the group's own route, or the ride's when the group"
                    + " has none",
            required = true)
        String routeSlug,
    @Schema(description = "Route name", required = true) String routeName,
    @Schema(description = "Distance in meters", required = true) float distance,
    @Schema(description = "Elevation gain in meters", required = true) float elevationGain,
    @Schema(
            description =
                "When the group leaves, as an absolute instant (UTC): the group's startAt, the"
                    + " ride's own start when the group has no time. Devices render it in their"
                    + " own zone.",
            required = true)
        Instant startDateTime,
    @Schema(description = "IANA time zone of the ride (e.g. Europe/Paris)", required = true)
        String timezone) {}
