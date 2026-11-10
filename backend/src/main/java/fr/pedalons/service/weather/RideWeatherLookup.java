package fr.pedalons.service.weather;

import fr.pedalons.domain.ride.Ride;
import fr.pedalons.repository.weather.WeatherHourRow;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository.RideWindowHour;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The weather line of a page of ride cards, in bulk — as {@code CommentCountLookup} is for comment
 * counts.
 *
 * <p><b>It costs a page, not a row</b>: no query at all when no ride of the page is within the
 * seven-day window (over — its stored end passed, docs/LEDGER_*.md API-163 —, cancelled, too far
 * ahead), <b>one</b> otherwise, whatever the page
 * size. The ride's groups are never loaded: the window to the last arrival is worked out in SQL
 * ({@code WeatherHourlyRepository#findRideWindowHours}). Reads the cache only, like the detail.
 *
 * <p>A ride further than seven days ahead gets {@code NOT_YET_AVAILABLE} without a query when its
 * meeting point or its route locates it; one located only through a group's route gets nothing until
 * it comes within range — telling would cost its groups.
 *
 * <p>Takes rides the caller may already read; the result is about those rides only.
 */
@ApplicationScoped
public class RideWeatherLookup {

  /** How far outside a ride's window an hour is still read, so the nearest one is in hand. */
  static final Duration SLACK = Duration.ofMinutes(90);

  @Inject WeatherHourlyRepository hourlyRepository;

  public RideWeatherSummaries forRides(Collection<Ride> rides) {
    return forRides(rides, Instant.now());
  }

  RideWeatherSummaries forRides(Collection<Ride> rides, Instant now) {
    Map<Long, RideWeatherSummary> summaries = new HashMap<>();
    List<Long> inRange = new ArrayList<>();
    for (Ride ride : rides) {
      if (RideWeatherService.isOutOfRange(ride, now)) {
        continue;
      }
      if (RideWeatherCalculator.isBeyondHorizon(ride.getDateTime(), now)) {
        if (RideWeatherPlans.departureWithoutGroups(ride) != null) {
          summaries.put(
              ride.getId(),
              RideWeatherSummary.notYetAvailable(
                  RideWeatherCalculator.availableFrom(ride.getDateTime())));
        }
        continue;
      }
      inRange.add(ride.getId());
    }
    if (!inRange.isEmpty()) {
      Map<Long, List<RideWindowHour>> byRide = new LinkedHashMap<>();
      for (RideWindowHour hour :
          hourlyRepository.findRideWindowHours(
              inRange,
              CellKey.SQL_LAT_IDX,
              CellKey.SQL_LON_IDX,
              RideWeatherCalculator.DEFAULT_SPEED_KMH,
              SLACK)) {
        byRide.computeIfAbsent(hour.rideId(), k -> new ArrayList<>()).add(hour);
      }
      for (Map.Entry<Long, List<RideWindowHour>> entry : byRide.entrySet()) {
        RideWindowHour first = entry.getValue().getFirst();
        List<WeatherHourRow> hours = entry.getValue().stream().map(RideWindowHour::hour).toList();
        RideWeatherSummary summary =
            RideWeatherCalculator.summary(
                first.departure(), first.lastArrival(), first.fetchedAt(), hours, now);
        if (summary != null) {
          summaries.put(entry.getKey(), summary);
        }
      }
    }
    return summaries.isEmpty() ? RideWeatherSummaries.NONE : new RideWeatherSummaries(summaries);
  }
}
