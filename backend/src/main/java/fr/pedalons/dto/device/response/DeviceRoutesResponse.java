package fr.pedalons.dto.device.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Response containing rides and routes for device applications")
@Builder
@ValidateSchema
public record DeviceRoutesResponse(
    @Schema(description = "Upcoming rides with route entries", required = true)
        List<DeviceRideDto> rides,
    @Schema(description = "Latest standalone routes", required = true) List<DeviceRouteDto> routes,
    @Schema(
            description =
                "Upcoming ride groups the user is registered in (from 12 hours ago to 7 days"
                    + " ahead), earliest first, each with the route to load",
            required = true)
        List<DeviceRegisteredGroupDto> registeredGroups,
    // Only for a device that asks for it (`stages=true`): left out of the JSON otherwise, so the
    // response of a device that does not — the Garmin app, whose memory is counted — stays
    // exactly what it was (docs/LEDGER_*.md API-168).
    @JsonInclude(JsonInclude.Include.NON_NULL)
        @Schema(
            description =
                "Upcoming stages of the trips the user is registered for (each stage leaving"
                    + " from 12 hours ago to 7 days ahead), earliest first, each with the route"
                    + " to load. Present only when the request carries stages=true.")
        @Nullable List<DeviceRegisteredStageDto> registeredStages) {}
