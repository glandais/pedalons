package fr.pedalons.dto.users.response;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * What the profile overview shows next to each of its shortcuts, in one request: without it, the
 * overview would call one list endpoint per subject only to count its rows.
 *
 * <p>The rest of the overview reads the user itself ({@code GET /api/users/me}): the display
 * preferences, {@code contactableByMembers} and {@code connectedServices} are there already, and
 * are not repeated here. Neither are the user's outings: no client showed them on the profile any
 * more, so their counts went (contract {@code 16.0.0}, docs/LEDGER_*.md API-136) and {@code GET
 * /api/users/me/participations} serves them.
 */
@Schema(description = "The state of each subject of the current user's profile, for its overview")
@ValidateSchema
public record ProfileSummaryDto(
    @Schema(
            description =
                "The user's teams on this site, in name order, each with the user's role in it",
            required = true)
        List<ProfileTeamDto> teams,
    @Schema(description = "Number of passkeys registered on the account", required = true)
        int passkeyCount,
    @Schema(
            description =
                "Devices (Karoo, Garmin) paired with the account, newest first — the same rows as"
                    + " GET /api/users/me/devices",
            required = true)
        List<PairedDeviceDto> pairedDevices,
    @Schema(description = "Number of live accounts the user blocked", required = true)
        long blockedUserCount,
    @Schema(description = "Where the user's notifications go", required = true)
        ProfileNotificationSummaryDto notifications) {}
