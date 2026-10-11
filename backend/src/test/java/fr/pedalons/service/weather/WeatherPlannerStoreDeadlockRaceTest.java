package fr.pedalons.service.weather;

import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.weather.WeatherCell;
import fr.pedalons.domain.weather.WeatherHourly;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoCircuitBreaker;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.weather.WeatherFetchWorker.Claimed;
import io.quarkus.arc.Arc;
import io.quarkus.arc.ManagedContext;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Bug: {@link WeatherPlanner#plan} and the store transaction of {@link
 * WeatherFetchWorker#fetchAndStore} lock the same {@code weather_cells} rows in opposite orders —
 * the planner in {@code HashMap} order of its demand (one {@code @Transactional} pass, each {@code
 * upsertDemand} holding its row until the end), the worker in the unordered order of {@code
 * list("id in ?1")} (one {@code requiringNew} for every {@code markFetched}). PostgreSQL detects
 * the deadlock and aborts one side; when it is the worker, the paid provider answer is thrown away
 * and {@code markFailed} puts every cell of the batch into backoff ({@code attempts = 1}).
 *
 * <p>Found by the TLA+/TLC model of the weather pipeline (planner pass vs. fetch worker store
 * transaction, row locks held to commit): the lock-order graph has a cycle, and the invariant
 * "a batch the provider answered ends stored" is violated by worker:lock(X), planner:lock(Y),
 * worker:wait(Y), planner:wait(X).
 *
 * <p>The interleaving is driven with real code on both sides, nothing timed:
 *
 * <ol>
 *   <li>A first planning pass reveals the planner's iteration order P1..Pn; the cells are then
 *       recreated in the reverse order, as a real worker's unordered claim can return them.
 *   <li>A gate transaction holds an uncommitted {@code weather_hourly} row of P1, so the worker's
 *       store blocks at P1's hourly upsert after locking (via {@code markFetched}) every cell it
 *       stores before P1. The gate only takes a KEY SHARE lock on P1's cell row, which the planner's
 *       upsert does not conflict with.
 *   <li>With the worker blocked, {@code plan()} runs: it locks P1 first, then waits for a cell the
 *       worker holds. After more than {@code deadlock_timeout} (so the planner's own deadlock check
 *       has passed harmlessly), the gate rolls back: the worker reaches P1's {@code markFetched},
 *       waits on the planner, and its own check finds the cycle — the worker is the victim.
 * </ol>
 *
 * <p>Today the store fails with a deadlock and every cell ends with {@code attempts = 1} and a
 * {@code store: ...} error. Once both sides take their locks in one canonical order (or the planner
 * commits each upsert on its own), P1 is either the worker's first cell — it holds nothing while it
 * waits — or the planner never holds a cell the worker still needs: no cycle, the batch is stored.
 */
@QuarkusTest
class WeatherPlannerStoreDeadlockRaceTest extends AbstractResourceTest {

  private static final ZoneId PARIS = ZoneId.of("Europe/Paris");

  /** Longer than PostgreSQL's default {@code deadlock_timeout} (1 s). */
  private static final long PAST_DEADLOCK_TIMEOUT_MS = 2_500;

  @InjectMock OpenMeteoGateway gateway;
  @InjectMock OpenMeteoCircuitBreaker breaker;

  @Inject WeatherPlanner planner;
  @Inject WeatherFetchWorker worker;
  @Inject WeatherCellRepository cellRepository;
  @Inject WeatherHourlyRepository hourlyRepository;
  @Inject RideRepository rideRepository;
  @Inject PlaceRepository placeRepository;
  @Inject DomainResolver domainResolver;

  /** A cell as the planner asked for it, to recreate it in another order. */
  private record Demand(
      int latIdx,
      int lonIdx,
      @Nullable Integer eleBand,
      double latitude,
      double longitude,
      Instant nearestNeedAt) {}

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(dataService.getOrCreateDefaultDomain());
    when(breaker.isClosed(any())).thenReturn(true);
    when(breaker.remainingBudget(any())).thenReturn(1_000);
    doAnswer(
            invocation -> {
              List<Location> locations = invocation.getArgument(0);
              return locations.stream().map(WeatherTestFixtures::forecast).toList();
            })
        .when(gateway)
        .forecast(anyList());
  }

  @Test
  void plannerAndStoreOnTheSameCells_shouldNotDeadlockAndLoseThePaidBatch() throws Exception {
    // Four rides tomorrow, meeting points 0.1° apart: four departure cells, no elevation band.
    Instant nine =
        LocalDate.now(PARIS).plusDays(1).atTime(LocalTime.of(9, 0)).atZone(PARIS).toInstant();
    for (int i = 0; i < 4; i++) {
      Ride ride =
          dataService.createRide(
              team1, user1, "Ride " + i, "ride-" + i, nine, Visibility.PUBLIC, Status.PUBLISHED);
      locate(ride, 44.0 + i * 0.1, 4.0);
    }

    // 1. The planner's lock order: a first pass inserts the cells in its iteration order, which
    //    TSIDs (monotonic) record.
    assertEquals(4, planner.plan(Instant.now()));
    List<Demand> plannerOrder =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    cellRepository.listAll().stream()
                        .sorted(Comparator.comparing(WeatherCell::getId))
                        .map(
                            c ->
                                new Demand(
                                    c.getLatIdx(),
                                    c.getLonIdx(),
                                    c.getEleBand(),
                                    c.getLatitude(),
                                    c.getLongitude(),
                                    Objects.requireNonNull(c.getNearestNeedAt())))
                        .toList());
    assertEquals(4, plannerOrder.size());
    Demand first = plannerOrder.getFirst();

    // Recreate the cells in the reverse order: a worker's claim (no ORDER BY) returns them so.
    Instant seededAt = Instant.now().minusSeconds(60);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              cellRepository.deleteAll();
              for (Demand d : plannerOrder.reversed()) {
                cellRepository.upsertDemand(
                    d.latIdx(),
                    d.lonIdx(),
                    d.eleBand(),
                    d.latitude(),
                    d.longitude(),
                    d.nearestNeedAt(),
                    WeatherRefreshPolicy.ttl(d.nearestNeedAt(), seededAt),
                    seededAt);
              }
            });

    List<Claimed> claimed = worker.claim(100, Instant.now());
    assertEquals(4, claimed.size(), "every planned cell is due");
    long gateCellId =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    cellRepository
                        .find("latIdx = ?1 and lonIdx = ?2", first.latIdx(), first.lonIdx())
                        .firstResultOptional()
                        .orElseThrow()
                        .getId());

    // 2. The gate: an uncommitted forecast hour of the planner's first cell, an hour the
    //    provider's answer also carries.
    CountDownLatch gateHeld = new CountDownLatch(1);
    CountDownLatch releaseGate = new CountDownLatch(1);
    Instant gateHour = Instant.now().truncatedTo(ChronoUnit.HOURS).plus(Duration.ofHours(10));
    CompletableFuture<Void> gate =
        CompletableFuture.runAsync(
            () ->
                inRequest(
                    () -> {
                      try {
                        QuarkusTransaction.requiringNew()
                            .run(
                                () -> {
                                  hourlyRepository.upsert(
                                      gateCellId, List.of(hour(gateCellId, gateHour)));
                                  hourlyRepository.flush();
                                  gateHeld.countDown();
                                  await(releaseGate);
                                  throw new GateRollback();
                                });
                      } catch (RuntimeException expected) {
                        // GateRollback, possibly wrapped: rolled back, so the worker's upsert of
                        // that hour goes through
                      } finally {
                        gateHeld.countDown();
                      }
                    }));
    assertTrue(gateHeld.await(30, TimeUnit.SECONDS), "gate not held");

    // The worker stores the batch and blocks at the gate cell's hourly upsert.
    CompletableFuture<Integer> stored =
        CompletableFuture.supplyAsync(() -> inRequest(() -> worker.fetchAndStore(claimed)));
    waitForLockWaiters(1, stored);

    // 3. The planner's next pass, on the same cells, while the worker holds what it stored so far.
    CompletableFuture<Integer> planned =
        CompletableFuture.supplyAsync(() -> inRequest(() -> planner.plan(Instant.now())));
    waitForLockWaiters(2, planned);
    // Let the planner's own deadlock check run (and find nothing yet), so that the check which
    // finds the cycle is the worker's — the case where a paid answer is lost.
    Thread.sleep(PAST_DEADLOCK_TIMEOUT_MS);
    releaseGate.countDown();
    gate.get(30, TimeUnit.SECONDS);

    assertEquals(4, planned.get(60, TimeUnit.SECONDS), "planning pass");
    int storedCells = stored.get(60, TimeUnit.SECONDS);

    List<WeatherCell> cells =
        QuarkusTransaction.requiringNew().call(() -> cellRepository.listAll());
    assertEquals(4, cells.size());
    for (WeatherCell cell : cells) {
      assertEquals(
          0,
          cell.getAttempts(),
          "cell " + cell.getId() + " put into backoff, last error: " + cell.getLastError());
      assertNull(cell.getLastError(), "cell " + cell.getId());
      assertNotNull(cell.getFetchedAt(), "cell " + cell.getId() + " never stored");
    }
    assertEquals(
        4, storedCells, "the provider answered for 4 cells, the store kept " + storedCells);
  }

  /**
   * Waits until {@code n} backends of this database wait on a lock — or until {@code task} is done,
   * which is how a correctly ordered side gets through without waiting.
   */
  private void waitForLockWaiters(int n, CompletableFuture<?> task) throws InterruptedException {
    long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(30);
    while (System.nanoTime() < deadline) {
      if (task.isDone()) {
        return;
      }
      long waiting =
          QuarkusTransaction.requiringNew()
              .call(
                  () ->
                      ((Number)
                              cellRepository
                                  .getEntityManager()
                                  .createNativeQuery(
                                      "select count(*) from pg_stat_activity"
                                          + " where datname = current_database()"
                                          + " and wait_event_type = 'Lock'")
                                  .getSingleResult())
                          .longValue());
      if (waiting >= n) {
        return;
      }
      Thread.sleep(20);
    }
    throw new AssertionError("never saw " + n + " backend(s) waiting on a lock");
  }

  private void locate(Ride ride, double lat, double lon) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Ride managed = rideRepository.findById(ride.getId());
              Place place = new Place(managed.getCreatedBy(), managed.getTeam(), "RDV", true, true);
              place.setGeometry(point(WGS84, g(lon, lat)));
              placeRepository.persist(place);
              managed.setStart(place);
            });
  }

  private static WeatherHourly hour(long cellId, Instant time) {
    WeatherHourly row = new WeatherHourly();
    row.setCellId(cellId);
    row.setTime(time);
    row.setTemperature(1);
    row.setApparentTemperature(0);
    row.setPrecipitationProbability(10);
    row.setPrecipitation(0);
    row.setWeatherCode(2);
    row.setWindSpeed(20);
    row.setWindDirection(0);
    row.setWindGusts(35.0);
    return row;
  }

  private static void await(CountDownLatch latch) {
    try {
      if (!latch.await(60, TimeUnit.SECONDS)) {
        throw new IllegalStateException("gate never released");
      }
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new IllegalStateException(e);
    }
  }

  private void inRequest(Runnable body) {
    inRequest(
        () -> {
          body.run();
          return null;
        });
  }

  private <T> T inRequest(Supplier<T> body) {
    ManagedContext requestContext = Arc.container().requestContext();
    requestContext.activate();
    try {
      domainResolver.setDomainForTest(dataService.getOrCreateDefaultDomain());
      return body.get();
    } finally {
      requestContext.terminate();
    }
  }

  /** Thrown to roll the gate transaction back. */
  private static final class GateRollback extends RuntimeException {}
}
