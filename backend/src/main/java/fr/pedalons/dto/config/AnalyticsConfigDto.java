package fr.pedalons.dto.config;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * Where the site sends its audience counts. Only a path on the site's own origin: the counter is
 * served next to the site on every domain, so nothing leaves for a third party (plan
 * 2026-10-15-web-analytics.md, ledger API-117).
 */
@Schema(description = "Audience measurement settings for the site")
@ValidateSchema
public record AnalyticsConfigDto(
    @Schema(
            description =
                "Same-origin path the site sends a page view to (for example /count), without the"
                    + " query string.",
            required = true)
        String countPath) {}
