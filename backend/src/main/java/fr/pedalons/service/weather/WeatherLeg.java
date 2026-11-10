package fr.pedalons.service.weather;

import fr.pedalons.enums.WeatherStatus;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The weather along one ridden route: a group of a ride, or a stage of a trip.
 *
 * @param groupId null for a ride without groups (its own route)
 * @param status {@code NO_LOCATION} when the leg has no route to sample
 * @param availableFrom for {@code NOT_YET_AVAILABLE}: seven days before the leg leaves
 * @param averageSpeed km/h used for the passages
 * @param speedIsDefault {@code averageSpeed} is the {@value RideWeatherCalculator#DEFAULT_SPEED_KMH}
 *     km/h default, to be said on screen
 * @param distance metres of the route
 * @param fetchedAt the oldest fetch among the cells read
 * @param departure for a ride's leg: the weather at the ride's meeting point when this leg leaves,
 *     sunrise and sunset included (docs/LEDGER_*.md API-169); null for a trip's stage, whose
 *     departure {@link TripWeather.StageLeg#departure} carries, and until {@link #withDeparture}
 */
public record WeatherLeg(
    @Nullable Long groupId,
    WeatherStatus status,
    @Nullable Instant availableFrom,
    Instant startTime,
    double averageSpeed,
    boolean speedIsDefault,
    double distance,
    Instant arrivalTime,
    @Nullable Instant fetchedAt,
    List<WeatherCheckpoint> checkpoints,
    List<WindSegment> segments,
    WindExposure windExposure,
    @Nullable Wind prevailingWind,
    @Nullable RainAlert rainAlert,
    @Nullable DepartureWeather departure) {

  /** This leg with its departure block. */
  public WeatherLeg withDeparture(DepartureWeather departure) {
    return new WeatherLeg(
        groupId,
        status,
        availableFrom,
        startTime,
        averageSpeed,
        speedIsDefault,
        distance,
        arrivalTime,
        fetchedAt,
        checkpoints,
        segments,
        windExposure,
        prevailingWind,
        rainAlert,
        departure);
  }
}
