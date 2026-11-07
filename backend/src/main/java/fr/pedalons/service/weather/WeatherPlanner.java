package fr.pedalons.service.weather;

import fr.pedalons.domain.ride.Ride;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.gpx.PreviewWeatherRow;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.trip.TripRepository;
import fr.pedalons.repository.trip.TripStageRepository;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.service.weather.RideWeatherCalculator.LegInput;
import fr.pedalons.service.weather.RideWeatherPlans.RidePlan;
import fr.pedalons.service.weather.TripWeatherPlans.StagePlan;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.jboss.logging.Logger;

/**
 * Decides which cells the cache needs, never calling the provider.
 *
 * <p>Every five minutes, the published rides leaving between now and seven days ahead — the window
 * the read side shows ({@code RideWeatherService#isOutOfRange}: a ride already gone is {@code
 * OUT_OF_RANGE}), so no cell is fetched for a forecast nobody can see:
 * their departure cell and the cell of each forecast point of each group, with the passage nearest
 * to now. The same for the dated GPX previews, as a ride without group (docs/LEDGER_*.md API-153). The same for the trip stages leaving in that window, and the trips without stages: the
 * cell of each forecast point of their leg ({@link TripWeatherPlans}). Each cell is upserted with that demand ({@code WeatherCellRepository#upsertDemand}); the
 * refresh interval follows from it ({@link WeatherRefreshPolicy}). Deterministic in the rides and
 * the clock, so a tick replayed — or run by both backends of a rolling deploy — writes the same
 * rows.
 *
 * <p>Across all domains: the cache is global (see {@code fr.pedalons.domain.weather}).
 */
@ApplicationScoped
public class WeatherPlanner {

  private static final Logger LOG = Logger.getLogger(WeatherPlanner.class);

  /** Dated previews read in one pass, the soonest first. */
  static final int MAX_PREVIEWS_PER_PASS = 500;

  @Inject RideRepository rideRepository;
  @Inject RideWeatherPlans plans;
  @Inject TripStageRepository tripStageRepository;
  @Inject TripRepository tripRepository;
  @Inject GpxPreviewRepository gpxPreviewRepository;
  @Inject TripWeatherPlans tripPlans;
  @Inject WeatherCellRepository cellRepository;
  @Inject WeatherFetchWorker fetchWorker;

  @Scheduled(every = "5m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void tick() {
    if (!fetchWorker.isEnabled()) {
      return;
    }
    try {
      int cells = plan(Instant.now());
      LOG.debugf("Weather planner: %d cell(s) in demand", cells);
    } catch (Exception e) {
      LOG.error("Weather planning failed", e);
    }
  }

  /**
   * One planning pass. Public for the tests, which run with the scheduler off.
   *
   * <p>The demand is read in one transaction, then each cell is upserted in its own: the planner
   * never holds a {@code weather_cells} row lock while it waits for another. One pass holding them
   * all to the end, in {@code HashMap} order, closed a cycle with the fetch worker's store
   * transaction — which locks the same rows, in its own order, until it commits — and PostgreSQL
   * aborted one side: the worker's, the provider's answer was thrown away and the batch put into
   * backoff. The same between the two planners of a rolling deploy. Each upsert is idempotent, so a
   * pass cut short loses nothing the next tick does not write again (docs/LEDGER_*.md API-100).
   */
  public int plan(Instant now) {
    Map<CellKey, Instant> demand = QuarkusTransaction.requiringNew().call(() -> demand(now));
    upsert(demand, now);
    return demand.size() + planPreviews(now);
  }

  /**
   * The dated previews, apart from the rides: their number is the people's, not the teams', and a
   * failure or a slow read here must not cost the rides their pass. Never throws.
   */
  private int planPreviews(Instant now) {
    try {
      Map<CellKey, Instant> demand =
          QuarkusTransaction.requiringNew().call(() -> previewsDemand(now));
      upsert(demand, now);
      return demand.size();
    } catch (Exception e) {
      LOG.error("Weather planning of the GPX previews failed", e);
      return 0;
    }
  }

