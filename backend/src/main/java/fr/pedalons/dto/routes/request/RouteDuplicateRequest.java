package fr.pedalons.dto.routes.request;

import fr.pedalons.dto.validation.AcceptableText;
import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * The one parameter of a route's duplication (docs/LEDGER_*.md API-179): its name. Everything else
 * is the source's. Same constraints as {@link RouteRequest#name()}.
 */
@Schema(description = "Route duplication request")
@ValidateSchema
public record RouteDuplicateRequest(
    @Schema(description = "Name of the copy", required = true)
        @NotBlank
        @Size(min = 3, max = 200)
        @AcceptableText
        String name) {}
