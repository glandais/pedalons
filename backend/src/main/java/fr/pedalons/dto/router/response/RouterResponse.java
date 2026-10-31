package fr.pedalons.dto.router.response;

import fr.pedalons.common.planner.UnpavedSpan;
import fr.pedalons.dto.common.GeoJsonLineString;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.geolatte.geom.G3D;
import org.geolatte.geom.LineString;
import org.jspecify.annotations.Nullable;

public record RouterResponse(
    @Schema(implementation = GeoJsonLineString.class, required = true) LineString<G3D> route,
    double dist,
    double ascend,
    @Nullable
        @Schema(
            description =
                "Runs of unpaved edges of route (compacted surface or worse, from the router's own"
                    + " maneuvers), half-open, ascending and disjoint; edge i joins route points i"
                    + " and i + 1. Absent when the router gave no surface; empty when all paved")
        List<UnpavedSpan> unpaved,
    @Nullable
        @Schema(
            description =
                "Polyline (precision 6, latitude then longitude) of the router's raw geometry, 2D:"
                    + " the leg shapes concatenated as decoded, neither resampled nor simplified;"
                    + " its first and last points are the ends of route. Opaque to the client,"
                    + " which carries it into PlannerPiece.shape. Absent when there is no route")
        String shape) {

  /** Without the raw geometry: the shape this record had before API-147 (phase C). */
  public RouterResponse(
      LineString<G3D> route, double dist, double ascend, @Nullable List<UnpavedSpan> unpaved) {
    this(route, dist, ascend, unpaved, null);
  }
}
