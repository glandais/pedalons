package fr.pedalons.dto.gps.response;

import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.GpsAutoSyncState;
import fr.pedalons.enums.GpsServiceType;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "GPS service connection information")
@ValidateSchema
public record GpsServiceConnectionDto(
    @Schema(description = "Service type identifier", required = true) GpsServiceType serviceType,
    @Schema(description = "Display name of the service", required = true) String displayName,
    @Schema(description = "When the service was connected", required = true) Instant connectedAt,
    @Schema(
            description =
                "Whether the routes of the rides the user is registered in are sent to this service"
                    + " automatically, and kept in sync (new route, corrected GPX, another group),"
                    + " from 7 days before the departure until a day after it",
            required = true)
        boolean autoSync,
    @Schema(
            description =
                "Where the automatic sync stands. OFF when autoSync is false; RECONNECT_REQUIRED"
                    + " is only cleared by connecting the service again",
            required = true)
        GpsAutoSyncState autoSyncState,
    @Schema(
            description =
                "How many routes the automatic sync currently has at the service (removed after"
                    + " the ride, or when the sync is turned off)",
            required = true)
        int autoSyncRouteCount,
    @Nullable @Schema(description = "When the automatic sync last sent a route to this service")
        Instant lastAutoSyncAt) {

  /**
   * The connection with the state of its automatic sync.
   *
   * @param routeCount routes the sync has at the service
   */
  public static GpsServiceConnectionDto from(
      GpsServiceConnection connection,
      GpsAutoSyncState state,
      long routeCount,
      @Nullable Instant lastSyncedAt) {
    return new GpsServiceConnectionDto(
        connection.getServiceType(),
        connection.getServiceType().getDisplayName(),
        connection.getConnectedAt(),
        connection.isAutoSync(),
        state,
        (int) routeCount,
        lastSyncedAt);
  }
}
