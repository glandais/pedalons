package fr.pedalons.service.weather;

import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.weather.RideWeatherCalculator.LegInput;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * Works out when and where each stage of a trip is ridden — what {@link RideWeatherPlans} is for a
 * ride, and for the same reason: the planner and the detail read must agree on every point.
 *
 * <p>A stage leaves at its own {@code dateTime}, a real departure instant (the editor picks a date
 * and a time; a stage migrated from biketeam gets the trip's meeting time or 8am), so no zone is
 * involved. It rides its route at its {@code averageSpeed}, else the default. A trip without any
 * live stage is one leg: its own route at its own time. There is no departure block: a stage's
 * first checkpoint is its start.
 */
@ApplicationScoped
public class TripWeatherPlans {

  @Inject GpxTrackRepository gpxTrackRepository;
  @Inject RideWeatherPlans ridePlans;

  /**
   * A stage, located.
   *
   * @param stageId null for the leg of a trip without stages
   * @param end until when the stage's weather is shown: the end of the local day, in the stage's
   *     zone, of its stored end ({@link PublicationEndCalculator#effectiveEnd}) — the trip's, in
   *     the trip's zone, for a trip without stages ({@link RideWeatherCalculator#shownUntil},
   *     docs/LEDGER_*.md API-170 and API-183)
   */
  public record StagePlan(@Nullable Long stageId, LegInput leg, Instant end) {}

  /** The legs of a trip, one per live stage in stage order. */
  public List<StagePlan> plan(Trip trip) {
    List<TripStage> stages = liveStages(trip);
    if (stages.isEmpty()) {
      Route route = RideWeatherPlans.live(trip.getRoute());
      Map<Long, List<Long>> trackIds =
          gpxTrackRepository.findIdsByRouteIds(route == null ? Set.of() : Set.of(route.getId()));
      return List.of(
          new StagePlan(
              null,
              new LegInput(
                  null,
                  trip.getDateTime(),
                  RideWeatherCalculator.speed(null),
                  ridePlans.samples(route, trackIds)),
              RideWeatherCalculator.shownUntil(
                  PublicationEndCalculator.effectiveEnd(trip), trip.zone())));
    }
    return stagePlans(stages);
  }

  /** The legs of a trip without live stages, for the planner, with one track-id query. */
  public List<StagePlan> tripPlans(Collection<Trip> trips) {
    Set<Long> routeIds = new HashSet<>();
    for (Trip trip : trips) {
      Route route = RideWeatherPlans.live(trip.getRoute());
      if (route != null) {
        routeIds.add(route.getId());
      }
    }
    Map<Long, List<Long>> trackIds = gpxTrackRepository.findIdsByRouteIds(routeIds);
    List<StagePlan> plans = new ArrayList<>(trips.size());
    for (Trip trip : trips) {
      plans.add(
          new StagePlan(
              null,
              new LegInput(
                  null,
                  trip.getDateTime(),
                  RideWeatherCalculator.speed(null),
                  ridePlans.samples(RideWeatherPlans.live(trip.getRoute()), trackIds)),
              RideWeatherCalculator.shownUntil(
                  PublicationEndCalculator.effectiveEnd(trip), trip.zone())));
    }
    return plans;
  }

  /** The legs of some stages, in the order given, with one track-id query for all their routes. */
  public List<StagePlan> stagePlans(Collection<TripStage> stages) {
    Set<Long> routeIds = new HashSet<>();
    for (TripStage stage : stages) {
      Route route = RideWeatherPlans.live(stage.getRoute());
      if (route != null) {
        routeIds.add(route.getId());
      }
    }
    Map<Long, List<Long>> trackIds = gpxTrackRepository.findIdsByRouteIds(routeIds);
    List<StagePlan> plans = new ArrayList<>(stages.size());
    for (TripStage stage : stages) {
      plans.add(
          new StagePlan(
              stage.getId(),
              new LegInput(
                  null,
                  stage.getDateTime(),
                  RideWeatherCalculator.speed(stage.getAverageSpeed()),
                  ridePlans.samples(RideWeatherPlans.live(stage.getRoute()), trackIds)),
              RideWeatherCalculator.shownUntil(
                  PublicationEndCalculator.effectiveEnd(stage), stage.zone())));
    }
    return plans;
  }

  /** The live stages in the order {@code TripDto} lists them. */
  static List<TripStage> liveStages(Trip trip) {
    return trip.getStages().stream()
        .filter(stage -> !stage.isDeleted())
        .sorted(
            Comparator.comparingInt(TripStage::getSortOrder)
                .thenComparing(TripStage::getId, Comparator.nullsLast(Comparator.naturalOrder())))
        .toList();
  }
}
