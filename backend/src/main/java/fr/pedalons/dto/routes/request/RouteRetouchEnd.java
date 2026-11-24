package fr.pedalons.dto.routes.request;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.Valid;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "The new finish of a retouch: exactly one of a point and a place of the team")
@ValidateSchema
public record RouteRetouchEnd(
    @Nullable @Schema(description = "A position, e.g. a tap on the map") @Valid GeoPoint point,
    @Nullable
        @Schema(
            description =
                "A place of the route's team, by id: its position is the finish (400 VALIDATION on"
                    + " end.placeId when it is not one of the team's)")
        String placeId) {}
