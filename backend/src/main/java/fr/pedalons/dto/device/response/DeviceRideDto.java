package fr.pedalons.dto.device.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.time.Instant;
import java.util.List;
import lombok.Builder;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Ride information for device applications")
@Builder
@ValidateSchema
public record DeviceRideDto(
    @Schema(description = "Team slug", required = true) String teamSlug,
    @Schema(description = "Ride slug", required = true) String rideSlug,
    @Schema(description = "Ride name", required = true) String rideName,
    @Schema(description = "Start date/time") Instant startDateTime,
    @Schema(
            description =
                "IANA zone of the ride, as RideDto.timezone: the Karoo renders the starts in it,"
                    + " the Garmin app ignores it and renders in its own zone",
            required = true)
        String timezone,
    @Schema(description = "Route entries for this ride", required = true)
        List<DeviceRideEntryDto> entries) {}
