package fr.pedalons.dto.error;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Visibility;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * A route a ride or a trip cannot use with the visibility it is saved with (docs/LEDGER_*.md
 * API-176): one entry of {@link IncompatibleVisibilityDetails#getRoutes()}.
 */
@Schema(description = "A route whose visibility does not fit the ride or trip being saved")
@ValidateSchema
public record IncompatibleRouteDto(
    @Schema(description = "Route URL slug", required = true) String slug,
    @Schema(description = "Route name", required = true) String name,
    @Schema(description = "The route's visibility today (TEAM)", required = true)
        Visibility visibility,
    @Schema(
            description =
                "The visibility the route takes when the same request is replayed with"
                    + " alignVisibility = true: always PUBLIC_UNLISTED, even under a PUBLIC ride or"
                    + " trip — a route never becomes PUBLIC without an explicit decision.",
            required = true)
        Visibility proposedVisibility) {}