  private Map<CellKey, Instant> previewsDemand(Instant now) {
    Instant until = now.plus(RideWeatherCalculator.HORIZON);
    List<PreviewWeatherRow> previews =
        gpxPreviewRepository.findForWeather(now, until, MAX_PREVIEWS_PER_PASS);
    return demand(plans.previewPlans(previews), List.of(), now);
  }

  private void upsert(Map<CellKey, Instant> demand, Instant now) {
    for (Map.Entry<CellKey, Instant> entry : demand.entrySet()) {
      CellKey key = entry.getKey();
      Instant need = entry.getValue();
      QuarkusTransaction.requiringNew()
          .run(
              () ->
                  cellRepository.upsertDemand(
                      key.latIdx(),
                      key.lonIdx(),
                      key.eleBand(),
                      key.centerLat(),
                      key.centerLon(),
                      need,
                      WeatherRefreshPolicy.ttl(need, now),
                      now));
    }
  }

  /**
   * The cells of one GPX preview, now (docs/LEDGER_*.md API-153). Public for the tests, without the
   * guard of {@link #requestPreview}; 0 when the preview is not dated within the window.
   */
  public int planPreview(long previewId, Instant now) {
    Map<CellKey, Instant> demand =
        QuarkusTransaction.requiringNew().call(() -> previewDemand(previewId, now));
    upsert(demand, now);
    return demand.size();
  }

  /**
   * Asks for the cells of a preview that has just been saved with a date or a speed, so the person
   * does not wait for the next pass. Called after the commit of the save, with no lock held; never
   * fails: the next pass writes the same thing.
   */
  public void requestPreview(long previewId) {
    if (!fetchWorker.isEnabled()) {
      return;
    }
    try {
      planPreview(previewId, Instant.now());
    } catch (Exception e) {
      LOG.warnf(e, "Weather demand of preview %d failed", previewId);
    }
  }

  private Map<CellKey, Instant> previewDemand(long previewId, Instant now) {
    Instant until = now.plus(RideWeatherCalculator.HORIZON);
    return gpxPreviewRepository
        .findForWeather(previewId, now, until)
        .map(row -> demand(List.of(plans.plan(row)), List.of(), now))
        .orElse(Map.of());
  }

  private Map<CellKey, Instant> demand(Instant now) {
    Instant until = now.plus(RideWeatherCalculator.HORIZON);
    List<Ride> rides = rideRepository.findForWeather(now, until);
    List<StagePlan> stages =
        new ArrayList<>(tripPlans.stagePlans(tripStageRepository.findForWeather(now, until)));
    stages.addAll(tripPlans.tripPlans(tripRepository.findStagelessForWeather(now, until)));
    return demand(plans.plans(rides), stages, now);
  }

  /**
   * Cell → nearest passage. A passage already behind us (a group timed before the ride's own
   * departure) counts as {@code now}: its cells want the shortest interval.
   */
  static Map<CellKey, Instant> demand(List<RidePlan> plans, Instant now) {
    return demand(plans, List.of(), now);
  }

  /** The same, with the legs of trip stages on top of the rides. */
  static Map<CellKey, Instant> demand(List<RidePlan> plans, List<StagePlan> stages, Instant now) {
    Map<CellKey, Instant> demand = new HashMap<>();
    for (RidePlan plan : plans) {
      if (plan.departure() != null) {
        need(demand, plan.departure().cell(), plan.departureTime(), now);
      }
      for (LegInput leg : plan.legs()) {
        need(demand, leg, now);
      }
    }
    for (StagePlan stage : stages) {
      need(demand, stage.leg(), now);
    }
    return demand;
  }

  private static void need(Map<CellKey, Instant> demand, LegInput leg, Instant now) {
    if (leg.samples() == null) {
      return;
    }
    for (RouteSamples.Sample sample : leg.samples().samples()) {
      Instant passage =
          RideWeatherCalculator.passage(leg.start(), sample.distance(), leg.speed().kmh());
      need(demand, sample.cell(), passage, now);
    }
  }

  private static void need(
      Map<CellKey, Instant> demand, CellKey cell, Instant passage, Instant now) {
    Instant need = passage.isBefore(now) ? now : passage;
    demand.merge(cell, need, (a, b) -> a.isBefore(b) ? a : b);
  }
}
