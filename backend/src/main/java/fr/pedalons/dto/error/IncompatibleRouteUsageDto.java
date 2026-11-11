package fr.pedalons.dto.error;

import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Visibility;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * A ride or a trip, visible outside its team, that keeps a route from going {@code TEAM}
 * (docs/LEDGER_*.md API-176): one entry of {@link IncompatibleVisibilityDetails#getUsages()}.
 */
@Schema(description = "A ride or trip visible outside the team that uses the route")
@ValidateSchema
public record IncompatibleRouteUsageDto(
    @Schema(description = "RIDE or TRIP", required = true) PublicationType type,
    @Schema(description = "Ride or trip URL slug, in the route's team", required = true)
        String slug,
    @Schema(description = "Ride or trip name", required = true) String name,
    @Schema(description = "Its visibility: PUBLIC or PUBLIC_UNLISTED", required = true)
        Visibility visibility) {}
