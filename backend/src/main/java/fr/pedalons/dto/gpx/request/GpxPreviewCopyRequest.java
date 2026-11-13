package fr.pedalons.dto.gpx.request;

import fr.pedalons.dto.validation.AcceptableText;
import fr.pedalons.dto.validation.ValidateSchema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * The one parameter of a GPX preview's copy (docs/LEDGER_*.md API-197): the name of the copy.
 * Everything else comes from the source. Same constraints as {@code RouteDuplicateRequest}.
 */
@Schema(description = "GPX preview copy request")
@ValidateSchema
public record GpxPreviewCopyRequest(
    @Schema(description = "Name of the copy", required = true)
        @NotBlank
        @Size(min = 3, max = 200)
        @AcceptableText
        String name) {}
