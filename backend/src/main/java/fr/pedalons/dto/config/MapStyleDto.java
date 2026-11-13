package fr.pedalons.dto.config;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * One basemap the clients may offer in their style switcher.
 *
 * <p>The list is served rather than compiled in because it used to be hard-coded on both clients —
 * the web shipped its own {@code mapStyles.ts} table and the mobile app a single {@code
 * tiles.versatiles.org/...} template, so changing a tile provider meant shipping two releases, and
 * the two lists had already drifted apart. Both now read this one, which changes with a restart.
 */
@Schema(description = "A basemap style the clients may offer")
@ValidateSchema
public record MapStyleDto(
    @Schema(description = "Stable style identifier, e.g. 'cycling'", required = true) String id,
    @Schema(description = "Human-readable label for the style switcher", required = true)
        String label,
    @Schema(
            description =
                "Section the switcher should list this style under — 'vector', 'satellite' or"
                    + " 'raster'. Clients group consecutive styles sharing a value and localise the"
                    + " heading themselves; an unknown value is rendered as its own section rather"
                    + " than dropped.",
            required = true)
        String group,
    @Schema(
            description =
                "URL of the MapLibre style document to load in light mode (or at all times when"
                    + " darkVariant is null). Either a third-party style document or, for a raster"
                    + " basemap the server wraps itself, a URL on /api/map/styles/{id}.json.",
            required = true)
        String url,
    @Nullable
        @Schema(
            description =
                "URL of the style document to load instead of 'url' when the client renders in dark"
                    + " mode. Null when the style has no dark counterpart — the client then keeps"
                    + " using 'url'.")
        String darkVariant,
    @Nullable
        @Schema(
            description =
                "Credit the style document does not declare itself, to be displayed IN ADDITION to"
                    + " the attribution the map engine derives from that document — not instead of"
                    + " it. Null for a style that credits itself (most of them) and for a raster"
                    + " basemap, whose credit is already on the source of the wrapper served at"
                    + " /api/map/styles/{id}.json. Non-null only where the provider ships no"
                    + " attribution at all, which would otherwise render the basemap uncredited.")
        String attribution) {}
