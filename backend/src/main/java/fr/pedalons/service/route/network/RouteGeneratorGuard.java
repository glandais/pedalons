package fr.pedalons.service.route.network;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.dto.error.ErrorCode;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.function.BooleanSupplier;
import java.util.function.Supplier;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

/**
 * The CPU guards of the route generator (docs/LEDGER_*.md API-198, lot 3 plan §3.5): a sliding
 * window per user, a number of generations at once per instance, and the time budget of one run.
 *
 * <p>In memory on purpose, unlike the table-backed limiters: what it protects is the CPU of the
 * instance that serves the request. There is one replica, two for the minute of a deploy.
 */
@ApplicationScoped
public class RouteGeneratorGuard {

  @ConfigProperty(name = "pedalons.route-generator.rate.max-per-window", defaultValue = "30")
  int maxPerWindow;

  @ConfigProperty(name = "pedalons.route-generator.rate.window-minutes", defaultValue = "15")
  int windowMinutes;

  /** 0: half of the cores, at least one. */
  @ConfigProperty(name = "pedalons.route-generator.max-concurrent", defaultValue = "0")
  int maxConcurrent;

  @ConfigProperty(name = "pedalons.route-generator.permit-wait", defaultValue = "PT2S")
  Duration permitWait;

  @ConfigProperty(name = "pedalons.route-generator.time-budget", defaultValue = "PT5S")
  Duration timeBudget;

  private Clock clock = Clock.systemUTC();
  private Cache<String, ArrayDeque<Long>> windows;
  private Semaphore permits;

  /** For CDI. */
  RouteGeneratorGuard() {}

  /** For the tests: the same guard without a container. */
  static RouteGeneratorGuard of(
      int maxPerWindow,
      int windowMinutes,
      int maxConcurrent,
      Duration permitWait,
      Duration timeBudget,
      Clock clock) {
    RouteGeneratorGuard g = new RouteGeneratorGuard();
    g.maxPerWindow = maxPerWindow;
    g.windowMinutes = windowMinutes;
    g.maxConcurrent = maxConcurrent;
    g.permitWait = permitWait;
    g.timeBudget = timeBudget;
    g.clock = clock;
    g.init();
    return g;
  }

  @PostConstruct
  void init() {
    windows = Caffeine.newBuilder().expireAfterAccess(Duration.ofMinutes(windowMinutes)).build();
    int n =
        maxConcurrent > 0
            ? maxConcurrent
            : Math.max(1, Runtime.getRuntime().availableProcessors() / 2);
    permits = new Semaphore(n, true);
  }

  /** Tests only: forgets every window and goes back to the system clock when {@code clock} is null. */
  public void clear() {
    windows.invalidateAll();
  }

  /** Tests only. */
  public void setClockForTest(@Nullable Clock testClock) {
    this.clock = testClock != null ? testClock : Clock.systemUTC();
  }

  /**
   * Counts one request of the user.
   *
   * @throws TooManyRequestsException {@code ROUTE_GENERATOR_RATE_LIMITED}, with the seconds until
   *     the oldest request of the window leaves it
   */
  public void admit(long domainId, long userId) {
    long now = clock.millis();
    long windowMs = Duration.ofMinutes(windowMinutes).toMillis();
    ArrayDeque<Long> window =
        windows.get(domainId + ":" + userId, k -> new ArrayDeque<>(maxPerWindow + 1));
    synchronized (window) {
      while (!window.isEmpty() && window.peekFirst() <= now - windowMs) {
        window.pollFirst();
      }
      if (window.size() >= maxPerWindow) {
        long retryMs = window.peekFirst() + windowMs - now;
        throw new TooManyRequestsException(
            ErrorCode.ROUTE_GENERATOR_RATE_LIMITED, (retryMs + 999) / 1000);
      }
      window.addLast(now);
    }
  }

  /**
   * Runs {@code work} holding one of the generation permits.
   *
   * @throws ServiceUnavailableException {@code ROUTE_GENERATOR_BUSY}: no permit within the wait
   */
  public <T> T withPermit(Supplier<T> work) {
    boolean acquired;
    try {
      acquired = permits.tryAcquire(permitWait.toMillis(), TimeUnit.MILLISECONDS);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
    }
    if (!acquired) {
      throw new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
    }
    try {
      return work.get();
    } finally {
      permits.release();
    }
  }

  /** Permits free right now, for the tests. */
  int availablePermits() {
    return permits.availablePermits();
  }

  /** A stop signal that fires once the time budget, counted from now, is spent. */
  public BooleanSupplier deadline() {
    long end = System.nanoTime() + timeBudget.toNanos();
    return () -> System.nanoTime() - end >= 0;
  }
}
