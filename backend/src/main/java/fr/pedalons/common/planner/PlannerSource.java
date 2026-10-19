package fr.pedalons.common.planner;

import fr.pedalons.service.route.GpxLimits;
import jakarta.validation.constraints.Size;
import java.io.Serializable;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/** A source track of a planner state: a stored track an imported piece refers to by index. */
public record PlannerSource(
    @Schema(
            description = "Polyline (precision 6, latitude then longitude) of the source track",
            required = true)
        @Size(max = GpxLimits.MAX_PLANNER_STATE_CHARS)
        String line,
    @Nullable
        @Schema(
            description =
                "One-dimension polyline (tenths of a metre), one value per point of line; absent:"
                    + " no elevation")
        @Size(max = GpxLimits.MAX_PLANNER_STATE_CHARS)
        String ele,
    @Schema(
            description =
                "Factor that recalibrates the raw climb of the source on a reference ascent (1"
                    + " without reference); in ]0, 100]",
            required = true)
        double ascendScale)
    implements Serializable {}
