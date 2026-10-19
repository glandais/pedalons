package fr.pedalons.infrastructure.valhalla;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import org.jspecify.annotations.Nullable;

@JsonIgnoreProperties(ignoreUnknown = true)
public record ValhallaResponse(@Nullable ValhallaTrip trip) {

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record ValhallaTrip(List<ValhallaLeg> legs) {}

  /** A leg: its shape and the maneuvers that cut it (indices are into this leg's shape). */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record ValhallaLeg(@Nullable String shape, @Nullable List<ValhallaManeuver> maneuvers) {}

  /**
   * A maneuver, reduced to what C1a reads. {@code rough} is Valhalla's "compacted or worse"; absent
   * means paved.
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  public record ValhallaManeuver(
      @JsonProperty("begin_shape_index") int beginShapeIndex,
      @JsonProperty("end_shape_index") int endShapeIndex,
      @Nullable Boolean rough) {}
}
