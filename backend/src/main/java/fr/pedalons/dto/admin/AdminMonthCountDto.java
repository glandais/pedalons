package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "A count for one calendar month (UTC)")
@ValidateSchema
public record AdminMonthCountDto(
    @Schema(description = "Calendar month, YYYY-MM (UTC)", examples = "2026-11", required = true)
        String month,
    @Schema(description = "How many", required = true) long count) {}
