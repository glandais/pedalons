package fr.pedalons.dto.routes.response;

import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.TrackSurface;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/** A stretch of a track with one surface class (docs/LEDGER_*.md WEB-100, C1b). */
@Schema(
    description =
        "A stretch of a track with one surface class, in metres along the track (the M of its"
            + " line)")
@ValidateSchema
public record SurfaceSpanDto(
    @Schema(description = "Start, metres along the track", required = true) double from,
    @Schema(description = "End, metres along the track", required = true) double to,
    @Schema(required = true) TrackSurface surface) {}
