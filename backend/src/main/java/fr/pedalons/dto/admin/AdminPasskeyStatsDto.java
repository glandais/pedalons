package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Passkeys of accounts that are not deleted")
@ValidateSchema
public record AdminPasskeyStatsDto(
    @Schema(description = "Passkeys registered", required = true) long total,
    @Schema(description = "Passkeys used during the last 30 days", required = true)
        long usedLast30Days) {}
