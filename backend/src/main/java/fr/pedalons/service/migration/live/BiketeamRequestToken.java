package fr.pedalons.service.migration.live;

import fr.pedalons.dto.migration.BiketeamMigrationSummaryDto;
import java.time.Instant;

/**
 * A verified biketeam migration request (docs/plans/2026-09-22-biketeam-live-migration.md §3.2).
 * Only ever built by {@link BiketeamRequestTokenVerifier}, once the signature, the claims and the
 * return URL have all been checked.
 *
 * <p>It is not a credential: on its own it only buys the preview. Confirming needs a Pédalons
 * session, and what biketeam redeems is the grant minted then.
 *
 * <p>It carries no option: every migration is incremental. The {@code dryRun} and {@code reset}
 * claims a biketeam not yet updated still sends are not read (docs/LEDGER_*.md MIG-16).
 *
 * @param requestId the {@code jti}, biketeam's {@code pedalons_migration.id}
 * @param teamId biketeam team id, lower case — also the target team slug
 */
public record BiketeamRequestToken(
    String requestId,
    Instant issuedAt,
    Instant expiresAt,
    String teamId,
    String teamName,
    String requestedBy,
    String returnUrl,
    BiketeamMigrationSummaryDto summary) {

  /** Where biketeam's "Cancel" link goes: the callback, told the request was cancelled. */
  public String cancelUrl() {
    return returnUrl + "?request=" + requestId + "&outcome=cancelled";
  }
}
