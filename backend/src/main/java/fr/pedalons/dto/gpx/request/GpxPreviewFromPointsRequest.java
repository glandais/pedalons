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
 * Creation request for a GPX preview drawn from scratch with the planner: no GPX file, just a name
 * and the already-routed points or the editing state of the planner. A sibling of {@link
 * GpxPreviewUpdateRequest}, but one of the two is mandatory — there is nothing else to build the
 * track from (checked by the service: {@code GPX_EMPTY}).
 */
@Schema(description = "GPX preview creation request from planner points")
@ValidateSchema
public record GpxPreviewFromPointsRequest(
    @Schema(description = "Preview name", required = true) @NotBlank @Size(min = 3, max = 250)
        String name,
    @Nullable
        @Schema(
            description =
                "Points from frontend routing; points or plannerState, never both (400"
                    + " PLANNER_STATE_INVALID), and one of them (400 GPX_EMPTY)")
        @Size(max = GpxLimits.MAX_PLANNER_POINTS)
        List<@Valid GeoPoint> points,
    @Nullable
        @Schema(
            description =
                "Editing state of the planner; the server derives the track from it. Not with"
                    + " points")
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
                "Departure date and time, a wall time without offset, in the time zone of the"
                    + " first point of the track (not the device's). Present: the weather is"
                    + " computed when it falls within the next 7 days")
        EventDateTime departure,
    @Nullable
        @Schema(
            description =
                "Average speed in km/h, 1 to 100, to estimate the passage times of the weather."
                    + " Without one, 25 km/h is assumed",
            examples = "25")
        @Min(GpxLimits.MIN_AVERAGE_SPEED_KMH)
        @Max(GpxLimits.MAX_AVERAGE_SPEED_KMH)
        Float averageSpeed) {

  /** Without departure date and speed: the shape this record had before API-153. */
  public GpxPreviewFromPointsRequest(
      String name,
      @Nullable List<GeoPoint> points,
      @Nullable PlannerState plannerState,
      @Nullable List<WaypointRequest> waypoints) {
    this(name, points, plannerState, waypoints, null, null);
  }

  /** Without waypoints: the shape this record had before WEB-100 (C3c). */
  public GpxPreviewFromPointsRequest(
      String name, @Nullable List<GeoPoint> points, @Nullable PlannerState plannerState) {
    this(name, points, plannerState, null);
  }

  /** Points only: the shape this record had before WEB-100 (C4a). */
  public GpxPreviewFromPointsRequest(String name, List<GeoPoint> points) {
    this(name, points, null, null);
  }
}
