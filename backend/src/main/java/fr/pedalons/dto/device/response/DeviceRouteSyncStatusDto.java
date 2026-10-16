package fr.pedalons.dto.device.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.GpsRouteSyncState;
import fr.pedalons.enums.GpsServiceType;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * Where a registered group's route stands at one of the user's GPS services (docs/LEDGER_*.md
 * API-121), so a device can tell its route is already there. Deliberately compact — no external id,
 * no date: the Karoo payload is capped at 100 KB.
 */
@Schema(description = "Where the route stands at one of the user's GPS services")
@ValidateSchema
public record DeviceRouteSyncStatusDto(
    @Schema(description = "GPS service", required = true) GpsServiceType serviceType,
    @Schema(
            description =
                "SENT: at the service, up to date; OUTDATED: at the service in an older version"
                    + " that nothing will update, send it again; PENDING: to be sent or updated"
                    + " shortly; FAILING: the last attempt failed (a few retries, then it waits"
                    + " for the route to change); RECONNECT_REQUIRED: the connection must be"
                    + " renewed",
            required = true)
        GpsRouteSyncState state) {}
