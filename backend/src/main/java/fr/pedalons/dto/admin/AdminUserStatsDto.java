package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(
    description =
        "Accounts of the platform (or of one domain). Every field but total and deleted counts"
            + " accounts that are not deleted; activity is based on the last sign-in date.")
@ValidateSchema
public record AdminUserStatsDto(
    @Schema(description = "Accounts that are not deleted", required = true) long total,
    @Schema(description = "Accounts deleted", required = true) long deleted,
    @Schema(description = "Accounts whose e-mail address is verified", required = true)
        long emailVerified,
    @Schema(description = "Accounts that accepted the terms", required = true) long termsAccepted,
    @Schema(description = "Platform administrators", required = true) long platformAdmins,
    @Schema(description = "Accounts with an avatar", required = true) long withAvatar,
    @Schema(description = "Accounts that never signed in", required = true) long neverLoggedIn,
    @Schema(description = "Accounts that signed in during the last 7 days", required = true)
        long activeLast7Days,
    @Schema(description = "Accounts that signed in during the last 30 days", required = true)
        long activeLast30Days,
    @Schema(description = "Accounts that signed in during the last 90 days", required = true)
        long activeLast90Days) {}
