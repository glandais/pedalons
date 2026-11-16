package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The wire records of the route generator of osm-route-details, api 1.9 ({@code
 * contract/openapi.json} of that repository, lot 3b plan §1). Only what Pédalons reads or sends;
 * unknown keys are ignored, so that a later api that adds some does not break the backend.
 */
public final class RouteGeneratorV1 {
  private RouteGeneratorV1() {}

  /** A point of a request. */
  public record GeoPoint(double lat, double lon) {}

  /** {@code POST /v1/generator/routes}. {@code end} and {@code bearing} are left out when null. */
  @JsonInclude(JsonInclude.Include.NON_NULL)
  public record GenerateRequest(
      GeoPoint start,
      @Nullable GeoPoint end,
      @Nullable String bearing,
      @JsonProperty("distance_m") double distanceM,
      @JsonProperty("ride_type") String rideType,
      double cursor,
      long seed) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record GenerateResponse(
      @JsonProperty("graph_id") @Nullable String graphId,
      @Nullable String mode,
      @Nullable String coverage,
      int dropped,
      @Nullable OverlayInfo overlay,
      @Nullable List<Route> routes) {

    /** Whether the disc around the start leaves the covered polygon ({@code partial}). */
    public boolean partialCoverage() {
      return "partial".equals(coverage);
    }
  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record OverlayInfo(@JsonProperty("deposited_at") @Nullable String depositedAt) {
    public @Nullable Instant depositedInstant() {
      return instant(depositedAt);
    }
  }

  /** One generated route; the distances come from the service's independent checker. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Route(
      String polyline,
      @JsonProperty("distance_m") double distanceM,
      @JsonProperty("team_m") double teamM,
      @JsonProperty("bridged_m") double bridgedM,
      @JsonProperty("team_share") double teamShare,
      @JsonProperty("tail_m") double tailM,
      int crossings,
      @JsonProperty("unpaved_m") double unpavedM,
      @JsonProperty("unpaved_share") double unpavedShare,
      @JsonProperty("bearing_deviation_deg") @Nullable Double bearingDeviationDeg,
      @JsonProperty("ascent_m") @Nullable Double ascentM,
      @JsonProperty("descent_m") @Nullable Double descentM) {}

  /** {@code GET /v1/generator/overlay}: {@code absent}, {@code ready} or {@code stale}. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record OverlayStatus(
      String state,
      @JsonProperty("graph_id") @Nullable String graphId,
      @JsonProperty("deposited_at") @Nullable String depositedAt,
      @JsonProperty("expires_at") @Nullable String expiresAt,
      @JsonProperty("source_digest") @Nullable String sourceDigest,
      @Nullable Long edges,
      @JsonProperty("stale_reason") @Nullable String staleReason) {

    public boolean ready() {
      return "ready".equals(state);
    }

    public @Nullable Instant depositedInstant() {
      return instant(depositedAt);
    }

    public @Nullable Instant expiresInstant() {
      return instant(expiresAt);
    }
  }

  /** What a deposit gave, for the log line only. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record DepositReport(
      @JsonProperty("graph_id") @Nullable String graphId,
      @JsonProperty("deposited_at") @Nullable String depositedAt,
      @JsonProperty("expires_at") @Nullable String expiresAt,
      long tracks,
      @JsonProperty("tracks_excluded") long tracksExcluded,
      @JsonProperty("tracks_unreadable") long tracksUnreadable,
      long edges,
      @JsonProperty("team_km") double teamKm,
      @JsonProperty("stored_bytes") long storedBytes,
      @Nullable DepositKm km) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record DepositKm(double total, double outside, double matched) {}

  /** An RFC 3339 instant, null when absent or unreadable. */
  static @Nullable Instant instant(@Nullable String text) {
    if (text == null) {
      return null;
    }
    try {
      return OffsetDateTime.parse(text).toInstant();
    } catch (DateTimeParseException e) {
      return null;
    }
  }
}
