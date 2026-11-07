package fr.pedalons.dto.gpx.request;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.dto.common.EventDateTime;
import fr.pedalons.dto.routes.request.WaypointRequest;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.service.route.GpxLimits;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
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
        PlannerState plannerState,
    @Nullable
        @Schema(
            description =
                "The complete list of the waypoints, replacing them. Omitted: they stay as they"
                    + " are (placed again when the track changes)")
        @Size(max = GpxLimits.MAX_WAYPOINTS)
        List<@Valid WaypointRequest> waypoints,
    @Nullable
        @Schema(
            description =
                "Departure date and time, a wall time without offset, in the time zone of the first"
                    + " point of the track (not the device's). Omitted: kept (it follows the track"
                    + " if that moves to another zone). Present: the weather is computed when it"
                    + " falls within the next 7 days")
        EventDateTime departure,
    @Nullable
        @Schema(description = "Remove the departure date. Not with departure (400 BAD_REQUEST)")
        Boolean clearDeparture,
    @Nullable
        @Schema(
            description =
                "Average speed in km/h, 1 to 100, to estimate the passage times of the weather."
                    + " Omitted: kept. Without one, 25 km/h is assumed",
            examples = "25")
        @Min(GpxLimits.MIN_AVERAGE_SPEED_KMH)
        @Max(GpxLimits.MAX_AVERAGE_SPEED_KMH)
        Float averageSpeed,
    @Nullable
        @Schema(description = "Remove the average speed. Not with averageSpeed (400 BAD_REQUEST)")
        Boolean clearAverageSpeed) {

  /** Without departure date and speed: the shape this record had before API-153. */
  public GpxPreviewUpdateRequest(
      String name,
      @Nullable List<GeoPoint> points,
      @Nullable PlannerState plannerState,
      @Nullable List<WaypointRequest> waypoints) {
    this(name, points, plannerState, waypoints, null, null, null, null);
  }

  /** Without waypoints: the shape this record had before WEB-100 (C3c). */
  public GpxPreviewUpdateRequest(
      String name, @Nullable List<GeoPoint> points, @Nullable PlannerState plannerState) {
    this(name, points, plannerState, null);
  }

  /** Without a planner state: the shape this record had before WEB-100 (C4a). */
  public GpxPreviewUpdateRequest(String name, @Nullable List<GeoPoint> points) {
    this(name, points, null, null);
  }
}
