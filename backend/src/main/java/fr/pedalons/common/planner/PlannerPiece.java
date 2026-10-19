package fr.pedalons.common.planner;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import fr.pedalons.service.route.GpxLimits;
import jakarta.validation.constraints.Size;
import java.io.Serializable;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/** A piece of a planner track between two junctions. Flat rather than a oneOf, for the generators. */
@JsonIgnoreProperties(ignoreUnknown = true)
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
        Integer to,
    @Nullable
        @Schema(
            description =
                "ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint;"
                    + " edge 0 joins the first junction to the first interior point, the last edge"
                    + " ends at the last junction. Absent: surface unknown")
        @Size(max = GpxLimits.MAX_PLANNER_UNPAVED_SPANS)
        List<UnpavedSpan> unpaved)
    implements Serializable {}
