package fr.pedalons.service.route.generator;

import org.jspecify.annotations.Nullable;

/**
 * What a person asks the generator for (plan §2).
 *
 * <p>No 10 to 300 km check here: lot 3 validates the public range, tests use shorter routes.
 *
 * @param end null for a loop (the route ends where it starts)
 * @param bearing wished direction, only used when the end is closer than half the distance
 * @param familiarity 0 prefers roads the team rides rarely, 1 the ones it rides often, 0.5 is
 *     indifferent
 * @param seed makes "other proposals" reproducible: the same seed gives the same routes
 */
public record GeneratorRequest(
    LatLon start,
    @Nullable LatLon end,
    @Nullable Bearing8 bearing,
    double distanceM,
    double familiarity,
    RideType type,
    long seed) {

  public GeneratorRequest {
    if (!(distanceM > 0)) {
      throw new IllegalArgumentException("distanceM must be positive: " + distanceM);
    }
    if (!(familiarity >= 0 && familiarity <= 1)) {
      throw new IllegalArgumentException("familiarity must be in [0, 1]: " + familiarity);
    }
  }
}
