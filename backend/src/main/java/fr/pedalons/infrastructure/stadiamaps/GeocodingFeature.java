package fr.pedalons.infrastructure.stadiamaps;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * One feature of the geocoder's {@code FeatureCollection}, reduced to what the autocomplete shows
 * and returns.
 *
 * <p>{@code @JsonIgnoreProperties(ignoreUnknown = true)} is not laziness: {@code properties} carries
 * fields (precision, bbox, address components, context…) we have no use for, and the set grows with
 * the releases behind the API. Coordinates are a GeoJSON position, {@code [lon, lat]} — in that
 * order, which {@link #lat()} and {@link #lon()} hide.
 *
 * <p>In a v2 autocomplete answer {@code geometry} is usually {@code null}: the position comes from
 * {@code place_details} once a result is picked. It is read whenever present all the same.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record GeocodingFeature(@Nullable Geometry geometry, @Nullable Properties properties) {

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Geometry(@Nullable List<Double> coordinates) {}

  /**
   * @param gid the global id, e.g. {@code whosonfirst:locality:101750851} — unique across sources,
   *     and what {@code place_details} takes
   * @param name the place's own name, e.g. {@code Annecy}
   * @param coarseLocation where it is, e.g. {@code France} or {@code Annecy, France} — v2 has no
   *     ready-made label, so the display name is {@code name, coarse_location}
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Properties(
      @Nullable String gid,
      @Nullable String name,
      @JsonProperty("coarse_location") @Nullable String coarseLocation) {}

  /** Latitude, or {@code null} when the feature carries no usable point. */
  public @Nullable Double lat() {
    return coordinate(1);
  }

  /** Longitude, or {@code null} when the feature carries no usable point. */
  public @Nullable Double lon() {
    return coordinate(0);
  }

  public @Nullable String gid() {
    return properties == null ? null : properties.gid();
  }

  /**
   * {@code name, coarse_location} — {@code "Annecy, France"} — or the name alone when there is no
   * coarse location; {@code null} without a name.
   */
  public @Nullable String displayName() {
    if (properties == null || properties.name() == null || properties.name().isBlank()) {
      return null;
    }
    String name = properties.name().strip();
    String coarse = properties.coarseLocation();
    return coarse == null || coarse.isBlank() ? name : name + ", " + coarse.strip();
  }

  private @Nullable Double coordinate(int index) {
    if (geometry == null || geometry.coordinates() == null || geometry.coordinates().size() < 2) {
      return null;
    }
    Double value = geometry.coordinates().get(index);
    return value == null || value.isNaN() ? null : value;
  }
}
