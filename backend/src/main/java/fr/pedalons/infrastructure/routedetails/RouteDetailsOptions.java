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
    @Nullable @JsonProperty("accept_partial") Boolean acceptPartial) {

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
        acceptPartial);
  }

  /** The same options restricted to {@code sections}. */
  public RouteDetailsOptions withSections(List<RouteDetailsSection> sections) {
    return new RouteDetailsOptions(
        profile, List.copyOf(sections), sampling, elevation, acceptPartial);
  }

  /** The profile the service runs: {@code full} when none is sent (its default). */
  public RouteDetailsProfile effectiveProfile() {
    return profile == null ? RouteDetailsProfile.FULL : profile;
  }
}
