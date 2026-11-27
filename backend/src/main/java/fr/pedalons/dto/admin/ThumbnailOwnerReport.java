package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "A route, ride or trip whose thumbnails were (or would be) redrawn")
@ValidateSchema
public record ThumbnailOwnerReport(
    @Schema(description = "Entity ID", required = true) String id,
    @Schema(description = "Entity kind", required = true) ThumbnailOwnerKind kind,
    @Schema(description = "Team slug", required = true) String teamSlug,
    @Schema(description = "Entity slug", required = true) String slug,
    @Schema(description = "Why it was selected", required = true)
        List<ThumbnailRegenerationReason> reasons,
    @Schema(description = "Its thumbnails before", required = true) List<ThumbnailFile> before,
    @Schema(description = "Its thumbnails after, absent on a dry run")
        @Nullable List<ThumbnailFile> after,
    @Schema(description = "What happened", required = true) ThumbnailRegenerationOutcome outcome,
    @Schema(description = "Error message when the regeneration itself failed")
        @Nullable String error) {

  public enum ThumbnailOwnerKind {
    ROUTE,
    RIDE,
    TRIP
  }

  public enum ThumbnailRegenerationReason {
    RENDERED_IN_WINDOW,
    SMALL_FILE,
    MISSING,
    OUTDATED,
    GIVEN_UP
  }

  public enum ThumbnailRegenerationOutcome {
    /** Dry run: would be redrawn. */
    PENDING,
    /** Both thumbnails redrawn. */
    REGENERATED,
    /** At least one thumbnail could not be drawn; the entity is left without it. */
    FAILED
  }

  @Schema(description = "One stored thumbnail")
  @ValidateSchema
  public record ThumbnailFile(
      @Schema(description = "Asset type", required = true) String type,
      @Schema(description = "Stored size in bytes, -1 when the file is missing", required = true)
          long bytes) {}
}
