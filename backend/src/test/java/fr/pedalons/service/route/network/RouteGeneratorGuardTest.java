package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.dto.error.ErrorCode;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
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

  private static RouteGeneratorGuard guard(Hand clock) {
    return RouteGeneratorGuard.of(30, 15, clock);
  }

  @Test
  void thirtyAreAdmitted_thenTheNextOneIsRefusedWithRetryAfter() {
    Hand clock = new Hand();
    RouteGeneratorGuard g = guard(clock);
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
    RouteGeneratorGuard g = guard(clock);
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
    RouteGeneratorGuard g = guard(clock);
    for (int i = 0; i < 30; i++) {
      g.admit(1, 10);
    }
    g.admit(1, 11);
    g.admit(2, 10);
  }
}
