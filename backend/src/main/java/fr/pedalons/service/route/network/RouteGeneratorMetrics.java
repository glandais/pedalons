package fr.pedalons.service.route.network;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.util.Locale;

/**
 * Metrics of the team route generator (docs/LEDGER_*.md API-198, lot 3), on {@code /q/metrics}:
 * requests by outcome, the time of a generation and of a graph build, the cache results and the
 * size of the cache. Never fails what it measures.
 */
@ApplicationScoped
public class RouteGeneratorMetrics {

  /** What a cache lookup did. */
  public enum CacheResult {
    HIT,
    DEFERRED,
    MISS,
    TOO_LARGE
  }

  @Inject MeterRegistry registry;

  public void request(String outcome) {
    try {
      Counter.builder("pedalons.route_generator.requests")
          .tag("outcome", outcome.toLowerCase(Locale.ROOT))
          .register(registry)
          .increment();
    } catch (RuntimeException e) {
      // a metric never fails what it measures
    }
  }

  public void cache(CacheResult result) {
    try {
      Counter.builder("pedalons.route_generator.cache")
          .tag("result", result.name().toLowerCase(Locale.ROOT))
          .register(registry)
          .increment();
    } catch (RuntimeException e) {
      // ignored
    }
  }

  public void generated(Duration d) {
    time("pedalons.route_generator.generate", d);
  }

  public void built(Duration d) {
    time("pedalons.route_generator.build", d);
  }

  private void time(String name, Duration d) {
    try {
      Timer.builder(name).register(registry).record(d);
    } catch (RuntimeException e) {
      // ignored
    }
  }

  /** Registers the size gauges of the graph cache. */
  void watch(TeamNetworkCache cache) {
    registry.gauge("pedalons.route_generator.cached_teams", cache, c -> c.cachedTeams());
    registry.gauge("pedalons.route_generator.cached_bytes", cache, c -> c.cachedBytes());
  }
}
