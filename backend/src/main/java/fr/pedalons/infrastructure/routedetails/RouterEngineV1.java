package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The wire records of {@code POST /v1/router/route} of osm-route-details, api 1.15 (plan
 * docs/plans/2026-11-23-itineraire-velo-osm.md §5). Only what Pédalons reads or sends; unknown keys
 * are ignored.
 */
public final class RouterEngineV1 {
  private RouterEngineV1() {}

  /** A point of a request. */
  public record Point(double lat, double lon) {}

  /** The request: {@code ride_type} is {@code road}, {@code gravel} or {@code mtb}. */
  public record Request(
      Point start, Point end, @JsonProperty("ride_type") String rideType, double cursor) {}

  /**
   * The answer. {@code polyline} is encoded with 6 digits; {@code unpaved} holds [first, last]
   * index ranges (inclusive) of the decoded polyline; absent, nothing is known of the surface.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Response(
      @Nullable String polyline,
      @JsonProperty("distance_m") double distanceM,
      @Nullable List<List<Integer>> unpaved) {}
}
