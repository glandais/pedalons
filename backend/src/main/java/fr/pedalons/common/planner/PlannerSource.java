package fr.pedalons.common.planner;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import fr.pedalons.service.route.GpxLimits;
import jakarta.validation.constraints.Size;
import java.io.Serializable;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/** A source track of a planner state: a stored track an imported piece refers to by index. */
@JsonIgnoreProperties(ignoreUnknown = true)
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
        double ascendScale,
    @Nullable
        @Schema(
            description =
                "One-dimension polyline (tenths of a metre), one value per point of line: the"
                    + " ascent accumulated up to each point, as the server measured it (dead-band,"
                    + " non-decreasing, within [0, 100 000 m]). Absent: the client derives it from"
                    + " ele. Requires ele")
        @Size(max = GpxLimits.MAX_PLANNER_STATE_CHARS)
        String climb,
    @Nullable
        @Schema(
            description =
                "Polyline (precision 6, latitude then longitude) of the raw track of the file, as"
                    + " GpxImportTrack.shape gave it, never edited. An imported piece is cut out of"
                    + " it by projecting its junctions (from and to still index line); absent or"
                    + " inconsistent with line: line")
        @Size(max = GpxLimits.MAX_PLANNER_STATE_CHARS)
        String shape)
    implements Serializable {

  /** Without the raw track: the shape this record had before API-147 (phase C). */
  public PlannerSource(
      String line, @Nullable String ele, double ascendScale, @Nullable String climb) {
    this(line, ele, ascendScale, climb, null);
  }
}
