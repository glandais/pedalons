package fr.pedalons.service.weather;

import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.jspecify.annotations.Nullable;

/**
 * How often a cell is refreshed, how long a failure waits, and when a cached forecast is too old to
 * show without a warning. Pure functions of their arguments: the planner that writes {@code
 * next_refresh_at} and the reader that flags {@code STALE} agree because they call the same code.
 *
 * <p>A forecast changes less the further out it looks: a passage more than two days away is
 * refreshed every 6 h (a model run), within two days every 3 h, within a day every hour.
 */
public final class WeatherRefreshPolicy {

  /** A failure is retried after {@code min(5 min · 2^attempts, 1 h)}. */
  public static final Duration BACKOFF_BASE = Duration.ofMinutes(5);

  public static final Duration BACKOFF_MAX = Duration.ofHours(1);

  /** A cached forecast older than this many refresh intervals is shown as {@code STALE}. */
  static final int STALE_AFTER_INTERVALS = 2;

  private WeatherRefreshPolicy() {}

  /**
   * The refresh interval of a cell whose closest passage is {@code nearestNeed}. A passage in the
   * past, or none known, counts as {@code now} and as never, respectively.
   */
  public static Duration ttl(@Nullable Instant nearestNeed, Instant now) {
    if (nearestNeed == null) {
      return Duration.ofHours(6);
    }
    Duration ahead = Duration.between(now, nearestNeed);
    if (ahead.compareTo(Duration.ofHours(48)) > 0) {
      return Duration.ofHours(6);
    }
    if (ahead.compareTo(Duration.ofHours(24)) >= 0) {
      return Duration.ofHours(3);
    }
    return Duration.ofHours(1);
  }

  /**
   * Whether a forecast fetched at {@code fetchedAt}, read for {@code passage}, is overdue.
   *
   * <p>A passage already behind us is judged at the passage itself: the worker no longer refreshes
   * a cell needed only in the past, so what was fetched shortly before the passage is the best
   * there will be, and is not flagged — or the stretch a group under way has ridden would turn
   * {@code STALE} two hours later (docs/LEDGER_*.md API-163). Was it already overdue when the group
   * rode by, it still is.
   */
  public static boolean isStale(Instant fetchedAt, Instant passage, Instant now) {
    Instant at = passage.isBefore(now) ? passage : now;
    Duration age = Duration.between(fetchedAt, at);
    return age.compareTo(ttl(passage, at).multipliedBy(STALE_AFTER_INTERVALS)) > 0;
  }

  /** When a rate-limited request may be tried again: the next full hour. */
  public static Instant retryAfterRateLimit(Instant now) {
    return now.truncatedTo(ChronoUnit.HOURS).plus(1, ChronoUnit.HOURS);
  }
}
