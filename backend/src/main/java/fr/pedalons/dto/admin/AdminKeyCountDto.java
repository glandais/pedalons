package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "A count per key (a tier, a role, a client kind…) — counts only")
@ValidateSchema
public record AdminKeyCountDto(
    @Schema(description = "What is counted", required = true) String key,
    @Schema(description = "How many", required = true) long count) {}
