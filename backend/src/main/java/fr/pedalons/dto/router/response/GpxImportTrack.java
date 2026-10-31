package fr.pedalons.dto.router.response;

import fr.pedalons.dto.validation.ValidateSchema;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/** One track of an imported GPX file, processed with the FAST elevations, ready for the editor. */
@Schema(description = "A track of an imported GPX file")
@ValidateSchema
public record GpxImportTrack(
    @Schema(
            description =
                "Polyline (precision 6, latitude then longitude) of the processed track, as"
                    + " PlannerSource.line",
            required = true)
        String line,
    @Nullable
        @Schema(
            description =
                "One-dimension polyline (tenths of a metre), one value per point of line; absent"
                    + " when an elevation is not finite")
        String ele,
    @Nullable
        @Schema(
            description =
                "One-dimension polyline (tenths of a metre): the ascent accumulated up to each"
                    + " point of line (dead-band, non-decreasing, first 0, last = ascend); absent"
                    + " when ele is")
        String climb,
    @Schema(description = "Length in metres", required = true) double dist,
    @Schema(description = "Reported ascent in metres", required = true) double ascend,
    @Nullable
        @Schema(
            description =
                "Polyline (precision 6, latitude then longitude) of the raw track of the file, 2D,"
                    + " as sanitized, neither resampled nor simplified. Opaque to the client, which"
                    + " carries it into PlannerSource.shape. Only in the GPX import answer: always"
                    + " absent from the line-elevation answer, and absent from the import answer"
                    + " when the file's raw tracks together exceed the planner's point budget")
        String shape) {

  /** Without the raw track: the shape this record had before API-147 (phase C). */
  public GpxImportTrack(
      String line, @Nullable String ele, @Nullable String climb, double dist, double ascend) {
    this(line, ele, climb, dist, ascend, null);
  }
}
