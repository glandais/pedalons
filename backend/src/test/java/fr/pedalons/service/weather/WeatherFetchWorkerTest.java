package fr.pedalons.service.weather;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.weather.WeatherCell;
import fr.pedalons.domain.weather.WeatherHourly;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoCircuitBreaker;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoException;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.repository.weather.WeatherDailyRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.weather.WeatherFetchWorker.Claimed;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * {@link WeatherFetchWorker} against the real cache tables, the provider and its breaker mocked:
 * the claim and its lease, what a success writes (and writes again), and what a failure leaves —
 * never less than there was.
 *
 * <p>Cells are seeded straight through {@link WeatherCellRepository#upsertDemand}, as the planner
 * would: no ride is needed to exercise the worker.
 */
@QuarkusTest
class WeatherFetchWorkerTest extends AbstractBaseTest {

  /** Slack for timestamps written by the worker's own clock. */
  private static final Duration CLOCK = Duration.ofSeconds(30);

  @InjectMock OpenMeteoGateway gateway;
  @InjectMock OpenMeteoCircuitBreaker breaker;

  @Inject WeatherFetchWorker worker;
  @Inject WeatherCellRepository cellRepository;
  @Inject WeatherHourlyRepository hourlyRepository;
  @Inject WeatherDailyRepository dailyRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    when(breaker.isClosed(any())).thenReturn(true);
    when(breaker.remainingBudget(any())).thenReturn(1_000);
    answerWith(location -> WeatherTestFixtures.forecast(location));
  }

  private void answerWith(
      Function<Location, fr.pedalons.infrastructure.openmeteo.OpenMeteoForecast> answer) {
    // doAnswer, not when(...): when() would call forecast() on a mock a test may have stubbed to
    // throw, and that throw would escape here.
    doAnswer(
            invocation -> {
              List<Location> locations = invocation.getArgument(0);
              return locations.stream().map(answer).toList();
            })
        .when(gateway)
        .forecast(anyList());
  }

  /** A cell due now, whose nearest passage is {@code need} from now. */
  private CellKey seedDue(double lat, double lon, @Nullable Double elevation, Duration need) {
    CellKey key = elevation == null ? CellKey.of(lat, lon) : CellKey.of(lat, lon, elevation);
    Instant now = Instant.now().minusSeconds(60);
    QuarkusTransaction.requiringNew()
        .run(() ->
            cellRepository.upsertDemand(
                key.latIdx(),
                key.lonIdx(),
                key.eleBand(),
                key.centerLat(),
                key.centerLon(),
                now.plus(need),
                WeatherRefreshPolicy.ttl(now.plus(need), now),
                now));
    return key;
  }

  private List<WeatherCell> cells() {
    return QuarkusTransaction.requiringNew().call(() -> cellRepository.listAll());
  }

  private WeatherCell cell(CellKey key) {
    WeatherCell cell =
        QuarkusTransaction.requiringNew().call(() -> WeatherTestFixtures.cell(cellRepository, key));
    assertNotNull(cell, "cell " + key);
    return cell;
  }

  private long hourRows() {
    return QuarkusTransaction.requiringNew().call(() -> hourlyRepository.count());
  }

  private long dayRows() {
    return QuarkusTransaction.requiringNew().call(() -> dailyRepository.count());
  }

  private void makeAllDue() {
    QuarkusTransaction.requiringNew()
        .run(() -> cellRepository.update("nextRefreshAt = ?1", Instant.now().minusSeconds(1)));
  }

  private static void assertAround(Instant expected, Instant actual) {
    assertTrue(
        Duration.between(expected, actual).abs().compareTo(CLOCK) <= 0,
        "expected about " + expected + ", was " + actual);
  }

  // --- claim ------------------------------------------------------------------------------------

  @Test
  void claim_shouldLeaseTheCells_soASecondWorkerSkipsThemUntilTheLeaseEnds() {
    seedDue(45.76, 4.83, null, Duration.ofHours(2));
    seedDue(45.86, 4.83, null, Duration.ofHours(3));
    seedDue(45.96, 4.83, null, Duration.ofHours(4));

    Instant now = Instant.now();
    List<Claimed> first = worker.claim(10, now);

    assertEquals(3, first.size());
    for (WeatherCell cell : cells()) {
      assertNotNull(cell.getClaimedUntil());
      assertAround(now.plus(WeatherFetchWorker.LEASE), cell.getClaimedUntil());
    }
    // A second backend of a rolling deploy, a second later: nothing for it.
    assertTrue(worker.claim(10, now.plusSeconds(1)).isEmpty());
    // A worker that died leaves its lease to expire: the cells are due again after it.
    assertEquals(3, worker.claim(10, now.plus(WeatherFetchWorker.LEASE).plusSeconds(1)).size());
  }

  @Test
  void claim_shouldTakeTheNearestPassageFirst_withinTheLimit() {
    CellKey far = seedDue(45.76, 4.83, null, Duration.ofDays(3));
    CellKey soon = seedDue(45.86, 4.83, null, Duration.ofHours(2));
    CellKey tomorrow = seedDue(45.96, 4.83, null, Duration.ofDays(1));

    List<Claimed> claimed = worker.claim(2, Instant.now());

    assertEquals(
        Set.of(cell(soon).getId(), cell(tomorrow).getId()),
        claimed.stream().map(Claimed::id).collect(Collectors.toSet()));
    assertNull(cell(far).getClaimedUntil());
  }

  /**
   * A cell the planner last asked for at {@code demandedAt}, for a passage at {@code need}, due
   * since then — what a ride leaves behind once it has gone by, or was deleted, cancelled or moved.
   */
  private CellKey seedOrphan(double lat, double lon, Instant demandedAt, Instant need) {
    CellKey key = CellKey.of(lat, lon);
    QuarkusTransaction.requiringNew()
        .run(() ->
            cellRepository.upsertDemand(
                key.latIdx(),
                key.lonIdx(),
                key.eleBand(),
                key.centerLat(),
                key.centerLon(),
                need,
                WeatherRefreshPolicy.ttl(need, demandedAt),
                demandedAt));
    return key;
  }

  @Test
  void claim_aCellNoPlanningPassAskedForLately_shouldNotBeClaimed() {
    Instant now = Instant.now();
    // Its ride left the planner's window an hour ago — deleted, cancelled, moved: still a passage
    // ahead on record, but nobody wants it any more.
    CellKey orphan =
        seedOrphan(
            45.76,
            4.83,
            now.minus(WeatherFetchWorker.DEMAND_FRESHNESS).minus(Duration.ofMinutes(1)),
            now.plus(Duration.ofHours(5)));
    CellKey wanted = seedDue(45.86, 4.83, null, Duration.ofHours(2));

    List<Claimed> claimed = worker.claim(10, now);

    assertEquals(List.of(cell(wanted).getId()), claimed.stream().map(Claimed::id).toList());
    assertNull(cell(orphan).getClaimedUntil());
  }

  @Test
  void claim_aCellWhosePassageIsBehindUs_shouldNotBeClaimed_evenAtTheHeadOfTheQueue() {
    Instant now = Instant.now();
    // Planned a minute ago for a ride that has left since: its passage is the nearest of all, so
    // it would come first, every hour, until the nightly purge.
    CellKey gone = seedOrphan(45.76, 4.83, now.minus(Duration.ofMinutes(1)), now.minusSeconds(10));
    CellKey wanted = seedDue(45.86, 4.83, null, Duration.ofDays(3));

    List<Claimed> claimed = worker.claim(1, now);

    assertEquals(List.of(cell(wanted).getId()), claimed.stream().map(Claimed::id).toList());
    assertNull(cell(gone).getClaimedUntil());
  }

  @Test
  void fetchDue_shouldNeverAskForAnOrphanCell() {
    Instant now = Instant.now();
    seedOrphan(45.76, 4.83, now.minus(Duration.ofHours(3)), now.minus(Duration.ofHours(2)));

    assertEquals(0, worker.fetchDue());

    verify(gateway, never()).forecast(anyList());
  }

  @Test
  void claim_shouldLeaveCellsNotDueYet() {
    seedDue(45.76, 4.83, null, Duration.ofHours(2));
    worker.fetchDue();

    assertTrue(worker.claim(10, Instant.now()).isEmpty());
  }

  // --- success ----------------------------------------------------------------------------------

  @Test
  void fetchDue_shouldStoreTheForecast_releaseTheLease_andScheduleTheNextRefresh() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));

    Instant before = Instant.now();
    int stored = worker.fetchDue();

    assertEquals(1, stored);
    assertEquals(48, hourRows());
    assertEquals(4, dayRows());
    WeatherCell cell = cell(key);
    assertNotNull(cell.getFetchedAt());
    assertFalse(cell.getFetchedAt().isBefore(before.minus(CLOCK)));
    assertEquals(0, cell.getAttempts());
    assertNull(cell.getLastError());
    assertNull(cell.getClaimedUntil());
    assertEquals("Europe/Paris", cell.getTimezone());
    assertEquals(180.0, cell.getGridElevation());
    // A passage two hours away: refreshed hourly.
    assertAround(cell.getFetchedAt().plus(Duration.ofHours(1)), cell.getNextRefreshAt());
    verify(breaker).recordCalls(eq(1), any());
    verify(breaker).recordSuccess();
  }

  @Test
  void fetchDue_shouldAskTheCentreOfTheCell_neverTheMeetingPoint() {
    CellKey key = seedDue(45.7578, 4.8320, null, Duration.ofHours(2));
    @SuppressWarnings("unchecked")
    ArgumentCaptor<List<Location>> asked = ArgumentCaptor.forClass(List.class);

    worker.fetchDue();

    verify(gateway).forecast(asked.capture());
    Location location = asked.getValue().getFirst();
    assertEquals(key.centerLat(), location.latitude(), 1e-9);
    assertEquals(key.centerLon(), location.longitude(), 1e-9);
    assertNull(location.elevation());
  }

  @Test
  void fetchDue_shouldAskCellsWithAndWithoutElevationInSeparateRequests() {
    seedDue(45.76, 4.83, null, Duration.ofHours(2));
    seedDue(45.86, 4.83, 312.0, Duration.ofHours(2));
    seedDue(45.96, 4.83, 487.0, Duration.ofHours(2));
    @SuppressWarnings("unchecked")
    ArgumentCaptor<List<Location>> asked = ArgumentCaptor.forClass(List.class);

    int stored = worker.fetchDue();

    assertEquals(3, stored);
    verify(gateway, times(2)).forecast(asked.capture());
    Map<Boolean, Long> requests =
        asked.getAllValues().stream()
            .collect(
                Collectors.partitioningBy(
                    request -> request.getFirst().elevation() != null, Collectors.counting()));
    assertEquals(1, requests.get(true));
    assertEquals(1, requests.get(false));
    for (List<Location> request : asked.getAllValues()) {
      boolean withElevation = request.getFirst().elevation() != null;
      assertTrue(request.stream().allMatch(l -> (l.elevation() != null) == withElevation));
    }
    // The band, not the point's own altitude, is what the provider is asked about.
    assertTrue(
        asked.getAllValues().stream()
            .flatMap(List::stream)
            .filter(l -> l.elevation() != null)
            .allMatch(l -> l.elevation() == 300.0 || l.elevation() == 500.0));
  }

  @Test
  void fetchDue_twice_shouldRewriteTheRowsNotDuplicateThem() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    Instant start = Instant.now().truncatedTo(ChronoUnit.HOURS).minus(Duration.ofHours(2));
    LocalDate today = LocalDate.now(ZoneOffset.UTC);
    answerWith(location -> WeatherTestFixtures.forecast(location, start, today, 48, 15, 0));
    worker.fetchDue();
    long hours = hourRows();
    long days = dayRows();
    assertEquals(48, hours);

    makeAllDue();
    answerWith(location -> WeatherTestFixtures.forecast(location, start, today, 48, 21, 90));
    int stored = worker.fetchDue();

    assertEquals(1, stored);
    assertEquals(hours, hourRows());
    assertEquals(days, dayRows());
    long cellId = cell(key).getId();
    List<WeatherHourly> rows =
        QuarkusTransaction.requiringNew().call(() -> hourlyRepository.list("cellId = ?1", cellId));
    assertTrue(rows.stream().allMatch(r -> r.getTemperature() == 21 && r.getWindDirection() == 90));
  }

  // --- failure ----------------------------------------------------------------------------------

  @Test
  void fetchDue_whenTheProviderFails_shouldKeepTheForecastAndBackOffFiveMinutes() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    worker.fetchDue();
    Instant firstFetch = cell(key).getFetchedAt();
    long hours = hourRows();
    long days = dayRows();

    makeAllDue();
    doThrow(new OpenMeteoException("Open-Meteo answered 502: Bad Gateway", false))
        .when(gateway)
        .forecast(anyList());
    Instant failedAt = Instant.now();
    int stored = worker.fetchDue();

    assertEquals(0, stored);
    WeatherCell cell = cell(key);
    // Nothing deleted: the reader serves this forecast as STALE meanwhile.
    assertEquals(hours, hourRows());
    assertEquals(days, dayRows());
    assertEquals(firstFetch, cell.getFetchedAt());
    assertEquals(1, cell.getAttempts());
    assertEquals("Open-Meteo answered 502: Bad Gateway", cell.getLastError());
    assertNull(cell.getClaimedUntil());
    assertAround(failedAt.plus(Duration.ofMinutes(5)), cell.getNextRefreshAt());
    verify(breaker).recordFailure(any());
    verify(breaker, never()).recordRateLimited(any());
  }

  @Test
  void backoff_shouldDoubleWithEachFailure_upToAnHour() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    doThrow(new OpenMeteoException("Open-Meteo answered 503", false))
        .when(gateway)
        .forecast(anyList());

    Instant first = Instant.now();
    worker.fetchDue();
    assertAround(first.plus(Duration.ofMinutes(5)), cell(key).getNextRefreshAt());

    makeAllDue();
    Instant second = Instant.now();
    worker.fetchDue();
    assertEquals(2, cell(key).getAttempts());
    assertAround(second.plus(Duration.ofMinutes(10)), cell(key).getNextRefreshAt());

    makeAllDue();
    QuarkusTransaction.requiringNew().run(() -> cellRepository.update("attempts = ?1", 10));
    Instant later = Instant.now();
    worker.fetchDue();
    assertEquals(11, cell(key).getAttempts());
    assertAround(later.plus(Duration.ofHours(1)), cell(key).getNextRefreshAt());
  }

  @Test
  void aSuccessAfterFailures_shouldForgetTheBackoff() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    doThrow(new OpenMeteoException("Open-Meteo answered 503", false))
        .when(gateway)
        .forecast(anyList());
    worker.fetchDue();
    assertEquals(1, cell(key).getAttempts());

    makeAllDue();
    answerWith(location -> WeatherTestFixtures.forecast(location));
    worker.fetchDue();

    WeatherCell cell = cell(key);
    assertEquals(0, cell.getAttempts());
    assertNull(cell.getLastError());
    assertNotNull(cell.getFetchedAt());
  }

  @Test
  void planningDuringABackoff_shouldNotCutItShort() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    doThrow(new OpenMeteoException("Open-Meteo answered 503", false))
        .when(gateway)
        .forecast(anyList());
    worker.fetchDue();
    Instant backoff = cell(key).getNextRefreshAt();

    // The planner's next tick, five minutes on, still wants the cell.
    seedDue(45.76, 4.83, null, Duration.ofHours(2));

    assertEquals(backoff, cell(key).getNextRefreshAt());
    assertEquals(1, cell(key).getAttempts());
  }

  @Test
  void fetchDue_whenRateLimited_shouldKeepTheForecastAndWaitForTheNextFullHour() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    worker.fetchDue();
    long hours = hourRows();

    makeAllDue();
    doThrow(new OpenMeteoException("Open-Meteo rate limit (429): limit exceeded", true))
        .when(gateway)
        .forecast(anyList());
    Instant nextHour = WeatherRefreshPolicy.retryAfterRateLimit(Instant.now());
    worker.fetchDue();

    WeatherCell cell = cell(key);
    assertEquals(hours, hourRows());
    assertNotNull(cell.getFetchedAt());
    assertFalse(cell.getNextRefreshAt().isBefore(nextHour), cell.getNextRefreshAt().toString());
    assertNull(cell.getClaimedUntil());
    verify(breaker).recordRateLimited(any());
    verify(breaker, never()).recordFailure(any());
  }

  @Test
  void fetchDue_anUnexpectedError_shouldBackOffWithARedactedMessage() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    doThrow(
            new IllegalStateException(
                "boom at https://customer-api.open-meteo.com/v1/forecast?apikey=SECRET-KEY"))
        .when(gateway)
        .forecast(anyList());

    worker.fetchDue();

    WeatherCell cell = cell(key);
    assertEquals(1, cell.getAttempts());
    assertNotNull(cell.getLastError());
    assertFalse(cell.getLastError().contains("SECRET-KEY"), cell.getLastError());
    assertTrue(cell.getLastError().startsWith("IllegalStateException"), cell.getLastError());
  }

  // --- breaker and budget -----------------------------------------------------------------------

  @Test
  void fetchDue_withTheBreakerOpen_shouldNeitherClaimNorCall() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    when(breaker.isClosed(any())).thenReturn(false);

    assertEquals(0, worker.fetchDue());

    verify(gateway, never()).forecast(anyList());
    WeatherCell cell = cell(key);
    assertNull(cell.getClaimedUntil());
    assertEquals(0, cell.getAttempts());
  }

  @Test
  void fetchDue_whenTheBreakerOpensAfterTheClaim_shouldGiveTheCellsBack() {
    CellKey key = seedDue(45.76, 4.83, null, Duration.ofHours(2));
    // Closed for the round, open by the time the request would go.
    when(breaker.isClosed(any())).thenReturn(true, false);

    assertEquals(0, worker.fetchDue());

    verify(gateway, never()).forecast(anyList());
    WeatherCell cell = cell(key);
    assertNull(cell.getClaimedUntil());
    assertEquals(0, cell.getAttempts(), "released, not counted as a failure");
  }

  @Test
  void fetchDue_withTheBudgetSpent_shouldNotCall() {
    seedDue(45.76, 4.83, null, Duration.ofHours(2));
    when(breaker.remainingBudget(any())).thenReturn(0);

    assertEquals(0, worker.fetchDue());

    verify(gateway, never()).forecast(anyList());
    verify(breaker, never()).recordCalls(anyInt(), any());
  }

  @Test
  void fetchDue_shouldAskNoMoreLocationsThanTheBudgetLeft() {
    seedDue(45.76, 4.83, null, Duration.ofHours(2));
    seedDue(45.86, 4.83, null, Duration.ofHours(3));
    seedDue(45.96, 4.83, null, Duration.ofHours(4));
    when(breaker.remainingBudget(any())).thenReturn(2, 0);

    assertEquals(2, worker.fetchDue());

    verify(breaker).recordCalls(eq(2), any());
    assertEquals(1, cells().stream().filter(c -> c.getFetchedAt() == null).count());
  }
}
