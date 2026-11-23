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
    @Nullable Data data,
    @Nullable GeneratorSection generator,
    @Nullable RouterSection router) {

  /** Without {@code generator}: the shape this record had before api 1.9. */
  public RouteDetailsCapabilities(
      @Nullable String apiVersion,
      @Nullable Limits limits,
      @Nullable Enums enums,
      @Nullable Data data) {
    this(apiVersion, limits, enums, data, null, null);
  }

  /** Without {@code router}: the shape this record had before api 1.15. */
  public RouteDetailsCapabilities(
      @Nullable String apiVersion,
      @Nullable Limits limits,
      @Nullable Enums enums,
      @Nullable Data data,
      @Nullable GeneratorSection generator) {
    this(apiVersion, limits, enums, data, generator, null);
  }

  /**
   * {@code router} (api 1.15): the point to point engine of the planner, its ride types and the
   * bounds of a leg.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record RouterSection(
      boolean enabled,
      @Nullable @JsonProperty("ride_types") List<String> rideTypes,
      @Nullable @JsonProperty("crow_m_max") Double crowMMax,
      @Nullable @JsonProperty("snap_m") Double snapM,
      @JsonProperty("use_roads") boolean useRoads,
      @JsonProperty("avoid_main_roads") boolean avoidMainRoads) {

    /** Without {@code use_roads}: the shape this record had before api 1.16. */
    public RouterSection(
        boolean enabled,
        @Nullable List<String> rideTypes,
        @Nullable Double crowMMax,
        @Nullable Double snapM) {
      this(enabled, rideTypes, crowMMax, snapM, false, false);
    }

    /** Without {@code avoid_main_roads}: the shape this record had before api 1.16's second option. */
    public RouterSection(
        boolean enabled,
        @Nullable List<String> rideTypes,
        @Nullable Double crowMMax,
        @Nullable Double snapM,
        boolean useRoads) {
      this(enabled, rideTypes, crowMMax, snapM, useRoads, false);
    }
  }

  /** The service's bounds as of api 1.6, used while it has not answered. */
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
  public record Data(
      @JsonProperty("surface_detail") boolean surfaceDetail, @Nullable EdgesFeature edges) {

    /** Without edges: the shape this record had before api 1.7. */
    public Data(boolean surfaceDetail) {
      this(surfaceDetail, null);
    }
  }

  /**
   * {@code data.edges} (api 1.7): how {@code edges[]} is built. Only its presence is read, the grid
   * and the precision are what the contract publishes for a client that decodes them.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record EdgesFeature(
      @Nullable @JsonProperty("node_id_prefix") String nodeIdPrefix,
      @Nullable @JsonProperty("node_grid_zoom") Integer nodeGridZoom,
      @Nullable @JsonProperty("node_grid_extent") Integer nodeGridExtent,
      @Nullable @JsonProperty("polyline_precision") Integer polylinePrecision) {}

  /**
   * {@code generator} (api 1.9): whether the route generator answers, which graph it serves and the
   * bounds of a deposit and of a request (lot 3b plan §1).
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record GeneratorSection(
      boolean enabled,
      @Nullable String reason,
      @Nullable Graph graph,
      @Nullable GeneratorLimits limits,
      @Nullable @JsonProperty("overlay_ttl_days") Long overlayTtlDays,
      boolean ascent,
      @Nullable OffroadInfo offroad) {

    /** Without {@code offroad}: the shape this record had before api 1.14. */
    public GeneratorSection(
        boolean enabled,
        @Nullable String reason,
        @Nullable Graph graph,
        @Nullable GeneratorLimits limits,
        @Nullable Long overlayTtlDays,
        boolean ascent) {
      this(enabled, reason, graph, limits, overlayTtlDays, ascent, null);
    }
  }

  /** {@code generator.offroad} (api 1.14): the steering of the share ridden off pavement. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record OffroadInfo(
      @Nullable @JsonProperty("ride_types") List<String> rideTypes,
      @JsonProperty("target_min") double targetMin,
      @JsonProperty("target_max") double targetMax,
      double tolerance) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Graph(@Nullable String id) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record GeneratorLimits(
      @JsonProperty("distance_m_max") double distanceMMax, @Nullable DepositLimits deposit) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record DepositLimits(
      @JsonProperty("max_document_bytes") long maxDocumentBytes,
      @JsonProperty("max_tracks") long maxTracks) {}

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

  /** {@code options.edges} is understood (api 1.7, announced by {@code data.edges}). */
  public boolean supportsEdges() {
    return apiAtLeast(1, 7) && data != null && data.edges() != null;
  }

  /** The generator is served: api 1.9 or later, and its section says it is enabled. */
  public boolean generatorEnabled() {
    return apiAtLeast(1, 9) && generator != null && generator.enabled();
  }

  /** The planner's engine is served: api 1.15 or later, and its section says it is enabled. */
  public boolean routerEnabled() {
    return apiAtLeast(1, 15) && router != null && router.enabled();
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
