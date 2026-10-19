package fr.pedalons.infrastructure.valhalla;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The part of a trace attributes answer the surface needs. {@code osmChangeset} is asked for in the
 * filter but was only seen in unfiltered answers: nullable.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record TraceAttributesResponse(
    @Nullable String shape,
    @Nullable List<Edge> edges,
    @Nullable @JsonProperty("matched_points") List<MatchedPoint> matchedPoints,
    @Nullable @JsonProperty("osm_changeset") Long osmChangeset) {

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Edge(
      @Nullable String surface,
      @Nullable String use,
      @Nullable @JsonProperty("cycle_lane") String cycleLane,
      @JsonProperty("begin_shape_index") int beginShapeIndex,
      @JsonProperty("end_shape_index") int endShapeIndex) {}

  /** {@code unmatched} points carry nothing else than their type. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record MatchedPoint(
      @Nullable String type,
      @Nullable @JsonProperty("edge_index") Integer edgeIndex,
      @Nullable @JsonProperty("distance_along_edge") Double distanceAlongEdge) {}
}
