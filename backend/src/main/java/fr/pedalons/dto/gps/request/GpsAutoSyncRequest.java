package fr.pedalons.dto.gps.request;

import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.NotNull;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Turns the automatic route sync of one GPS service on or off")
@ValidateSchema
public record GpsAutoSyncRequest(
    @NotNull
        @Schema(
            description =
                "true to send the routes of the user's upcoming rides to this service"
                    + " automatically; false to stop, which also removes from the service the"
                    + " upcoming routes the sync sent",
            required = true)
        Boolean enabled) {}
