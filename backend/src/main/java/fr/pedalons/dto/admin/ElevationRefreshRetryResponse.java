package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Outcome of an HD elevation retry, one entry per target")
@ValidateSchema
public record ElevationRefreshRetryResponse(
    @Schema(description = "Whether this was a dry run (nothing changed)", required = true)
        boolean dryRun,
    @Schema(
            description = "Number of abandoned targets in the domain, before the limit",
            required = true)
        int matched,
    @Schema(
            description = "Targets listed, and retried unless dry run; at most the limit",
            required = true)
        List<ElevationRefreshRetryItem> items) {

  @Schema(description = "One abandoned recomputation")
  @ValidateSchema
  public record ElevationRefreshRetryItem(
      @Schema(description = "Kind of target", required = true) ElevationRefreshKind kind,
      @Schema(description = "ID of the route or preview", required = true) String targetId,
      @Schema(description = "Team slug (routes)") @Nullable String teamSlug,
      @Schema(description = "Route slug (routes)") @Nullable String routeSlug,
      @Schema(description = "Public identifier (previews)") @Nullable String previewPublicId,
      @Schema(description = "Failed attempts before the retry", required = true) int attempts,
      @Schema(description = "Last error recorded, before the retry") @Nullable String lastError,
      @Schema(description = "When the recomputation was first requested", required = true)
          Instant firstRequestedAt) {}
}
