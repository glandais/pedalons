package fr.pedalons.infrastructure.stadiamaps;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The GeoJSON {@code FeatureCollection} the Stadia Maps geocoder answers with, reduced to its
 * features. {@code bbox}, {@code geocoding} (the query echo) and whatever Pelias adds next are
 * ignored.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record GeocodingResponse(@Nullable List<GeocodingFeature> features) {

  /** Never null: a missing {@code features} array reads as no result. */
  public List<GeocodingFeature> featuresOrEmpty() {
    return features == null ? List.of() : features;
  }
}
