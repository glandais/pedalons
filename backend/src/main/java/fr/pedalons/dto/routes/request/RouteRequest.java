package fr.pedalons.dto.routes.request;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.WithVisibility;
import fr.pedalons.dto.validation.AcceptableText;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.route.GpxLimits;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

@Schema(description = "Route update request")
@ValidateSchema
public record RouteRequest(
    @Schema(description = "Route name", required = true)
        @NotBlank
        @Size(min = 3, max = 200)
        @AcceptableText
        String name,
    @Schema(description = "Media", required = true) @Valid MediaDto media,
    @Schema(description = "Surface type", required = true) SurfaceType surfaceType,
    @Schema(description = "Whether the route is publicly visible", required = true)
        Visibility visibility,
    @Nullable
        @Schema(description = "Points from frontend routing")
        @Size(max = GpxLimits.MAX_PLANNER_POINTS)
        @Valid
        List<GeoPoint> points,
    @Nullable
        @Schema(
            description =
                "IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set —"
                    + " at most 10, each a tag of this team and of kind ROUTE, else 400"
                    + " (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none"
                    + " on a creation, left as they are on an update.")
        List<String> tagIds,
    @Nullable
        @Schema(
            description =
                "Editing state of the planner; the server derives the track from it. Not with"
                    + " points (400 PLANNER_STATE_INVALID); a gpxFile wins over it")
        @Valid
        PlannerState plannerState)
    implements WithVisibility {

  /** Without tags: the shape this record had before API-59 — leaves the tags as they are. */
  public RouteRequest(
      String name,
      MediaDto media,
      SurfaceType surfaceType,
      Visibility visibility,
      @Nullable List<GeoPoint> points) {
    this(name, media, surfaceType, visibility, points, null, null);
  }

  /** Without a planner state: the shape this record had before WEB-100 (C4a). */
  public RouteRequest(
      String name,
      MediaDto media,
      SurfaceType surfaceType,
      Visibility visibility,
      @Nullable List<GeoPoint> points,
      @Nullable List<String> tagIds) {
    this(name, media, surfaceType, visibility, points, tagIds, null);
  }
}
