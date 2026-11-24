package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.RouteGeneratorType;
import fr.pedalons.enums.RouteRetouchOperation;
import fr.pedalons.enums.RouteRetouchUnavailable;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "Whether a route can be retouched by the caller now, and within which bounds. Nothing is"
            + " computed to answer: the engine's capabilities and the heads of the route's stored"
            + " documents")
@ValidateSchema
public record RouteRetouchOfferDto(
    @Schema(description = "The retouch can be asked for now", required = true) boolean available,
    @Nullable
        @Schema(
            description =
                "Why not. NOT_ALLOWED and ENGINE_UNAVAILABLE: show nothing. NOT_READY: the route"
                    + " is still being analysed (show the action disabled). UNSUPPORTED: show"
                    + " nothing. Absent when available")
        RouteRetouchUnavailable unavailableReason,
    @Schema(description = "The operations offered; empty when not available", required = true)
        List<RouteRetouchOperation> operations,
    @Nullable
        @Schema(
            description = "Length of the route's raw track in metres. Absent when not available")
        Double originalDistanceM,
    @Nullable
        @Schema(
            description =
                "Smallest total distance of a RESIZE, in kilometres, rounded inwards to the tenth")
        Double minDistanceKm,
    @Nullable
        @Schema(
            description =
                "Largest total distance of a RESIZE, in kilometres, rounded inwards to the tenth")
        Double maxDistanceKm,
    @Nullable
        @Schema(
            description =
                "Smallest change of a RESIZE, in kilometres, above or below the route's length")
        Double minChangeKm,
    @Nullable
        @Schema(description = "Largest change of a RESIZE as a share of the route's length, 0 to 1")
        Double maxChangeShare,
    @Nullable
        @Schema(
            description = "How far from a way of the ride type the new finish may be, in metres")
        Double endSnapM,
    @Nullable @Schema(description = "Proposals returned at most") Integer proposalsMax,
    @Nullable
        @Schema(
            description = "The ride type the engine is asked for, from the route's surface type")
        RouteGeneratorType rideType) {}
