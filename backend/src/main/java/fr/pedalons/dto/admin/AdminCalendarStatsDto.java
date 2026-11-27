package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Calendar feeds (iCal subscription links)")
@ValidateSchema
public record AdminCalendarStatsDto(
    @Schema(description = "Feeds created", required = true) long tokens,
    @Schema(description = "Feeds fetched at least once", required = true) long usedEver,
    @Schema(description = "Feeds fetched during the last 7 days", required = true)
        long usedLast7Days) {}
