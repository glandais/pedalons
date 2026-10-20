package fr.pedalons.dto.gpx.request;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.service.route.GpxLimits;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * Update request for a GPX preview: rename it, and optionally redraw its track from planner points. A
 * new GPX file, when present, travels as a separate multipart part rather than in this JSON.
 */
@Schema(description = "GPX preview update request")
@ValidateSchema
public record GpxPreviewUpdateRequest(
    @Schema(description = "Preview name", required = true) @NotBlank @Size(min = 3, max = 250)
        String name,
    @Nullable
        @Schema(description = "Points from frontend routing")
        @Size(max = GpxLimits.MAX_PLANNER_POINTS)
        List<@Valid GeoPoint> points,
    @Nullable
        @Schema(
            description =
                "Editing state of the planner; the server derives the track from it. Not with"
                    + " points (400 PLANNER_STATE_INVALID); a gpxFile wins over it")
        @Valid
        PlannerState plannerState) {

  /** Without a planner state: the shape this record had before WEB-100 (C4a). */
  public GpxPreviewUpdateRequest(String name, @Nullable List<GeoPoint> points) {
    this(name, points, null);
  }
}
