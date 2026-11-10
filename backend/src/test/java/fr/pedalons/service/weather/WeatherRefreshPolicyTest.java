package fr.pedalons.service.weather;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;

class WeatherRefreshPolicyTest {

  private static final Instant NOW = Instant.parse("2026-10-05T12:20:00Z");

  @Test
  void ttl_shouldShortenAsThePassageComesCloser() {
    assertEquals(
        Duration.ofHours(6), WeatherRefreshPolicy.ttl(NOW.plus(Duration.ofHours(72)), NOW));
    assertEquals(
        Duration.ofHours(3), WeatherRefreshPolicy.ttl(NOW.plus(Duration.ofHours(30)), NOW));
    assertEquals(Duration.ofHours(1), WeatherRefreshPolicy.ttl(NOW.plus(Duration.ofHours(5)), NOW));
    assertEquals(
        Duration.ofHours(1), WeatherRefreshPolicy.ttl(NOW.minus(Duration.ofHours(1)), NOW));
    assertEquals(Duration.ofHours(6), WeatherRefreshPolicy.ttl(null, NOW));
  }

  @Test
  void ttl_atTheBoundaries_shouldTakeTheShorterSideFromADayOn() {
    assertEquals(
        Duration.ofHours(3), WeatherRefreshPolicy.ttl(NOW.plus(Duration.ofHours(48)), NOW));
    assertEquals(
        Duration.ofHours(6),
        WeatherRefreshPolicy.ttl(NOW.plus(Duration.ofHours(48)).plusSeconds(1), NOW));
    assertEquals(
        Duration.ofHours(3), WeatherRefreshPolicy.ttl(NOW.plus(Duration.ofHours(24)), NOW));
    assertEquals(
        Duration.ofHours(1),
        WeatherRefreshPolicy.ttl(NOW.plus(Duration.ofHours(24)).minusSeconds(1), NOW));
  }

  @Test
  void isStale_farAhead_shouldTolerateTwoModelRuns() {
    Instant nextWeek = NOW.plus(Duration.ofDays(5));
    assertFalse(WeatherRefreshPolicy.isStale(NOW.minus(Duration.ofHours(12)), nextWeek, NOW));
    assertTrue(
        WeatherRefreshPolicy.isStale(
            NOW.minus(Duration.ofHours(12)).minusSeconds(1), nextWeek, NOW));
  }

  @Test
  void backoff_shouldStartAtFiveMinutesAndStopAtAnHour() {
    // The SQL of WeatherCellRepository#markFailed computes min(base · 2^attempts, max) from these.
    assertEquals(Duration.ofMinutes(5), WeatherRefreshPolicy.BACKOFF_BASE);
    assertEquals(Duration.ofHours(1), WeatherRefreshPolicy.BACKOFF_MAX);
  }

  @Test
  void isStale_afterTwoIntervals() {
    Instant tomorrowMorning = NOW.plus(Duration.ofHours(20));
    assertFalse(
        WeatherRefreshPolicy.isStale(NOW.minus(Duration.ofMinutes(90)), tomorrowMorning, NOW));
    assertTrue(WeatherRefreshPolicy.isStale(NOW.minus(Duration.ofHours(3)), tomorrowMorning, NOW));
  }

  @Test
  void retryAfterRateLimit_shouldBeTheNextFullHour() {
    assertEquals(
        Instant.parse("2026-10-05T13:00:00Z"), WeatherRefreshPolicy.retryAfterRateLimit(NOW));
    // On the hour exactly: the next one, never now.
    assertEquals(
        Instant.parse("2026-10-05T14:00:00Z"),
        WeatherRefreshPolicy.retryAfterRateLimit(Instant.parse("2026-10-05T13:00:00Z")));
  }

  /** docs/LEDGER_*.md API-163: a stretch already ridden is judged when it was ridden. */
  @Test
  void isStale_ofAPassageBehindUs_shouldBeJudgedAtThePassage() {
    Instant ridden = NOW.minus(Duration.ofHours(3));
    // Fetched 40 min before the group rode by, four hours ago now: not overdue.
    assertFalse(WeatherRefreshPolicy.isStale(ridden.minus(Duration.ofMinutes(40)), ridden, NOW));
    // Already three hours old when it rode by: overdue then, still overdue.
    assertTrue(WeatherRefreshPolicy.isStale(ridden.minus(Duration.ofHours(3)), ridden, NOW));
  }
}
