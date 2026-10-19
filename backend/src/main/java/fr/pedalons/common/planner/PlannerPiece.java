package fr.pedalons.common.planner;

import fr.pedalons.service.route.GpxLimits;
import jakarta.validation.constraints.Size;
import java.io.Serializable;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/** A piece of a planner track between two junctions. Flat rather than a oneOf, for the generators. */
public record PlannerPiece(
    @Schema(required = true) PlannerPieceMode mode,
    @Nullable
        @Schema(
            description = "ROUTED and DIRECT: polyline6 of the points strictly inside the piece")
        @Size(max = GpxLimits.MAX_PLANNER_STATE_CHARS)
        String line,
    @Nullable
        @Schema(description = "ROUTED and DIRECT: one-dimension polyline of their elevations")
        @Size(max = GpxLimits.MAX_PLANNER_STATE_CHARS)
        String ele,
    @Nullable @Schema(description = "ROUTED: climb of the piece in metres") Double ascend,
    @Nullable @Schema(description = "IMPORTED: index of the source track") Integer source,
    @Nullable @Schema(description = "IMPORTED: index in the source of the first junction")
        Integer from,
    @Nullable @Schema(description = "IMPORTED: index in the source of the last junction")
        Integer to)
    implements Serializable {}
