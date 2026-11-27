package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Push notification devices of one platform")
@ValidateSchema
public record AdminPushPlatformStatsDto(
    @Schema(description = "The platform (ANDROID, IOS…)", required = true) String platform,
    @Schema(description = "Devices registered", required = true) long devices,
    @Schema(description = "Accounts with at least one device", required = true) long users,
    @Schema(description = "Devices seen during the last 7 days", required = true)
        long seenLast7Days) {}
