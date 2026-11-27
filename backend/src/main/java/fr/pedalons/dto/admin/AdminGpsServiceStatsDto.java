package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Connections to one GPS service and the routes sent through them")
@ValidateSchema
public record AdminGpsServiceStatsDto(
    @Schema(description = "The service (GARMIN, HAMMERHEAD)", required = true) String service,
    @Schema(description = "Connections", required = true) long connections,
    @Schema(description = "Accounts with at least one connection", required = true) long users,
    @Schema(description = "Connections with automatic sending on", required = true) long autoSync,
    @Schema(description = "Connections that must be reconnected", required = true)
        long reconnectRequired,
    @Schema(description = "Connections used during the last 30 days", required = true)
        long usedLast30Days,
    @Schema(description = "Routes sent or to send through these connections", required = true)
        long routeSyncs,
    @Schema(description = "Of which delivered", required = true) long routeSyncsSucceeded,
    @Schema(description = "Of which in error", required = true) long routeSyncsFailed) {}
