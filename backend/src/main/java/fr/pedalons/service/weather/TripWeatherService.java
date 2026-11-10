package fr.pedalons.service.weather;

import fr.pedalons.domain.trip.Trip;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.service.weather.RideWeatherCalculator.CellSeries;
import fr.pedalons.service.weather.RideWeatherCalculator.LegInput;
import fr.pedalons.service.weather.TripWeatherPlans.StagePlan;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * A trip's weather, stage by stage, read from the cache only — the trip counterpart of {@link
 * RideWeatherService}, under the same rules: <b>never calls the provider and never writes</b>, takes
 * a {@link Trip} the caller has already been allowed to read, returns no coordinate.
 *
 * <p>Each stage has its own state: a stage over (its stored end passed, docs/LEDGER_*.md API-163)
 * is {@code OUT_OF_RANGE}, one beyond the
 * seven-day horizon {@code NOT_YET_AVAILABLE}, one without a route {@code NO_LOCATION}. Its query
 * count does not depend on the number of stages: the track ids (one), the cells (one), their hours
 * over the window of the stages within range (one) — plus, on a cold route-sample cache only, the
 * tracks of each route not cached yet.
 */
@ApplicationScoped
public class TripWeatherService {

  @Inject TripWeatherPlans plans;
  @Inject WeatherSeriesLoader seriesLoader;

  public TripWeather forTrip(Trip trip) {
    return forTrip(trip, Instant.now());
  }

  TripWeather forTrip(Trip trip, Instant now) {
    // A draft or a cancelled trip has no weather block; a finished one falls out below, every
    // stage being over.
    if (trip.getStatus() != Status.PUBLISHED) {
      return TripWeather.of(WeatherStatus.OUT_OF_RANGE);
    }
    List<StagePlan> stagePlans = plans.plan(trip);

    // The cells of the stages within range, and the window that covers them all.
    Set<CellKey> keys = new LinkedHashSet<>();
    Instant from = null;
    Instant to = null;
    for (StagePlan plan : stagePlans) {
      LegInput leg = plan.leg();
      if (isGone(plan, now)
          || leg.samples() == null
          || RideWeatherCalculator.isBeyondHorizon(leg.start(), now)) {
        continue;
      }
      for (RouteSamples.Sample sample : leg.samples().samples()) {
        keys.add(sample.cell());
      }
      from = from == null || leg.start().isBefore(from) ? leg.start() : from;
      to = to == null || leg.arrival().isAfter(to) ? leg.arrival() : to;
    }
    Map<CellKey, CellSeries> cache = from == null ? Map.of() : seriesLoader.load(keys, from, to);

    List<TripWeather.StageLeg> stages = new ArrayList<>(stagePlans.size());
    List<WeatherLeg> upcoming = new ArrayList<>(stagePlans.size());
    for (StagePlan plan : stagePlans) {
      LegInput leg = plan.leg();
      WeatherLeg weather;
      if (isGone(plan, now)) {
        weather = gone(leg);
      } else {
        weather =
            RideWeatherCalculator.leg(leg, key -> cache.getOrDefault(key, CellSeries.EMPTY), now);
        upcoming.add(weather);
      }
      stages.add(new TripWeather.StageLeg(plan.stageId(), weather, departure(plan, cache, now)));
    }
    return RideWeatherCalculator.trip(stages, upcoming);
  }

  /**
   * The weather when the stage leaves, read at its first forecast point — the cell the stage's leg
   * already reads, so no other cell is fetched for it (a ride reads its meeting point instead, with
   * no elevation band). Gives the stage the same departure temperature and daylight as a ride group.
   */
  static DepartureWeather departure(StagePlan plan, Map<CellKey, CellSeries> cache, Instant now) {
    LegInput leg = plan.leg();
    if (isGone(plan, now)) {
      return DepartureWeather.of(WeatherStatus.OUT_OF_RANGE);
    }
    if (leg.samples() == null || leg.samples().samples().isEmpty()) {
      return DepartureWeather.of(WeatherStatus.NO_LOCATION);
    }
    if (RideWeatherCalculator.isBeyondHorizon(leg.start(), now)) {
      return DepartureWeather.of(WeatherStatus.NOT_YET_AVAILABLE);
    }
    CellKey first = leg.samples().samples().getFirst().cell();
    return RideWeatherCalculator.departure(
        cache.getOrDefault(first, CellSeries.EMPTY), leg.start(), now);
  }

  /**
   * A stage that is over: its forecast is no longer shown, as for a ride over. One under way still
   * shows it, to its end (docs/LEDGER_*.md API-163).
   */
  static boolean isGone(StagePlan plan, Instant now) {
    return plan.end().isBefore(now);
  }

  private static WeatherLeg gone(LegInput leg) {
    return new WeatherLeg(
        null,
        WeatherStatus.OUT_OF_RANGE,
        null,
        leg.start(),
        leg.speed().kmh(),
        leg.speed().isDefault(),
        RideWeatherCalculator.round0(leg.distance()),
        leg.arrival(),
        null,
        List.of(),
        List.of(),
        WindExposure.NONE,
        null,
        null,
        null);
  }
}
