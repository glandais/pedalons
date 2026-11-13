package fr.pedalons.dto.device.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Status;
import java.time.Instant;
import java.util.List;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

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
                    + " ride's own start when the group has no time. The Karoo renders it in"
                    + " timezone, the Garmin app in its own zone.",
            required = true)
        Instant startDateTime,
    @Schema(description = "IANA time zone of the ride (e.g. Europe/Paris)", required = true)
        String timezone,
    // Not required: devices installed before docs/LEDGER_*.md API-121 never read it, and a
    // backend older than it never sends it.
    @Schema(
            description =
                "Where the route stands at each of the user's GPS services that hold it (sent"
                    + " automatically or uploaded by hand), so a device does not upload it again."
                    + " Empty when no service holds it; a device only reads its own service's"
                    + " entry (Karoo: HAMMERHEAD, Garmin: GARMIN).")
        List<DeviceRouteSyncStatusDto> syncStatuses,
    // The four below only for a device that asks for them (`details=true`), left out of the JSON
    // otherwise: the Garmin app parses the whole body in counted memory (docs/LEDGER_*.md API-194).
    @JsonInclude(JsonInclude.Include.NON_NULL)
        @Schema(description = "Team name. Only with details=true.")
        @Nullable String teamName,
    @JsonInclude(JsonInclude.Include.NON_NULL)
        @Schema(
            description =
                "Name of the place the ride leaves from, when it has one. Only with"
                    + " details=true.")
        @Nullable String startPlaceName,
    @JsonInclude(JsonInclude.Include.NON_NULL)
        @Schema(
            description =
                "Status of the ride: PUBLISHED or CANCELLED. Only with details=true — which also"
                    + " lists the groups of a cancelled ride, left out otherwise.")
        @Nullable Status status,
    @JsonInclude(JsonInclude.Include.NON_NULL)
        @Schema(
            description =
                "When the group is expected to arrive, as an absolute instant (UTC): its route's"
                    + " length at its speed, the departure plus three hours when either is"
                    + " missing. Only with details=true.")
        @Nullable Instant endDateTime) {}
