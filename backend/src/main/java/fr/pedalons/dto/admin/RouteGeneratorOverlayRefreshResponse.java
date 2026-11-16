package fr.pedalons.dto.admin;

import fr.pedalons.dto.validation.ValidateSchema;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "What the pass over the teams' overlays did, or would do (dry run)")
@ValidateSchema
public record RouteGeneratorOverlayRefreshResponse(
    @Schema(
            description =
                "False when nothing started: the generator is off or unconfigured, or a pass is"
                    + " already running",
            required = true)
        boolean started,
    @Nullable @Schema(description = "Identity of the graph the engine serves") String graphId,
    @Schema(
            description =
                "One entry per team that is deposited, deleted, or kept (dry run only: a started"
                    + " pass answers 202 with no entries, it runs in the background)",
            required = true)
        List<RouteGeneratorOverlayRefreshItem> items) {

  /** What is done with a team's overlay. */
  public enum Action {
    DEPOSIT,
    DELETE,
    KEEP
  }

  /** Why. */
  public enum Reason {
    ABSENT,
    STALE,
    CHANGED,
    EXPIRING,
    FORCED,
    CURRENT,
    TEAM_GONE,
    PLANNER_OFF
  }

  @Schema(description = "One team's overlay")
  @ValidateSchema
  public record RouteGeneratorOverlayRefreshItem(
      @Schema(description = "ID of the team", required = true) String teamId,
      @Schema(description = "Slug of the team", required = true) String teamSlug,
      @Schema(description = "What is done", required = true) Action action,
      @Schema(description = "Why", required = true) Reason reason,
      @Nullable @Schema(description = "State of the overlay at the engine: absent, ready or stale")
          String state,
      @Nullable @Schema(description = "When it was deposited") Instant depositedAt,
      @Nullable @Schema(description = "When the engine drops it if it is not deposited again")
          Instant expiresAt) {}
}
