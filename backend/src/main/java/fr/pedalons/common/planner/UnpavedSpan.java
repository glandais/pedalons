package fr.pedalons.common.planner;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import fr.pedalons.dto.validation.ValidateSchema;
import java.io.Serializable;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * A run of unpaved edges, half-open: edges {@code from} to {@code to - 1}, edge {@code i} being the
 * segment between points {@code i} and {@code i + 1} (docs/LEDGER_*.md WEB-100, C1a).
 */
@Schema(
    description =
        "Half-open run of unpaved edges [from, to) of a line; edge i joins points i and i + 1")
@ValidateSchema
@JsonIgnoreProperties(ignoreUnknown = true)
public record UnpavedSpan(
    @Schema(required = true, minimum = "0") int from,
    @Schema(required = true, minimum = "1") int to)
    implements Serializable {}
