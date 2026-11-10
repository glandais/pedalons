package fr.pedalons.service.weather;

import fr.pedalons.enums.WeatherStatus;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * A trip's weather, one leg per live stage. Built by {@link TripWeatherService#forTrip} from the
 * cache alone.
 *
 * @param availableFrom for {@code NOT_YET_AVAILABLE}: seven days before the first stage with a
 *     route leaves
 * @param fetchedAt the oldest fetch among the cells read
 * @param stages one per live stage, in stage order — a stage already over included, {@code
 *     OUT_OF_RANGE}; a single one without {@code stageId} for a trip without stages; empty when the
 *     trip is not published
 */
public record TripWeather(
    WeatherStatus status,
    @Nullable Instant availableFrom,
    @Nullable Instant fetchedAt,
    List<StageLeg> stages) {

  /**
   * A stage and its leg.
   *
   * @param departure the weather at the stage's first forecast point when it leaves: {@code
   *     OUT_OF_RANGE} once over, {@code NO_LOCATION} without a route, {@code NOT_YET_AVAILABLE}
   *     beyond the horizon
   */
  public record StageLeg(@Nullable Long stageId, WeatherLeg leg, DepartureWeather departure) {}

  public static TripWeather of(WeatherStatus status) {
    return new TripWeather(status, null, null, List.of());
  }
}
