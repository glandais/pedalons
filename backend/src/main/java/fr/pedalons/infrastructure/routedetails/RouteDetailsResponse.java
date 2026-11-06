package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.JsonNode;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * The part of a {@code POST /v1/route-details} answer Pédalons reads (contract api 1.6). Unknown
 * properties are ignored: the contract adds fields within a major version (its §6), and a client
 * that refused them would break at the next minor release.
 *
 * <p>Every enumerated value — point origin, elevation method, structure, surface class and detail,
 * way kind, terrain origin, warning code — stays a {@code String}: the contract's lists are open, a
 * client must tolerate a value it does not know (and fall back, for {@code surface.detail}, on
 * {@code class}). Constants for the values the backend tests against are below.
 *
 * <p>{@code points}, {@code segments} and {@code summary} are null when their section was not
 * asked for.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record RouteDetailsResponse(
    @Nullable Meta meta,
    @Nullable String status,
    @Nullable List<OutputPoint> points,
    @Nullable List<Segment> segments,
    @Nullable Summary summary,
    @Nullable Quality quality) {

  /** {@code status}: a source gave nothing on part of the route (down, or out of its coverage). */
  public static final String STATUS_PARTIAL = "partial";

  public static final String STATUS_COMPLETE = "complete";

  /** {@code points[].origin}: a breakpoint the service added between two input points. */
  public static final String ORIGIN_INSERTED = "inserted";

  public static final String ORIGIN_INPUT = "input";

  public boolean isPartial() {
    return STATUS_PARTIAL.equals(status);
  }

  /**
   * {@code profile} is the effective one (api 1.5), part of the identity of the answer like the
   * versions; {@code data_versions} is kept as a tree, only ever logged or stored as is.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Meta(
      @Nullable @JsonProperty("api_version") String apiVersion,
      @Nullable @JsonProperty("rules_version") String rulesVersion,
      @Nullable String profile,
      @Nullable @JsonProperty("data_versions") JsonNode dataVersions) {}

  /**
   * A point of the profile. {@code index} is the input point's, or the last input point's before an
   * inserted one; {@code lat} / {@code lon} only on inserted points. {@code ele} is corrected on the
   * structures but not smoothed, {@code eleSmoothed} only with {@code elevation.smoothing_m}; both
   * null on an elevation gap. The cumulative gain and loss (api 1.5) are those of {@code summary}:
   * the gain of a sub-range is the difference at its ends.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record OutputPoint(
      @JsonProperty("d_m") double dM,
      int index,
      @Nullable String origin,
      @Nullable List<String> reasons,
      @Nullable Double lat,
      @Nullable Double lon,
      @Nullable Double ele,
      @Nullable @JsonProperty("ele_smoothed") Double eleSmoothed,
      @Nullable @JsonProperty("ele_method") String eleMethod,
      @JsonProperty("gain_cum_m") double gainCumM,
      @JsonProperty("loss_cum_m") double lossCumM) {

    public boolean isInserted() {
      return ORIGIN_INSERTED.equals(origin);
    }
  }

  /**
   * A homogeneous stretch; the segments cover the whole route. {@code matched} false: off the
   * bicycle network (or on a way closed to bicycles, api 1.1). {@code structureSource} only on a
   * bridge or a tunnel.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Segment(
      @JsonProperty("from_m") double fromM,
      @JsonProperty("to_m") double toM,
      @JsonProperty("from_index") int fromIndex,
      @JsonProperty("to_index") int toIndex,
      @Nullable String structure,
      @Nullable @JsonProperty("structure_source") String structureSource,
      @Nullable Surface surface,
      @Nullable @JsonProperty("way_kind") String wayKind,
      boolean matched) {}

  /**
   * {@code class}: {@code paved}, {@code unpaved} or {@code unknown}. {@code detail} (api 1.6) only
   * on a recognised raw tag ({@code source = tagged}), absent otherwise — about half of the French
   * roads; each detail implies a single class.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Surface(
      @Nullable @JsonProperty("class") String surfaceClass,
      @Nullable String detail,
      @Nullable String source) {}

  /** The route's aggregates; {@code terrainM} is the length per terrain origin. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Summary(
      @JsonProperty("length_m") double lengthM,
      @JsonProperty("gain_m") double gainM,
      @JsonProperty("loss_m") double lossM,
      @Nullable @JsonProperty("ele_min_m") Double eleMinM,
      @Nullable @JsonProperty("ele_max_m") Double eleMaxM,
      @Nullable List<Structure> structures,
      @Nullable @JsonProperty("terrain_m") Map<String, Double> terrainM) {}

  /** A bridge or a tunnel met on the route, and how its elevation was corrected. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Structure(
      @Nullable String kind,
      @JsonProperty("from_m") double fromM,
      @JsonProperty("to_m") double toM,
      @JsonProperty("length_m") double lengthM,
      @Nullable @JsonProperty("structure_source") String structureSource,
      @Nullable String method) {}

  /** {@code structureCorrection} is kept as a tree: logged, never interpreted. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Quality(
      @Nullable List<TerrainRange> terrain,
      @Nullable List<Warning> warnings,
      @Nullable @JsonProperty("structure_correction") JsonNode structureCorrection) {}

  /**
   * The terrain source of a range. {@code fallbackAfterError}: the primary source failed there (as
   * opposed to a range outside its coverage) — an answer worth asking again later.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record TerrainRange(
      @JsonProperty("from_m") double fromM,
      @JsonProperty("to_m") double toM,
      @Nullable String origin,
      boolean measured,
      @JsonProperty("fallback_after_error") boolean fallbackAfterError) {}

  /** {@code message} is a diagnostic only: a client translates the code. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Warning(
      @Nullable String code,
      @Nullable String message,
      @Nullable @JsonProperty("from_m") Double fromM,
      @Nullable @JsonProperty("to_m") Double toM) {}
}
