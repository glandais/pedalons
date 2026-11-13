package fr.pedalons.dto.device.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Status;
import java.time.Instant;
import java.util.List;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * A stage of a trip the device's user is registered for, with the route to load for it: the
 * counterpart of {@link DeviceRegisteredGroupDto} for trips (docs/LEDGER_*.md API-168).
 */
@Schema(
    description =
        "Upcoming stage of a trip the user is registered for, with the route to load on the"
            + " device")
@Builder
@ValidateSchema
public record DeviceRegisteredStageDto(
    @Schema(description = "Team slug", required = true) String teamSlug,
    @Schema(description = "Trip slug", required = true) String tripSlug,
    @Schema(description = "Trip name", required = true) String tripName,
    @Schema(description = "Stage name", required = true) String stageName,
    @Schema(
            description =
                "Slug of the route to load: the stage's own route, never the trip's (a stage"
                    + " without a route is left out)",
            required = true)
        String routeSlug,
    @Schema(description = "Route name", required = true) String routeName,
    @Schema(description = "Distance in meters", required = true) float distance,
    @Schema(description = "Elevation gain in meters", required = true) float elevationGain,
    @Schema(description = "When the stage leaves, as an absolute instant (UTC)", required = true)
        Instant startDateTime,
    @Schema(description = "IANA time zone of the stage (e.g. Europe/Paris)", required = true)
        String timezone,
    @Schema(description = "Name of the place the stage leaves from, when it has one")
        @Nullable String startPlaceName,
    @Schema(description = "Name of the place the stage ends at, when it has one")
        @Nullable String endPlaceName,
    @Schema(
            description =
                "Where the route stands at each of the user's GPS services that hold it, as"
                    + " DeviceRegisteredGroupDto.syncStatuses",
            required = true)
        List<DeviceRouteSyncStatusDto> syncStatuses,
    @Schema(description = "Team name", required = true) String teamName,
    @Schema(
            description =
                "Status of the trip: PUBLISHED or CANCELLED (the stages of a cancelled trip are"
                    + " listed, for the device to say so)",
            required = true)
        Status status,
    @Schema(
            description =
                "When the stage is expected to end, as an absolute instant (UTC): its stored end,"
                    + " the departure plus three hours without one",
            required = true)
        Instant endDateTime) {}
