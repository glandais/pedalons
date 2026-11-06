package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * A {@code POST /v1/route-details} body: either a polyline with its precision, or points, never
 * both (a 400). Pédalons sends a polyline6 — about a third of the bytes of the points, and the
 * encoder already exists. The answer's {@code points[].index} and {@code segments[].from_index} /
 * {@code to_index} count the points of this polyline, from 0.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record RouteDetailsRequest(
    @Nullable String polyline,
    @Nullable @JsonProperty("polyline_precision") Integer polylinePrecision,
    @Nullable List<Point> points,
    @Nullable RouteDetailsOptions options) {

  public static final int POLYLINE_PRECISION = 6;

  /** An input point; any elevation would be ignored by the service, so none is sent. */
  public record Point(double lat, double lon) {}

  /** A polyline already encoded at precision 6. */
  public static RouteDetailsRequest ofPolyline6(String polyline6, RouteDetailsOptions options) {
    return new RouteDetailsRequest(polyline6, POLYLINE_PRECISION, null, options);
  }

  /**
   * The positions {@code from..toInclusive} of two parallel arrays, as a polyline6: a slice of a
   * longer track keeps its own indices, from 0 at {@code from}.
   */
  public static RouteDetailsRequest ofSlice(
      double[] lat, double[] lon, int from, int toInclusive, RouteDetailsOptions options) {
    return ofPolyline6(Polyline6Encoder.encode(lat, lon, from, toInclusive), options);
  }

  /** The profile the service will run, which picks the client and its read timeout. */
  public RouteDetailsProfile effectiveProfile() {
    return options == null ? RouteDetailsProfile.FULL : options.effectiveProfile();
  }
}
