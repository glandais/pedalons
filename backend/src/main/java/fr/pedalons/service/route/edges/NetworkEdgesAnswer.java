package fr.pedalons.service.route.edges;

import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * What the pipeline keeps of an osm-route-details answer asked with {@code options.edges}
 * (docs/LEDGER_*.md API-198, lot 1): its identity, the edges, and the segments the unmatched
 * summary is read from. The indices of the edges (into the densified line that was sent) are
 * meaningless afterwards and are not stored.
 *
 * @param lengthM the length on the service's axis ({@code summary.length_m}, else the end of the
 *     last edge or segment)
 * @param dropped the service gave edges but the pipeline could not stitch or reindex them: a
 *     marker without data, counted as a stitch failure
 * @param tooShort the track was too short to be sent: {@code meta}, {@code edges} and {@code
 *     segments} are then empty
 */
public record NetworkEdgesAnswer(
    RouteDetailsResponse.@Nullable Meta meta,
    double lengthM,
    List<RouteDetailsResponse.Edge> edges,
    List<RouteDetailsResponse.Segment> segments,
    boolean tooShort,
    boolean dropped) {

  public NetworkEdgesAnswer(
      RouteDetailsResponse.@Nullable Meta meta,
      double lengthM,
      List<RouteDetailsResponse.Edge> edges,
      List<RouteDetailsResponse.Segment> segments,
      boolean tooShort) {
    this(meta, lengthM, edges, segments, tooShort, false);
  }

  /**
   * The edges of {@code response}, null when it carries none ({@code edges} absent: the option was
   * not honoured).
   */
  public static @Nullable NetworkEdgesAnswer of(RouteDetailsResponse response) {
    if (response.edgesDropped()) {
      return new NetworkEdgesAnswer(response.meta(), 0, List.of(), List.of(), false, true);
    }
    List<RouteDetailsResponse.Edge> edges = response.edges();
    if (edges == null) {
      return null;
    }
    edges = edges.stream().filter(java.util.Objects::nonNull).toList();
    List<RouteDetailsResponse.Segment> segments =
        response.segments() == null ? List.of() : response.segments();
    double length;
    if (response.summary() != null) {
      length = response.summary().lengthM();
    } else if (!edges.isEmpty() || !segments.isEmpty()) {
      double lastEdge = edges.isEmpty() ? 0 : edges.getLast().toM();
      double lastSegment = segments.isEmpty() ? 0 : segments.getLast().toM();
      length = Math.max(lastEdge, lastSegment);
    } else {
      length = 0;
    }
    return new NetworkEdgesAnswer(response.meta(), length, edges, segments, false);
  }

  /** A track too short to be sent: a document without edges, so that nothing asks again. */
  public static NetworkEdgesAnswer tooShort(double lengthM) {
    return new NetworkEdgesAnswer(null, lengthM, List.of(), List.of(), true);
  }
}
