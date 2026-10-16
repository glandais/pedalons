package fr.pedalons.dto.device.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

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
        List<DeviceRegisteredGroupDto> registeredGroups) {}
