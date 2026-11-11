package fr.pedalons.dto.migration;

import com.fasterxml.jackson.annotation.JsonInclude;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.BiketeamMigrationBlockReason;
import fr.pedalons.enums.BiketeamMigrationTargetState;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * What the confirmation page shows before anyone has signed in: the request as biketeam signed it,
 * and what it would land on here. Nothing beyond what the signed request already says, plus the
 * name of the existing team it would land on or conflict with — which the team's public page shows anyway.
 *
 * <p>No class-level {@code @Schema}: SmallRye adds every type annotated with it to the OpenAPI
 * components, and the biketeam migration endpoints are hidden from the contract. The field-level
 * {@code required} flags stay, for {@link ValidateSchema}. Mirrored by hand in the frontend's
 * pages/biketeamMigration/biketeamMigrationApi.ts.
 */
@ValidateSchema
public record BiketeamMigrationPreviewDto(
    @Schema(description = "Biketeam request id", required = true) String requestId,
    @Schema(description = "Biketeam team id — the mapping key", required = true) String teamId,
    @Schema(description = "Biketeam team name", required = true) String teamName,
    @Schema(description = "The biketeam admin who asked, for display", required = true)
        String requestedBy,
    @Schema(description = "When the signed request expires", required = true) Instant expiresAt,
    @Schema(description = "What biketeam will send", required = true)
        BiketeamMigrationSummaryDto summary,
    @Schema(description = "Name of the Pédalons site the team lands on", required = true)
        String targetDomainName,
    @Schema(
            description =
                "Slug of the Pédalons team: the current one of an existing migrated team, otherwise"
                    + " the biketeam id normalised to a Pédalons slug",
            required = true)
        String targetTeamSlug,
    @Schema(description = "What the migration would land on", required = true)
        BiketeamMigrationTargetState targetState,
    @JsonInclude(JsonInclude.Include.ALWAYS)
        @Schema(
            description =
                "Name of the Pédalons team already at the slug (EXISTING_MIGRATED, SLUG_CONFLICT)")
        @Nullable String existingTeamName,
    @JsonInclude(JsonInclude.Include.ALWAYS)
        @Schema(
            description =
                "Name of the team migrated earlier and now in the Pédalons trash, set aside (its"
                    + " slug renamed, it stays in the trash) before the team is created anew; null"
                    + " otherwise")
        @Nullable String trashedTeamSetAside,
    @Schema(description = "Whether the signed-in user can confirm now", required = true)
        boolean confirmable,
    @JsonInclude(JsonInclude.Include.ALWAYS)
        @Schema(description = "Why it cannot be confirmed; null when confirmable")
        @Nullable BiketeamMigrationBlockReason blockReason,
    @Schema(description = "Where \"Cancel\" goes back to on biketeam", required = true)
        String cancelUrl) {}
