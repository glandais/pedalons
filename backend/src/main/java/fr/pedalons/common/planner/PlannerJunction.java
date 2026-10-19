package fr.pedalons.common.planner;

import java.io.Serializable;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * A point between two pieces (or at an end of the track). Piece {@code k} runs from junction {@code
 * k} to junction {@code k + 1}.
 */
public record PlannerJunction(
    @Schema(required = true) PlannerJunctionKind kind,
    @Schema(required = true) double lng,
    @Schema(required = true) double lat,
    @Nullable Double ele,
    @Nullable
        @Schema(
            description = "Index of the source track this point comes from; with idx or not at all")
        Integer source,
    @Nullable @Schema(description = "Index of this point in that source track") Integer idx)
    implements Serializable {}
