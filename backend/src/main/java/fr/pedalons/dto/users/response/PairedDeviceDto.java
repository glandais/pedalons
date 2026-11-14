package fr.pedalons.dto.users.response;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.auth.AuthSession;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.PairedDeviceType;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(
    description =
        "A device (Karoo, Garmin) paired with the account by code, or an external application"
            + " the user authorized through OAuth")
@ValidateSchema
public record PairedDeviceDto(
    @Schema(description = "Pairing ID, to unpair the device", required = true) String id,
    @Schema(
            description =
                "Kind of device. OTHER for an external application: applicationName then names it",
            required = true)
        PairedDeviceType type,
    @Nullable
        @Schema(
            description =
                "For an access opened through OAuth, the name the application gave itself"
                    + " (client_id) — unverified. Absent for a device.")
        String applicationName,
    @Schema(description = "When the device was paired", required = true) Instant pairedAt,
    @Nullable @Schema(description = "When the device last renewed its access") Instant lastUsedAt) {

  public static PairedDeviceDto from(AuthSession session) {
    return new PairedDeviceDto(
        TsidUtils.toString(session.getId()),
        PairedDeviceType.fromClientId(session.getDeviceClient()),
        applicationName(session),
        session.getCreatedAt(),
        session.getLastUsedAt());
  }

  /** The {@code client_id} of a session opened by the OAuth flow, {@code oauth:<client_id>}. */
  private static @Nullable String applicationName(AuthSession session) {
    String deviceClient = session.getDeviceClient();
    return deviceClient != null && session.isOAuthApplication()
        ? deviceClient.substring(AuthSession.OAUTH_CLIENT_PREFIX.length())
        : null;
  }
}
