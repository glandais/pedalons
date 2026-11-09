package fr.pedalons.service.weather;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.weather.WeatherDaily;
import fr.pedalons.domain.weather.WeatherHourly;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.repository.weather.WeatherDailyRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.panache.common.Sort;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@link WeatherHousekeeping}: the nightly purge keeps the last day of hours and every cell a ride
 * asked for within two days — and nothing else.
 */
@QuarkusTest
class WeatherHousekeepingTest extends AbstractBaseTest {

  @Inject WeatherHousekeeping housekeeping;
  @Inject WeatherCellRepository cellRepository;
  @Inject WeatherHourlyRepository hourlyRepository;
  @Inject WeatherDailyRepository dailyRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  /** 03:40 UTC, when the cron runs, on a fixed day: the dates kept do not depend on the clock. */
  private static final Instant NOW = Instant.parse("2026-10-05T03:40:00Z");

  private static final LocalDate TODAY = LocalDate.ofInstant(NOW, ZoneOffset.UTC);

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
  }

  private long seed(CellKey key, Instant demandedAt) {
    Instant from = NOW.truncatedTo(ChronoUnit.HOURS).minus(Duration.ofDays(3));
    Instant to = NOW.truncatedTo(ChronoUnit.HOURS).plus(Duration.ofDays(1));
    return QuarkusTransaction.requiringNew()
        .call(() ->
            WeatherTestFixtures.seedCell(
                cellRepository,
                hourlyRepository,
                dailyRepository,
                key,
                demandedAt,
                demandedAt,
                WeatherTestFixtures.hours(from, to),
                12,
                WeatherTestFixtures.dates(TODAY.minusDays(4), TODAY.plusDays(1))));
  }

  private List<WeatherHourly> hoursOf(long cellId) {
    return QuarkusTransaction.requiringNew()
        .call(() -> hourlyRepository.list("cellId = ?1", Sort.by("time"), cellId));
  }

  private List<WeatherDaily> daysOf(long cellId) {
    return QuarkusTransaction.requiringNew()
        .call(() -> dailyRepository.list("cellId = ?1", Sort.by("date"), cellId));
  }

  @Test
  void purge_shouldDropHoursMoreThanADayPast_andKeepTheRest() {
    long id = seed(CellKey.of(45.76, 4.83), NOW.minus(Duration.ofMinutes(5)));
    assertEquals(97, hoursOf(id).size()); // 72 hours back, 24 ahead, and this one

    housekeeping.purge(NOW);

    List<WeatherHourly> hours = hoursOf(id);
    Instant cutoff = NOW.minus(Duration.ofDays(1));
    assertTrue(hours.stream().noneMatch(h -> h.getTime().isBefore(cutoff)));
    // From 04:00 yesterday (03:40 minus a day, to the next full hour) to 03:00 tomorrow.
    assertEquals(48, hours.size());
    assertEquals(
        cutoff.truncatedTo(ChronoUnit.HOURS).plus(1, ChronoUnit.HOURS), hours.getFirst().getTime());
    // Days: a day's margin before yesterday, for every zone's local "yesterday".
    List<WeatherDaily> days = daysOf(id);
    assertEquals(TODAY.minusDays(2), days.getFirst().getDate());
    assertEquals(4, days.size());
  }

  @Test
  void purge_shouldDropCellsNobodyAskedForInTwoDays_withTheirRows() {
    long forgotten = seed(CellKey.of(45.76, 4.83), NOW.minus(Duration.ofDays(3)));
    long recent = seed(CellKey.of(45.86, 4.83), NOW.minus(Duration.ofDays(1)));

    housekeeping.purge(NOW);

    assertNull(QuarkusTransaction.requiringNew().call(() -> cellRepository.findById(forgotten)));
    assertTrue(hoursOf(forgotten).isEmpty());
    assertTrue(daysOf(forgotten).isEmpty());
    assertNotNull(QuarkusTransaction.requiringNew().call(() -> cellRepository.findById(recent)));
    assertEquals(48, hoursOf(recent).size());
    assertEquals(4, daysOf(recent).size());
  }

  @Test
  void purge_shouldKeepACellWithItsElevationBand_asLongAsItIsAskedFor() {
    long banded = seed(CellKey.of(45.76, 4.83, 640.0), NOW.minus(Duration.ofHours(1)));
    long plain = seed(CellKey.of(45.76, 4.83), NOW.minus(Duration.ofDays(3)));

    housekeeping.purge(NOW);

    // Same 5 km cell, different band: two cells, two fates.
    assertNotNull(QuarkusTransaction.requiringNew().call(() -> cellRepository.findById(banded)));
    assertNull(QuarkusTransaction.requiringNew().call(() -> cellRepository.findById(plain)));
  }

  @Test
  void purge_shouldKeepAForgottenCell_whileAWorkerHoldsItsLease() {
    long leased = seed(CellKey.of(45.76, 4.83), NOW.minus(Duration.ofDays(3)));
    long expired = seed(CellKey.of(45.86, 4.83), NOW.minus(Duration.ofDays(3)));
    QuarkusTransaction.requiringNew()
        .run(() -> {
          cellRepository.findById(leased).setClaimedUntil(NOW.plus(Duration.ofMinutes(2)));
          cellRepository.findById(expired).setClaimedUntil(NOW.minus(Duration.ofMinutes(1)));
        });

    housekeeping.purge(NOW);

    // The worker's upsert of its rows must not hit a deleted parent; the next night drops it.
    assertNotNull(QuarkusTransaction.requiringNew().call(() -> cellRepository.findById(leased)));
    assertNull(QuarkusTransaction.requiringNew().call(() -> cellRepository.findById(expired)));
  }

  @Test
  void purge_twice_shouldChangeNothingTheSecondTime() {
    long id = seed(CellKey.of(45.76, 4.83), NOW.minus(Duration.ofMinutes(5)));
    housekeeping.purge(NOW);
    int hours = hoursOf(id).size();
    int days = daysOf(id).size();

    housekeeping.purge(NOW);

    assertEquals(hours, hoursOf(id).size());
    assertEquals(days, daysOf(id).size());
    assertEquals(1, QuarkusTransaction.requiringNew().call(() -> cellRepository.count()));
  }
}
