package fr.pedalons.service.weather;

import fr.pedalons.domain.ride.Ride;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.repository.gpx.PreviewWeatherRow;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.weather.RideWeatherCalculator.CellSeries;
import fr.pedalons.service.weather.RideWeatherCalculator.LegInput;
import fr.pedalons.service.weather.RideWeatherPlans.RidePlan;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * A ride's weather for its detail page, read from the cache only.
 *
 * <p><b>Never calls the provider and never writes</b>, so the web SSR can prefetch it like any
 * read: a cell nobody fetched yet reads as {@code UNAVAILABLE}, and the planner will have asked for
 * it within five minutes of the ride being published.
 *
 * <p>Its query count does not depend on the number of groups: the track ids of all the ride's
 * routes (one query), the cells (one), their hours with sunrise and sunset (one) — plus, on a cold
 * route-sample cache only, the tracks of each route not cached yet.
 *
 * <p>Takes a {@link Ride} the caller has already been allowed to read: the access check is the
 * caller's ({@code @CheckAccess(RIDE, READ)} on the endpoint). Nothing it returns carries a
 * coordinate.
 */
@ApplicationScoped
public class RideWeatherService {

  @Inject RideWeatherPlans plans;
  @Inject WeatherSeriesLoader seriesLoader;

  public RideWeather forRide(Ride ride) {
    return forRide(ride, Instant.now());
  }

  RideWeather forRide(Ride ride, Instant now) {
    if (isOutOfRange(ride, now)) {
      return RideWeather.of(WeatherStatus.OUT_OF_RANGE);
    }
    return forPlan(plans.plan(ride), now);
  }

  /**
   * The weather of a dated GPX preview (docs/LEDGER_*.md API-153): finished or undated is {@code
   * OUT_OF_RANGE}, otherwise as a ride without group.
   */
  public RideWeather forPreview(PreviewWeatherRow preview) {
    return forPreview(preview, Instant.now());
  }

  RideWeather forPreview(PreviewWeatherRow preview, Instant now) {
    Instant departure = preview.departureAt();
    if (departure == null || departure.isBefore(now)) {
      return RideWeather.of(WeatherStatus.OUT_OF_RANGE);
    }
    return forPlan(plans.plan(preview), now);
  }

  /** What follows the range check: no location, horizon, cells, calculation. */
  RideWeather forPlan(RidePlan plan, Instant now) {
    if (plan.departure() == null) {
      return RideWeather.of(WeatherStatus.NO_LOCATION);
    }
    if (RideWeatherCalculator.isBeyondHorizon(plan.departureTime(), now)) {
      return new RideWeather(
          WeatherStatus.NOT_YET_AVAILABLE,
          RideWeatherCalculator.availableFrom(plan.departureTime()),
          null,
          DepartureWeather.of(WeatherStatus.NOT_YET_AVAILABLE),
          List.of());
    }

    // Every cell the plan reads, then one query for those cells and one for their hours.
    Set<CellKey> keys = new LinkedHashSet<>();
    CellKey departureCell = plan.departure().cell();
    keys.add(departureCell);
    for (LegInput leg : plan.legs()) {
      if (leg.samples() != null) {
        for (RouteSamples.Sample sample : leg.samples().samples()) {
          keys.add(sample.cell());
        }
      }
    }
    Map<CellKey, CellSeries> cache = seriesLoader.load(keys, plan.earliest(), plan.lastArrival());

    CellSeries departureSeries = cache.getOrDefault(departureCell, CellSeries.EMPTY);
    DepartureWeather departure =
        RideWeatherCalculator.departure(departureSeries, plan.departureTime(), now);
    List<WeatherLeg> legs = new ArrayList<>(plan.legs().size());
    for (LegInput leg : plan.legs()) {
      legs.add(
          RideWeatherCalculator.leg(leg, key -> cache.getOrDefault(key, CellSeries.EMPTY), now)
              .withDeparture(legDeparture(departureSeries, leg, now)));
    }
    return RideWeatherCalculator.ride(departure, legs);
  }

  /**
   * A group's departure block: the meeting point — the cell of the ride's own block, already read
   * — at the group's start, sunrise and sunset included (docs/LEDGER_*.md API-169). The cell is in
   * the planner's demand with the ride's departure, and the series read spans every leg's start
   * ({@link RidePlan#earliest}), so it costs nothing more. {@code NOT_YET_AVAILABLE} for a group
   * leaving beyond the horizon, as its leg.
   */
  static DepartureWeather legDeparture(CellSeries departureSeries, LegInput leg, Instant now) {
    if (RideWeatherCalculator.isBeyondHorizon(leg.start(), now)) {
      return DepartureWeather.of(WeatherStatus.NOT_YET_AVAILABLE);
    }
    return RideWeatherCalculator.departure(departureSeries, leg.start(), now);
  }

  /**
   * The local day of its end — its stored end ({@link PublicationEndCalculator#effectiveEnd}, the
   * last group back), read in the ride's zone — is over, or the ride is cancelled: no weather
   * block. A draft has none either. A ride that has left keeps its weather while its groups are
   * out (docs/LEDGER_*.md API-170), and to the end of that day rather than to the estimated
   * arrival ({@link RideWeatherCalculator#shownUntil}, docs/LEDGER_*.md API-183), unlike {@code
   * RideDto.finished}, which only says it has left.
   */
  static boolean isOutOfRange(Ride ride, Instant now) {
    return ride.getStatus() != Status.PUBLISHED
        || !now.isBefore(
            RideWeatherCalculator.shownUntil(
                PublicationEndCalculator.effectiveEnd(ride), ride.zone()));
  }
}
