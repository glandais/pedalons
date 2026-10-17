package fr.pedalons.dto.geocode;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * One place matching a geocoding query.
 *
 * <p>Latitude and longitude are two named numbers here, whatever shape the upstream provider gives
 * them (a GeoJSON {@code [lon, lat]} position today) — a client should not have to know which
 * provider answered.
 *
 * <p>Both are {@code null} on a search suggestion the provider gave no position for — the common
 * case since API-129: the client resolves the one picked with {@code GET /api/geocode/place?id=}.
 * They are always set on that endpoint's answer.
 */
@Schema(description = "A place matching a geocoding query")
@ValidateSchema
public record GeocodeResultDto(
    @Schema(
            description =
                "Opaque identifier of the result, stable enough to key a list on; what GET"
                    + " /api/geocode/place takes to resolve the position",
            required = true)
        String id,
    @Schema(description = "Full human-readable name of the place", required = true)
        String displayName,
    @Schema(
            description =
                "Latitude in degrees (WGS 84). Null on a search suggestion the provider gave no"
                    + " position for: resolve it with GET /api/geocode/place once the user picks"
                    + " it. Always set in that endpoint's answer.")
        @Nullable Double lat,
    @Schema(
            description =
                "Longitude in degrees (WGS 84). Null exactly when lat is null: resolve it with GET"
                    + " /api/geocode/place once the user picks the suggestion.")
        @Nullable Double lon) {}
