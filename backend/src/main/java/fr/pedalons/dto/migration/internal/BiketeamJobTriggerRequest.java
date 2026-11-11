package fr.pedalons.dto.migration.internal;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.jspecify.annotations.Nullable;

/**
 * M2M, biketeam → Pédalons: redeem a grant and queue the migration. Hidden from the public
 * contract; see docs/plans/2026-09-22-biketeam-live-migration.md §5.1. {@code requestId} and {@code
 * teamId} must equal what the grant was minted for.
 *
 * <p>Unknown properties are ignored, explicitly: a biketeam not yet updated still sends {@code
 * dryRun} and {@code reset}, which no longer mean anything — every migration is incremental (docs/LEDGER_*.md
 * MIG-16).
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record BiketeamJobTriggerRequest(
    @NotBlank @Size(max = 64) @Nullable String requestId,
    @NotBlank @Size(max = 200) @Nullable String grant,
    @NotBlank @Size(max = 255) @Nullable String teamId) {}
