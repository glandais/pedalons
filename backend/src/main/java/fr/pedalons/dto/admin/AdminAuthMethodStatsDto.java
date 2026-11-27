package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "How the accounts that are not deleted can sign in; the four add up to total")
@ValidateSchema
public record AdminAuthMethodStatsDto(
    @Schema(description = "A password and no passkey", required = true) long passwordOnly,
    @Schema(description = "A passkey and no password", required = true) long passkeyOnly,
    @Schema(description = "A password and a passkey", required = true) long passwordAndPasskey,
    @Schema(description = "Neither: one-time code sent by e-mail only", required = true)
        long neither) {}
