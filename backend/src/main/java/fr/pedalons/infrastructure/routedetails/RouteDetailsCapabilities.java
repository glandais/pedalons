package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The part of {@code GET /v1/capabilities} Pédalons reads: the api version, the input bounds a
 * request must stay under (beyond them a 413, and the client slices, plan §3.1), the profiles, and
 * whether the fine surface is served (api 1.6).
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RouteDetailsCapabilities(
    @Nullable @JsonProperty("api_version") String apiVersion,
    @Nullable Limits limits,
    @Nullable Enums enums,
    @Nullable Data data) {

  /** The service's bounds as of api 1.6, used while it has not answered: those of osm-surface. */
  public static final Limits FALLBACK_LIMITS = new Limits(16_000, 200_000);

  /**
   * Bounds on the input only (points after the removal of consecutive duplicates, length), not on
   * the output.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Limits(
      @JsonProperty("max_points") int maxPoints, @JsonProperty("max_length_m") double maxLengthM) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Enums(
      @Nullable List<String> profiles,
      @Nullable @JsonProperty("surface_detail") List<String> surfaceDetail) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Data(@JsonProperty("surface_detail") boolean surfaceDetail) {}

  /** The published bounds, or {@link #FALLBACK_LIMITS} when they are missing or not positive. */
  public Limits effectiveLimits() {
    if (limits == null || limits.maxPoints() <= 0 || limits.maxLengthM() <= 0) {
      return FALLBACK_LIMITS;
    }
    return limits;
  }

  /** {@code options.profile = fast} is understood (api 1.5): otherwise a 400 on the unknown value. */
  public boolean supportsFast() {
    return enums != null
        && enums.profiles() != null
        && enums.profiles().contains(RouteDetailsProfile.FAST.value());
  }

  /** {@code segments[].surface.detail} is served (api 1.6). */
  public boolean supportsSurfaceDetail() {
    return data != null && data.surfaceDetail();
  }

  /** Whether {@code apiVersion} is at least {@code major.minor}; false when it is unreadable. */
  public boolean apiAtLeast(int major, int minor) {
    if (apiVersion == null) {
      return false;
    }
    String[] parts = apiVersion.trim().split("\\.");
    try {
      int ma = Integer.parseInt(parts[0]);
      int mi = parts.length > 1 ? Integer.parseInt(parts[1]) : 0;
      return ma > major || (ma == major && mi >= minor);
    } catch (NumberFormatException e) {
      return false;
    }
  }
}
