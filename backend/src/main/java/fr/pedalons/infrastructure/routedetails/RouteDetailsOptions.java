package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The {@code options} of a request, the ones Pédalons uses. A null option is left out of the JSON
 * ({@code NON_NULL}) and the service applies its published default; an unknown key would be a 400
 * before any work, so nothing here is sent "just in case".
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record RouteDetailsOptions(
    @Nullable RouteDetailsProfile profile,
    @Nullable List<RouteDetailsSection> sections,
    @Nullable Sampling sampling,
    @Nullable Elevation elevation,
    @Nullable @JsonProperty("accept_partial") Boolean acceptPartial,
    @Nullable Boolean edges) {

  /** Without {@code edges}: the shape this record had before api 1.7. */
  public RouteDetailsOptions(
      @Nullable RouteDetailsProfile profile,
      @Nullable List<RouteDetailsSection> sections,
      @Nullable Sampling sampling,
      @Nullable Elevation elevation,
      @Nullable Boolean acceptPartial) {
    this(profile, sections, sampling, elevation, acceptPartial, null);
  }

  /** Every input point kept, plus the summits, low points, grade and structure breakpoints. */
  public static final String INPUT_WITH_BREAKPOINTS = "input_with_breakpoints";

  /** One value per input point, no insertion. */
  public static final String INPUT = "input";

  /** The smoothing of gpx2web, which the profile chart and the climbs were tuned on (plan §4.2). */
  public static final double SMOOTHING_M = 150;

  @JsonInclude(JsonInclude.Include.NON_NULL)
  public record Sampling(@Nullable String mode) {}

  @JsonInclude(JsonInclude.Include.NON_NULL)
  public record Elevation(@Nullable @JsonProperty("smoothing_m") Double smoothingM) {}

  /**
   * What Pédalons asks: {@code profile}, all three sections, the input points plus breakpoints, a
   * 150 m smoothed elevation.
   *
   * @param acceptPartial a 200 {@code partial} rather than a 503 when one source is down
   */
  public static RouteDetailsOptions of(RouteDetailsProfile profile, boolean acceptPartial) {
    return new RouteDetailsOptions(
        profile,
        List.of(
            RouteDetailsSection.ELEVATION,
            RouteDetailsSection.TYPOLOGY,
            RouteDetailsSection.SUMMARY),
        new Sampling(INPUT_WITH_BREAKPOINTS),
        new Elevation(SMOOTHING_M),
        acceptPartial,
        null);
  }

  /**
   * The options of an edges-only call: the typology (its segments say what stayed unmatched) and
   * the summary, in {@code full}, with no {@code accept_partial}. The edges come whatever the
   * sections are.
   */
  public static RouteDetailsOptions edgesOnly() {
    return new RouteDetailsOptions(
        RouteDetailsProfile.FULL,
        List.of(RouteDetailsSection.TYPOLOGY, RouteDetailsSection.SUMMARY),
        new Sampling(INPUT_WITH_BREAKPOINTS),
        null,
        null,
        true);
  }

  /** The same options restricted to {@code sections}. */
  public RouteDetailsOptions withSections(List<RouteDetailsSection> sections) {
    return new RouteDetailsOptions(
        profile, List.copyOf(sections), sampling, elevation, acceptPartial, edges);
  }

  /**
   * The same options asking for {@code edges[]} (api 1.7) or not: false leaves the key out, as an
   * unknown key would be a 400 on an older service.
   */
  public RouteDetailsOptions withEdges(boolean wanted) {
    return new RouteDetailsOptions(
        profile, sections, sampling, elevation, acceptPartial, wanted ? Boolean.TRUE : null);
  }

  /** Whether {@code edges[]} is asked for. */
  public boolean wantsEdges() {
    return Boolean.TRUE.equals(edges);
  }

  /** The profile the service runs: {@code full} when none is sent (its default). */
  public RouteDetailsProfile effectiveProfile() {
    return profile == null ? RouteDetailsProfile.FULL : profile;
  }
}
