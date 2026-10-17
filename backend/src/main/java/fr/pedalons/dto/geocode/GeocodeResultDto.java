package fr.pedalons.dto.geocode;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * One place matching a geocoding query.
 *
 * <p>Latitude and longitude are two named numbers here, whatever shape the upstream provider gives
 * them (a GeoJSON {@code [lon, lat]} position today) — a client should not have to know which
 * provider answered.
 */
@Schema(description = "A place matching a geocoding query")
@ValidateSchema
public record GeocodeResultDto(
    @Schema(
            description = "Opaque identifier of the result, stable enough to key a list on",
            required = true)
        String id,
    @Schema(description = "Full human-readable name of the place", required = true)
        String displayName,
    @Schema(description = "Latitude in degrees (WGS 84)", required = true) double lat,
    @Schema(description = "Longitude in degrees (WGS 84)", required = true) double lon) {}
