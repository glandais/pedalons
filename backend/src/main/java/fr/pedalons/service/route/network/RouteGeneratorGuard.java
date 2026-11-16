package fr.pedalons.service.route.network;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.dto.error.ErrorCode;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

/**
 * The rate limit of the route generator (docs/LEDGER_*.md API-198, lot 3 plan §3.5): a sliding
 * window per user. The places and the time budget of a generation are the engine's own (lot 3b,
 * 503 {@code overloaded}).
 *
 * <p>In memory on purpose, unlike the table-backed limiters: what it protects is the engine's CPU
 * from one user. There is one replica, two for the minute of a deploy.
 */
@ApplicationScoped
public class RouteGeneratorGuard {

  @ConfigProperty(name = "pedalons.route-generator.rate.max-per-window", defaultValue = "30")
  int maxPerWindow;

  @ConfigProperty(name = "pedalons.route-generator.rate.window-minutes", defaultValue = "15")
  int windowMinutes;

  private Clock clock = Clock.systemUTC();
  private Cache<String, ArrayDeque<Long>> windows;

  /** For CDI. */
  RouteGeneratorGuard() {}

  /** For the tests: the same guard without a container. */
  static RouteGeneratorGuard of(int maxPerWindow, int windowMinutes, Clock clock) {
    RouteGeneratorGuard g = new RouteGeneratorGuard();
    g.maxPerWindow = maxPerWindow;
    g.windowMinutes = windowMinutes;
    g.clock = clock;
    g.init();
    return g;
  }

  @PostConstruct
  void init() {
    windows = Caffeine.newBuilder().expireAfterAccess(Duration.ofMinutes(windowMinutes)).build();
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
}
