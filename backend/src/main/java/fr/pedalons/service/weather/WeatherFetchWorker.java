package fr.pedalons.service.weather;

import fr.pedalons.domain.weather.WeatherCell;
import fr.pedalons.domain.weather.WeatherDaily;
import fr.pedalons.domain.weather.WeatherHourly;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoCircuitBreaker;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoException;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoForecast;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.repository.weather.WeatherDailyRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Refreshes the due weather cells from Open-Meteo — the only code that calls the provider.
 *
 * <p>Every minute, in rounds of up to {@value #BATCH} cells, nearest passage first — only the cells a
 * planning pass of the last {@link #DEMAND_FRESHNESS} asked for, for a passage still ahead:
 *
 * <ol>
 *   <li><b>claim</b>, in its own transaction ({@code QuarkusTransaction.requiringNew()}, as {@code
 *       NotificationDispatchService}): {@code FOR UPDATE SKIP LOCKED}, then a lease ({@code
 *       claimed_until}) so the provider call runs with no transaction and no row lock open, and a
 *       second backend of a rolling deploy skips these cells;
 *   <li><b>fetch</b>, one request per batch — cells with an elevation band and cells without go in
 *       separate requests, since {@code elevation} is all or nothing;
 *   <li><b>store</b>, in a new transaction: forecast rows upserted, cell marked fetched, its next
 *       refresh set by {@link WeatherRefreshPolicy}.
 * </ol>
 *
 * <p>A failure never deletes anything — the cache is served {@code STALE} meanwhile. It is written
 * on the cells as a backoff of {@code min(5 min · 2^attempts, 1 h)}, the next full hour for a 429,
 * and fed to the in-memory breaker, which stops the rounds for ten minutes after three failures in
 * a row or a 429. The budgets of the breaker cap the locations asked for: per UTC day, per hour,
 * and per sliding minute — Open-Meteo bills each location as a call and refuses more than 600 a
 * minute on the free plan, which a backlog of {@value #MAX_ROUNDS} rounds would otherwise exceed.
 */
@ApplicationScoped
public class WeatherFetchWorker {

  private static final Logger LOG = Logger.getLogger(WeatherFetchWorker.class);

  /** Locations per request. */
  static final int BATCH = 100;

  /** Rounds per tick: a backlog drains within minutes, without one tick monopolising a thread. */
  static final int MAX_ROUNDS = 10;

  /**
   * How recently the planner (every 5 min) must have asked for a cell for it to be fetched: four of
   * its periods, so a slow or failed tick does not starve the cache, while a cell nobody plans any
   * more stops being refreshed within minutes rather than at the nightly purge.
   */
  static final Duration DEMAND_FRESHNESS = Duration.ofMinutes(20);

  /** Longer than two requests at their 15 s read timeout plus the writes. */
  static final Duration LEASE = Duration.ofMinutes(5);

  @Inject OpenMeteoGateway gateway;
  @Inject OpenMeteoCircuitBreaker breaker;
  @Inject WeatherCellRepository cellRepository;
  @Inject WeatherHourlyRepository hourlyRepository;
  @Inject WeatherDailyRepository dailyRepository;

  /** A claimed cell, detached from the claiming transaction. */
  record Claimed(
      long id,
      double latitude,
      double longitude,
      @Nullable Integer eleBand,
      @Nullable Instant need) {}

  public boolean isEnabled() {
    return gateway.isEnabled();
  }

  @Scheduled(every = "1m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void tick() {
    if (!gateway.isEnabled()) {
      return;
    }
    try {
      int fetched = fetchDue();
      if (fetched > 0) {
        LOG.debugf("Weather: %d cell(s) refreshed", fetched);
      }
    } catch (Exception e) {
      LOG.error("Weather refresh failed", e);
    }
  }

  /**
   * Refreshes due cells until none is left, the breaker opens, the budget runs out or {@value
   * #MAX_ROUNDS} rounds have run. Public for the tests (scheduler off, gateway mocked). No
   * {@code @Transactional}: each step opens its own.
   *
   * @return how many cells were stored
   */
  public int fetchDue() {
    int stored = 0;
    for (int round = 0; round < MAX_ROUNDS; round++) {
      Instant now = Instant.now();
      if (!breaker.isClosed(now)) {
        break;
      }
      int budget = breaker.remainingBudget(now);
      if (budget <= 0) {
        if (breaker.isDailyBudgetSpent(now)) {
          LOG.warn("Weather: daily Open-Meteo call budget spent, refresh paused until 00:00 UTC");
        } else {
          LOG.debug("Weather: per-minute or hourly Open-Meteo budget reached, next tick resumes");
        }
        break;
      }
      List<Claimed> claimed = claim(Math.min(BATCH, budget), now);
      if (claimed.isEmpty()) {
        break;
      }
      List<Claimed> withElevation = new ArrayList<>();
      List<Claimed> withoutElevation = new ArrayList<>();
      for (Claimed cell : claimed) {
        (cell.eleBand() != null ? withElevation : withoutElevation).add(cell);
      }
      stored += fetchAndStore(withoutElevation);
      stored += fetchAndStore(withElevation);
      if (claimed.size() < BATCH || !breaker.isClosed(Instant.now())) {
        break;
      }
    }
    return stored;
  }

  List<Claimed> claim(int limit, Instant now) {
    return QuarkusTransaction.requiringNew()
        .call(() -> {
          List<Long> ids =
              cellRepository.findDueIdsSkipLocked(now, now.minus(DEMAND_FRESHNESS), limit);
          if (ids.isEmpty()) {
            return List.<Claimed>of();
          }
          cellRepository.lease(ids, now.plus(LEASE));
          List<Claimed> claimed = new ArrayList<>(ids.size());
          for (WeatherCell cell : cellRepository.list("id in ?1", ids)) {
            claimed.add(
                new Claimed(
                    cell.getId(),
                    cell.getLatitude(),
                    cell.getLongitude(),
                    cell.getEleBand(),
                    cell.getNearestNeedAt()));
          }
          return claimed;
        });
  }

  /** One request for {@code cells}, then their storage. Returns how many were stored. */
  int fetchAndStore(List<Claimed> cells) {
    if (cells.isEmpty()) {
      return 0;
    }
    List<Long> ids = cells.stream().map(Claimed::id).toList();
    Instant now = Instant.now();
    if (!breaker.isClosed(now)) {
      QuarkusTransaction.requiringNew().run(() -> cellRepository.release(ids));
      return 0;
    }
    List<Location> locations =
        cells.stream()
            .map(c ->
                new Location(
                    c.latitude(),
                    c.longitude(),
                    c.eleBand() == null ? null : c.eleBand().doubleValue()))
            .toList();
    List<OpenMeteoForecast> forecasts;
    try {
      breaker.recordCalls(locations.size(), now);
      forecasts = gateway.forecast(locations);
    } catch (OpenMeteoException e) {
      fail(ids, e.getMessage(), e.isRateLimited());
      return 0;
    } catch (RuntimeException e) {
      fail(
          ids,
          e.getClass().getSimpleName() + ": " + OpenMeteoGateway.redact(e.getMessage()),
          false);
      return 0;
    }
    breaker.recordSuccess();
    try {
      Instant fetchedAt = Instant.now();
      QuarkusTransaction.requiringNew()
          .run(() -> {
            for (int i = 0; i < cells.size(); i++) {
              store(cells.get(i), forecasts.get(i), fetchedAt);
            }
          });
      return cells.size();
    } catch (RuntimeException e) {
      // The provider answered; the database did not take it. Backed off like any failure, but the
      // breaker stays out of it: the provider is fine.
      LOG.errorf(e, "Weather: storing %d cell(s) failed", cells.size());
      QuarkusTransaction.requiringNew()
          .run(() ->
              cellRepository.markFailed(
                  ids,
                  truncate("store: " + e.getClass().getSimpleName()),
                  WeatherRefreshPolicy.BACKOFF_BASE,
                  WeatherRefreshPolicy.BACKOFF_MAX,
                  Instant.now()));
      return 0;
    }
  }

  private void store(Claimed cell, OpenMeteoForecast forecast, Instant fetchedAt) {
    List<WeatherHourly> hours = new ArrayList<>(forecast.hours().size());
    for (OpenMeteoForecast.Hour hour : forecast.hours()) {
      WeatherHourly row = new WeatherHourly();
      row.setCellId(cell.id());
      row.setTime(hour.time());
      row.setTemperature(hour.temperature());
      row.setApparentTemperature(hour.apparentTemperature());
      row.setPrecipitationProbability(hour.precipitationProbability());
      row.setPrecipitation(hour.precipitation());
      row.setWeatherCode(hour.weatherCode());
      row.setWindSpeed(hour.windSpeed());
      row.setWindDirection(hour.windDirection());
      row.setWindGusts(hour.windGusts());
      hours.add(row);
    }
    List<WeatherDaily> days = new ArrayList<>(forecast.days().size());
    for (OpenMeteoForecast.Day day : forecast.days()) {
      WeatherDaily row = new WeatherDaily();
      row.setCellId(cell.id());
      row.setDate(day.date());
      row.setSunrise(day.sunrise());
      row.setSunset(day.sunset());
      days.add(row);
    }
    hourlyRepository.upsert(cell.id(), hours);
    dailyRepository.upsert(cell.id(), days);
    cellRepository.markFetched(
        cell.id(),
        forecast.elevation(),
        forecast.timezone(),
        fetchedAt,
        fetchedAt.plus(WeatherRefreshPolicy.ttl(cell.need(), fetchedAt)));
  }

  private void fail(List<Long> ids, String message, boolean rateLimited) {
    Instant now = Instant.now();
    String error = truncate(message);
    LOG.warnf("Weather: Open-Meteo request for %d cell(s) failed: %s", ids.size(), error);
    if (rateLimited) {
      breaker.recordRateLimited(now);
      QuarkusTransaction.requiringNew()
          .run(() ->
              cellRepository.markRateLimited(
                  ids, error, WeatherRefreshPolicy.retryAfterRateLimit(now), now));
    } else {
      breaker.recordFailure(now);
      QuarkusTransaction.requiringNew()
          .run(() ->
              cellRepository.markFailed(
                  ids,
                  error,
                  WeatherRefreshPolicy.BACKOFF_BASE,
                  WeatherRefreshPolicy.BACKOFF_MAX,
                  now));
    }
  }

  static String truncate(@Nullable String message) {
    if (message == null) {
      return "";
    }
    return message.length() <= 500 ? message : message.substring(0, 500);
  }
}
