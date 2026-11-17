package fr.pedalons.service.weather;

import fr.pedalons.domain.trip.Trip;
import fr.pedalons.dto.trips.response.TripListSummary;
import fr.pedalons.enums.Status;
import fr.pedalons.repository.weather.WeatherHourRow;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository.TripLegHour;
import fr.pedalons.service.publication.PublicationEndCalculator;
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
import java.util.Objects;
import java.util.function.Function;

/**
 * The weather line of a page of trip cards, in bulk — what {@link RideWeatherLookup} is for rides
 * (docs/LEDGER_*.md API-82). The line is that of the trip's <b>current leg</b>: the first live stage
 * whose day is not over — the local day of its end, in its zone, the rule of the trip's page
 * (docs/LEDGER_*.md API-170, API-173) — else the trip itself when it has no stage. A stage under
 * way, the last one included, keeps the line until then.
 *
 * <p><b>It costs a page, not a row</b>: no query at all when no trip of the page can have a leg
 * left (draft, cancelled, over for a day — told by the trip's stored end and the page's {@link
 * TripListSummary}, already loaded), <b>one</b> otherwise, whatever the page size. The stages are never loaded: the next leg,
 * its departure cell and its window are worked out in SQL ({@code
 * WeatherHourlyRepository#findTripNextLegHours}). Reads the cache only, like the detail.
 *
 * <p>The departure cell is the one the detail reads for the stage's first checkpoint (first track
 * point, with its elevation band), so the card and the stage's own line agree on the start. The
 * extremes are over that one cell, as a ride's card: the rain alert carries no {@code distance}.
 *
 * <p>Takes trips the caller may already read; the result is about those trips only.
 */
@ApplicationScoped
public class TripWeatherLookup {

  @Inject WeatherHourlyRepository hourlyRepository;

  /**
   * @param summaries the list summary of each trip of the page, for its stage count and the date
   *     of its last stage
   */
  public RideWeatherSummaries forTrips(
      Collection<Trip> trips, Function<Long, TripListSummary> summaries) {
    return forTrips(trips, summaries, Instant.now());
  }

  /**
   * A bound past which no leg of the trip is shown any more — a pre-filter only, so that a page of
   * finished trips costs no query: the query itself drops each stage at the end of the local day of
   * its own end, in its own zone, as the trip's page does ({@code TripWeatherService#isGone},
   * docs/LEDGER_*.md API-170, API-173). The end is the trip's stored one, else (a row an older backend
   * left null) its last stage's departure plus the default duration; the local day of an instant,
   * whatever its zone, is over at most {@link #LATEST_DAY_END} after it.
   */
  static Instant latestShownUntil(Trip trip, TripListSummary summary) {
    Instant end = PublicationEndCalculator.effectiveEnd(trip);
    Instant lastDeparture = summary.stageCount() > 0 ? summary.endDate() : null;
    if (lastDeparture != null) {
      Instant lastEnd = lastDeparture.plus(PublicationEndCalculator.DEFAULT_DURATION);
      end = lastEnd.isAfter(end) ? lastEnd : end;
    }
    return end.plus(LATEST_DAY_END);
  }

  /** A day of 25 hours (a clock put back) ends at most this long after any of its instants. */
  static final Duration LATEST_DAY_END = Duration.ofHours(25);

  RideWeatherSummaries forTrips(
      Collection<Trip> trips, Function<Long, TripListSummary> summaries, Instant now) {
    List<Long> candidates = new ArrayList<>();
    for (Trip trip : trips) {
      if (trip.getStatus() != Status.PUBLISHED) {
        continue;
      }
      if (!now.isBefore(latestShownUntil(trip, summaries.apply(trip.getId())))) {
        continue;
      }
      candidates.add(trip.getId());
    }
    if (candidates.isEmpty()) {
      return RideWeatherSummaries.NONE;
    }
    Map<Long, List<TripLegHour>> byTrip = new LinkedHashMap<>();
    for (TripLegHour hour :
        hourlyRepository.findTripNextLegHours(
            candidates,
            now,
            now.plus(RideWeatherCalculator.HORIZON),
            CellKey.SQL_LAT_IDX,
            CellKey.SQL_LON_IDX,
            CellKey.ELEVATION_BAND,
            RideWeatherCalculator.DEFAULT_SPEED_KMH,
            RideWeatherLookup.SLACK)) {
      byTrip.computeIfAbsent(hour.tripId(), k -> new ArrayList<>()).add(hour);
    }
    Map<Long, RideWeatherSummary> result = new HashMap<>();
    Map<Long, String> zones = new HashMap<>();
    for (Map.Entry<Long, List<TripLegHour>> entry : byTrip.entrySet()) {
      TripLegHour first = entry.getValue().getFirst();
      RideWeatherSummary summary;
      if (RideWeatherCalculator.isBeyondHorizon(first.departure(), now)) {
        summary =
            RideWeatherSummary.notYetAvailable(
                RideWeatherCalculator.availableFrom(first.departure()));
      } else {
        List<WeatherHourRow> hours =
            entry.getValue().stream().map(TripLegHour::hour).filter(Objects::nonNull).toList();
        summary =
            hours.isEmpty()
                ? null
                : RideWeatherCalculator.summary(
                    first.departure(), first.arrival(), first.fetchedAt(), hours, now);
      }
      if (summary != null) {
        result.put(entry.getKey(), summary);
        zones.put(entry.getKey(), first.zone());
      }
    }
    return result.isEmpty() ? RideWeatherSummaries.NONE : new RideWeatherSummaries(result, zones);
  }
}
