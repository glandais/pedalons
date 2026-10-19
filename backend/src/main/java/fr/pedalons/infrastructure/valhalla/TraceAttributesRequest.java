package fr.pedalons.infrastructure.valhalla;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * A trace attributes request: a polyline6 matched on the network ({@code map_snap}), answered with
 * the attributes of the edges it follows. No {@code costing_options}, and in particular never {@code
 * avoid_bad_surfaces}, which makes the unpaved passages unmatched (38.9 % unknown instead of 0.8 % in
 * the trials of docs/research/2026-10-19-stadia-surfaces.md).
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record TraceAttributesRequest(
    @JsonProperty("encoded_polyline") String encodedPolyline,
    String costing,
    @JsonProperty("shape_match") String shapeMatch,
    Filters filters) {

  public static final String MAP_SNAP = "map_snap";

  /** What the answer is restricted to: the attributes of the filter, nothing else. */
  public record Filters(List<String> attributes, String action) {}

  public static final List<String> ATTRIBUTES =
      List.of(
          "edge.surface",
          "edge.use",
          "edge.cycle_lane",
          "edge.begin_shape_index",
          "edge.end_shape_index",
          "matched.type",
          "matched.edge_index",
          "matched.distance_along_edge",
          "shape",
          "osm_changeset");

  public static TraceAttributesRequest of(String encodedPolyline, String costing) {
    return new TraceAttributesRequest(
        encodedPolyline, costing, MAP_SNAP, new Filters(ATTRIBUTES, "include"));
  }
}
