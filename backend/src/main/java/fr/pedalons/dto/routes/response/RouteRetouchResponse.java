package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.RouteRetouchOperation;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Proposals to retouch a saved route")
@ValidateSchema
public record RouteRetouchResponse(
    @Schema(description = "The operation answered", required = true)
        RouteRetouchOperation operation,
    @Schema(
            description = "Length of the original route's raw track in metres, the engine's own",
            required = true)
        double originalDistanceM,
    @Nullable
        @Schema(
            description =
                "Elevation gain of the original track, computed in the same batch as the"
                    + " proposals' so that before and after compare like with like")
        Double originalAscentM,
    @Nullable @Schema(description = "Elevation loss of the original track") Double originalDescentM,
    @Nullable @Schema(description = "RESIZE: the total distance asked, in metres")
        Double targetDistanceM,
    @Schema(description = "One to three proposals, best first", required = true)
        List<RetouchedRouteDto> candidates,
    @Nullable
        @Schema(
            description =
                "When the team's roads were last prepared for the generator. Absent when the"
                    + " request did not use them (discovery)")
        Instant networkPreparedAt) {}
