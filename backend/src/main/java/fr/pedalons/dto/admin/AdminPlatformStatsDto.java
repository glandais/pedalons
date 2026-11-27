package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "Usage statistics of the platform or of one domain, for the platform administration."
            + " Counts only: no row names or identifies anyone. Deleted accounts and deleted"
            + " domains are left out unless a field says otherwise.")
@ValidateSchema
public record AdminPlatformStatsDto(
    @Schema(description = "When the figures were computed", required = true) Instant generatedAt,
    @Nullable @Schema(description = "The domain the figures are limited to; absent: all domains")
        String domainId,
    @Schema(required = true) AdminUserStatsDto users,
    @Schema(required = true) AdminAuthMethodStatsDto authMethods,
    @Schema(required = true) AdminPasskeyStatsDto passkeys,
    @Schema(
            description =
                "Accounts created per calendar month (UTC), the last 12 months, the current one"
                    + " included, oldest first, months without any included",
            required = true)
        List<AdminMonthCountDto> signupsByMonth,
    @Schema(required = true) AdminTeamStatsDto teams,
    @Schema(required = true) List<AdminGpsServiceStatsDto> gpsServices,
    @Schema(description = "Accounts with a connection to any GPS service", required = true)
        long usersWithGpsService,
    @Schema(required = true) List<AdminPushPlatformStatsDto> pushDevices,
    @Schema(
            description =
                "Distinct accounts per kind of client among the sessions used during the last 30"
                    + " days. Keys: MOBILE_APP (the Pédalons app), OAUTH (a third-party application"
                    + " authorised through OAuth), the lowercase device client of a paired device"
                    + " (garmin, karoo), WEB_MOBILE (a browser on a phone or tablet), WEB_DESKTOP"
                    + " (any other browser). An account counts once per kind, so the total can"
                    + " exceed the number of accounts.",
            required = true)
        List<AdminKeyCountDto> clientsLast30Days,
    @Schema(required = true) AdminCalendarStatsDto calendarFeeds) {}
