package fr.pedalons.infrastructure.stadiamaps;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * One feature of the geocoder's {@code FeatureCollection}, reduced to what the autocomplete shows
 * and returns.
 *
 * <p>{@code @JsonIgnoreProperties(ignoreUnknown = true)} is not laziness: {@code properties} carries
 * some forty fields (the whole administrative hierarchy, concordances, confidence…) we have no use
 * for, and the set grows with the Pelias releases behind the API. Coordinates are a GeoJSON
 * position, {@code [lon, lat]} — in that order, which {@link #lat()} and {@link #lon()} hide.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record GeocodingFeature(@Nullable Geometry geometry, @Nullable Properties properties) {

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Geometry(@Nullable List<Double> coordinates) {}

  /**
   * @param gid the Pelias global id, e.g. {@code whosonfirst:locality:101749323} — unique across
   *     sources, which the numeric {@code id} alone is not
   * @param label the full human-readable name, e.g. {@code Chambéry, France}
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record Properties(@Nullable String gid, @Nullable String label, @Nullable String name) {}

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

  public @Nullable String label() {
    return properties == null ? null : properties.label();
  }

  private @Nullable Double coordinate(int index) {
    if (geometry == null || geometry.coordinates() == null || geometry.coordinates().size() < 2) {
      return null;
    }
    Double value = geometry.coordinates().get(index);
    return value == null || value.isNaN() ? null : value;
  }
}
