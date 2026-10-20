package fr.pedalons.common.planner;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.service.route.GpxLimits;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import java.io.Serializable;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * Editing state of the route planner (docs/LEDGER_*.md WEB-100, C4a): the pieces of the track and
 * the junctions between them. A track of {@code n} pieces has {@code n + 1} junctions, so continuity
 * holds by construction. The server derives the saved track from it.
 */
@Schema(description = "Editing state of the route planner")
@ValidateSchema
@JsonIgnoreProperties(ignoreUnknown = true)
public record PlannerState(
    @Schema(required = true) int version,
    @Schema(required = true) RouterProfile profile,
    @Schema(required = true) @Size(max = GpxLimits.MAX_PLANNER_SOURCES)
        List<@Valid PlannerSource> sources,
    @Schema(required = true) @Size(max = GpxLimits.MAX_PLANNER_PIECES + 1)
        List<@Valid PlannerJunction> junctions,
    @Schema(required = true) @Size(max = GpxLimits.MAX_PLANNER_PIECES)
        List<@Valid PlannerPiece> pieces)
    implements Serializable {

  /** Whether the user drew any of it: one routed or straight piece (docs/LEDGER_*.md API-127). */
  public boolean drawn() {
    return pieces.stream().anyMatch(p -> p.mode() != PlannerPieceMode.IMPORTED);
  }
}
