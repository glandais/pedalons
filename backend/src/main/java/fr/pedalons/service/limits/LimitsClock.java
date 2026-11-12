package fr.pedalons.service.limits;

import jakarta.enterprise.context.ApplicationScoped;
import java.time.Clock;
import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * The time the plan's quotas are read at (docs/LEDGER_*.md BILL-10): the month a save falls in, the
 * day of a route calculation. A bean so that a test can move to the next month without waiting.
 */
@ApplicationScoped
public class LimitsClock {

  private volatile Clock clock = Clock.systemUTC();

  public Instant now() {
    return clock.instant();
  }

  /** Tests only: a fixed or offset clock; null goes back to the system clock. */
  public void setForTest(@Nullable Clock testClock) {
    this.clock = testClock != null ? testClock : Clock.systemUTC();
  }
}
