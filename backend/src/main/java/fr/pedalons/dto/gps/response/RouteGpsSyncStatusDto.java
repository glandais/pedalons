package fr.pedalons.dto.gps.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.GpsRouteSyncState;
import fr.pedalons.enums.GpsServiceType;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * Where a route stands at one of the caller's GPS services whose automatic sync is on
 * (docs/LEDGER_*.md API-120). Only ever about the caller's own connections — never anyone else's.
 */
@Schema(description = "Where the route stands at one of the caller's automatically synced services")
@ValidateSchema
public record RouteGpsSyncStatusDto(
    @Schema(description = "GPS service", required = true) GpsServiceType serviceType,
    @Schema(
            description =
                "SENT: at the service, up to date; OUTDATED: at the service in an older version"
                    + " that nothing will update, send it again; PENDING: to be sent or updated"
                    + " shortly; FAILING: the last attempt failed (a few retries, then it waits"
                    + " for the route to change); RECONNECT_REQUIRED: the connection must be"
                    + " renewed",
            required = true)
        GpsRouteSyncState state,
    @Nullable
        @Schema(
            description =
                "When the route was last sent to the service successfully. Absent while it never"
                    + " was.")
        Instant syncedAt) {}
