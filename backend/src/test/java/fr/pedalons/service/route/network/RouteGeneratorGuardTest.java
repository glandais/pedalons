package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.dto.error.ErrorCode;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

class RouteGeneratorGuardTest {

  /** A clock moved by hand. */
  private static final class Hand extends Clock {
    private Instant now = Instant.parse("2026-11-14T10:00:00Z");

    void advance(Duration d) {
      now = now.plus(d);
    }

    @Override
    public java.time.ZoneId getZone() {
      return ZoneOffset.UTC;
    }

    @Override
    public Clock withZone(java.time.ZoneId zone) {
      return this;
    }

    @Override
    public Instant instant() {
      return now;
    }
  }

  private static RouteGeneratorGuard guard(Hand clock, int concurrent, Duration wait) {
    return RouteGeneratorGuard.of(30, 15, concurrent, wait, Duration.ofSeconds(5), clock);
  }

  @Test
  void thirtyAreAdmitted_thenTheNextOneIsRefusedWithRetryAfter() {
    Hand clock = new Hand();
    RouteGeneratorGuard g = guard(clock, 1, Duration.ofMillis(10));
    for (int i = 0; i < 30; i++) {
      g.admit(1, 10);
      clock.advance(Duration.ofSeconds(1));
    }
    // the first request was 30 s ago: 15 min - 30 s = 870 s left
    TooManyRequestsException e = assertThrows(TooManyRequestsException.class, () -> g.admit(1, 10));
    assertEquals(ErrorCode.ROUTE_GENERATOR_RATE_LIMITED, e.getErrorCode());
    assertEquals(870, e.getRetryAfterSeconds());
  }

  @Test
  void theWindowSlides() {
    Hand clock = new Hand();
    RouteGeneratorGuard g = guard(clock, 1, Duration.ofMillis(10));
    for (int i = 0; i < 30; i++) {
      g.admit(1, 10);
    }
    assertThrows(TooManyRequestsException.class, () -> g.admit(1, 10));
    clock.advance(Duration.ofMinutes(15));
    g.admit(1, 10);
  }

  @Test
  void usersAndDomainsAreIndependent() {
    Hand clock = new Hand();
    RouteGeneratorGuard g = guard(clock, 1, Duration.ofMillis(10));
    for (int i = 0; i < 30; i++) {
      g.admit(1, 10);
    }
    g.admit(1, 11);
    g.admit(2, 10);
  }

  @Test
  void aPermitTimesOutWhenNoneIsFree_andIsReleasedOnException() throws Exception {
    RouteGeneratorGuard g = guard(new Hand(), 1, Duration.ofMillis(50));
    CountDownLatch inside = new CountDownLatch(1);
    CountDownLatch leave = new CountDownLatch(1);
    AtomicReference<Throwable> holderError = new AtomicReference<>();
    Thread holder =
        new Thread(() -> {
          try {
            g.withPermit(() -> {
              inside.countDown();
              try {
                leave.await(5, TimeUnit.SECONDS);
              } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
              }
              return null;
            });
          } catch (Throwable t) {
            holderError.set(t);
          }
        });
    holder.start();
    inside.await(5, TimeUnit.SECONDS);
    ServiceUnavailableException e =
        assertThrows(ServiceUnavailableException.class, () -> g.withPermit(() -> "never"));
    assertEquals(ErrorCode.ROUTE_GENERATOR_BUSY, e.getErrorCode());
    leave.countDown();
    holder.join(5000);
    assertEquals(null, holderError.get());
    assertEquals(1, g.availablePermits());

    assertThrows(
        IllegalStateException.class,
        () ->
            g.withPermit(() -> {
              throw new IllegalStateException("boom");
            }));
    assertEquals(1, g.availablePermits());
  }

  @Test
  void theDeadlineFiresOnceTheBudgetIsSpent() throws Exception {
    RouteGeneratorGuard g =
        RouteGeneratorGuard.of(
            30, 15, 1, Duration.ofMillis(10), Duration.ofMillis(30), Clock.systemUTC());
    var stop = g.deadline();
    assertEquals(false, stop.getAsBoolean());
    Thread.sleep(60);
    assertEquals(true, stop.getAsBoolean());
  }
}
