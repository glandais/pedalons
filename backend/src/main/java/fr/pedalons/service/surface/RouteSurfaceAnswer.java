package fr.pedalons.service.surface;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * What the {@code full} answer of osm-route-details says of the surface of one track, and how to
 * read its distances on the track as stored (docs/LEDGER_*.md API-150).
 *
 * <p>The service's {@code d_m} and the stored {@code track_points.dist} are not one axis: Douglas-
 * Peucker keeps a fraction of the answer's points and the stored distance is measured on those
 * only, so the jitter of a recording and the wiggles of a stop stay in the first and vanish from
 * the second. The retained points are the anchors between the two: {@code answerM[k]} is the {@code
 * d_m} of the point stored at {@code storedM[k]}.
 *
 * @param segments the service's segments, on {@code d_m}; empty for a degenerate track, sent as a
 *     probe of its elevation
 * @param answerM non-decreasing, the {@code d_m} of each stored point
 * @param storedM non-decreasing, the distance of each stored point
 * @param dataVersions {@code meta.data_versions} of the first slice
 * @param complete whether the status of the answer is {@code complete}
 */
public record RouteSurfaceAnswer(
    List<Segment> segments,
    double[] answerM,
    double[] storedM,
    @Nullable JsonNode dataVersions,
    boolean complete) {

  /** The answer for a degenerate track: nothing to project, its length is all there is. */
  public static RouteSurfaceAnswer degenerate(
      double length, @Nullable JsonNode dataVersions, boolean complete) {
    return new RouteSurfaceAnswer(
        List.of(), new double[] {0, length}, new double[] {0, length}, dataVersions, complete);
  }

  /** The length of the track as stored. */
  public double storedLength() {
    return storedM.length == 0 ? 0 : storedM[storedM.length - 1];
  }
}
