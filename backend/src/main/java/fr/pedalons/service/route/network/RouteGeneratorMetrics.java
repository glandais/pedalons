package fr.pedalons.service.route.network;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Metrics of the route generator, on {@code /q/metrics} (lot 3b plan §6.4): requests by outcome,
 * the time of a generation, routes dropped by the sanity check, the ascent outcomes, and the
 * nightly overlay deposits. Labels are fixed sets; never a key, a digest, a coordinate, a name.
 * Never fails what it measures.
 */
@ApplicationScoped
public class RouteGeneratorMetrics {

  @Inject MeterRegistry registry;

  private final AtomicLong lastSuccess = new AtomicLong();
  private volatile boolean gaugeRegistered;

  public void request(String outcome) {
    count("pedalons.route_generator.requests", "outcome", outcome);
  }

  public void generated(Duration d) {
    time("pedalons.route_generator.generate", d);
  }

  /** A route dropped by {@link GeneratedRouteSanity}. */
  public void dropped(String check) {
    count("pedalons.route_generator.dropped", "check", check);
  }

  /** {@code ok}, {@code late} or {@code failed}. */
  public void ascent(String outcome) {
    count("pedalons.route_generator.ascent", "outcome", outcome);
  }

  /**
   * A retouch of a saved route (docs/plans/2026-11-24-retouche-parcours-lot7c.md §3.5): {@code
   * operation} is {@code resize} or {@code move_end}, {@code outcome} {@code ok}, a reason of the
   * engine in lower case, {@code not_ready}, {@code unsupported}, {@code unavailable}, {@code
   * rate_limited} or {@code sanity}. Fixed sets: never a coordinate, a distance or a name.
   */
  public void retouch(String operation, String outcome) {
    try {
      Counter.builder("pedalons.route_retouch.requests")
          .tag("operation", operation.toLowerCase(Locale.ROOT))
          .tag("outcome", outcome.toLowerCase(Locale.ROOT))
          .register(registry)
          .increment();
    } catch (RuntimeException e) {
      // a metric never fails what it measures
    }
  }

  public void retouchDuration(String operation, Duration d) {
    try {
      Timer.builder("pedalons.route_retouch.duration")
          .tag("operation", operation.toLowerCase(Locale.ROOT))
          .register(registry)
          .record(d);
    } catch (RuntimeException e) {
      // ignored
    }
  }

  public void deposit(String outcome) {
    count("pedalons.route_generator.overlay.deposits", "outcome", outcome);
  }

  public void depositTime(Duration d) {
    time("pedalons.route_generator.overlay.deposit", d);
  }

  public void passTime(Duration d) {
    time("pedalons.route_generator.overlay.pass", d);
  }

  /** A pass that ended without a failure that cut it short. */
  public void passSucceeded(Instant at) {
    lastSuccess.set(at.getEpochSecond());
    if (!gaugeRegistered) {
      gaugeRegistered = true;
      try {
        registry.gauge(
            "pedalons.route_generator.overlay.last_success", lastSuccess, AtomicLong::get);
      } catch (RuntimeException e) {
        // ignored
      }
    }
  }

  private void count(String name, String tag, String value) {
    try {
      Counter.builder(name).tag(tag, value.toLowerCase(Locale.ROOT)).register(registry).increment();
    } catch (RuntimeException e) {
      // a metric never fails what it measures
    }
  }

  private void time(String name, Duration d) {
    try {
      Timer.builder(name).register(registry).record(d);
    } catch (RuntimeException e) {
      // ignored
    }
  }
}
