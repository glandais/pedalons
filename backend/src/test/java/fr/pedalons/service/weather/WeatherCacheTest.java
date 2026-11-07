package fr.pedalons.service.weather;

import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.weather.WeatherCell;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WeatherStatus;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoCircuitBreaker;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoException;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoForecast;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository.RideWindowHour;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The weather cache end to end, the provider mocked: planning a ride's cells, fetching them,
 * reading them back for the detail and the list — and what a provider failure leaves behind.
 */
@QuarkusTest
class WeatherCacheTest extends AbstractResourceTest {

  @InjectMock OpenMeteoGateway gateway;
  @InjectMock OpenMeteoCircuitBreaker breaker;

  @Inject WeatherPlanner planner;
  @Inject WeatherFetchWorker worker;
  @Inject WeatherHousekeeping housekeeping;
  @Inject RideWeatherService rideWeatherService;
  @Inject RideWeatherLookup rideWeatherLookup;
  @Inject WeatherCellRepository cellRepository;
  @Inject WeatherHourlyRepository hourlyRepository;
  @Inject RideRepository rideRepository;
  @Inject PlaceRepository placeRepository;

  private Ride ride;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    when(breaker.isClosed(any())).thenReturn(true);
    when(breaker.remainingBudget(any())).thenReturn(1_000);
    when(gateway.forecast(anyList()))
        .thenAnswer(
            invocation -> {
              List<Location> locations = invocation.getArgument(0);
              return locations.stream().map(WeatherCacheTest::forecast).toList();
            });

    // Tomorrow, 30 km due north from Lyon, meeting point at the start.
    Instant tomorrow = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.HOURS);
    Route route =
        dataService.createRouteWithTracks(
            team1, user1, "Vers le nord", Visibility.PUBLIC, List.of(northbound(30)));
    ride = dataService.createRide(team1, user1, "Sortie", "sortie", tomorrow);
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Place place = new Place(user1, team1, "Bellecour", true, true);
              place.setGeometry(point(WGS84, g(4.8320, 45.7578)));
              placeRepository.persist(place);
              Ride managed = rideRepository.findById(ride.getId());
              managed.setStart(place);
              managed.setRoute(rideRepository.getEntityManager().find(Route.class, route.getId()));
            });
  }

  private static List<TrackPoint> northbound(double km) {
    List<TrackPoint> points = new ArrayList<>();
    for (int i = 0; i <= km * 10; i++) {
      double d = i * 100.0;
      points.add(new TrackPoint(45.7578 + d / 111_195, 4.8320, 170 + i * 0.1, d));
    }
    return points;
  }

  /** 48 hours of mild weather with a northerly, from two hours ago. */
  private static OpenMeteoForecast forecast(Location location) {
    Instant start = Instant.now().truncatedTo(ChronoUnit.HOURS).minus(Duration.ofHours(2));
    List<OpenMeteoForecast.Hour> hours = new ArrayList<>();
    for (int h = 0; h < 48; h++) {
      hours.add(
          new OpenMeteoForecast.Hour(
              start.plus(Duration.ofHours(h)), 15, 14, 10, 0, 2, 20, 0, 35.0));
    }
    LocalDate today = LocalDate.now(ZoneOffset.UTC);
    List<OpenMeteoForecast.Day> days = new ArrayList<>();
    for (int d = -1; d < 3; d++) {
      LocalDate date = today.plusDays(d);
      days.add(
          new OpenMeteoForecast.Day(
              date,
              date.atTime(5, 0).toInstant(ZoneOffset.UTC),
              date.atTime(18, 0).toInstant(ZoneOffset.UTC)));
    }
    return new OpenMeteoForecast(
        location.latitude(),
        location.longitude(),
        location.elevation(),
        "Europe/Paris",
        hours,
        days);
  }

  private List<WeatherCell> cells() {
    return QuarkusTransaction.requiringNew().call(() -> cellRepository.listAll());
  }

  @Test
  void plan_shouldUpsertOneCellPerPlace_evenWithoutElevation() {
    int planned = planner.plan(Instant.now());
    int again = planner.plan(Instant.now());

    // The departure (no band) and the three route samples — the start sample shares the
    // departure's 5 km cell but not its (null) elevation band.
    assertEquals(planned, again);
    List<WeatherCell> cells = cells();
    assertEquals(planned, cells.size());
    assertEquals(1, cells.stream().filter(c -> c.getEleBand() == null).count());
    assertTrue(cells.stream().allMatch(c -> c.getFetchedAt() == null));
  }

  @Test
  void fetchDue_shouldStoreEveryCellAndServeTheDetailAndTheList() {
    planner.plan(Instant.now());

    int stored = worker.fetchDue();

    assertEquals(cells().size(), stored);
    assertTrue(cells().stream().allMatch(c -> c.getFetchedAt() != null && c.getAttempts() == 0));
    assertTrue(cells().stream().allMatch(c -> c.getNextRefreshAt().isAfter(Instant.now())));

    RideWeather weather =
        QuarkusTransaction.requiringNew()
            .call(() -> rideWeatherService.forRide(rideRepository.findById(ride.getId())));
    assertEquals(WeatherStatus.OK, weather.status());
    assertEquals(WeatherStatus.OK, weather.departure().status());
    assertNotNull(weather.departure().conditions());
    assertEquals(1, weather.legs().size());
    WeatherLeg leg = weather.legs().getFirst();
    assertNull(leg.groupId());
    assertTrue(leg.speedIsDefault());
    assertEquals(3, leg.checkpoints().size()); // 0, 15, 30 km
    assertTrue(leg.checkpoints().stream().allMatch(c -> c.weather() != null));
    assertEquals(30_000, leg.windExposure().head(), 1); // due north into a northerly

    RideWeatherSummaries summaries =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  List<Ride> rides = List.of(rideRepository.findById(ride.getId()));
                  return rideWeatherLookup.forRides(rides);
                });
    RideWeatherSummary summary = summaries.forRide(ride.getId());
    assertNotNull(summary);
    assertEquals(WeatherStatus.OK, summary.status());
    assertEquals(15, summary.temperature());
  }

  @Test
  void forRides_shouldCostOneStatementForAPage() {
    planner.plan(Instant.now());
    worker.fetchDue();

    long statements =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  List<Ride> rides = List.of(rideRepository.findById(ride.getId()));
                  return queryStats.measure(
                      "weather summaries [1 ride]", () -> rideWeatherLookup.forRides(rides));
                });

    assertEquals(1, statements);
  }

  /**
   * The list's SQL and the detail start a group from the same instant (docs/LEDGER_*.md API-60): its
   * stored start_at — the ride being in Tokyo, while the departure cell's zone is Paris, which dates
   * only its daily rows.
   */
  @Test
  void forRides_aTimedGroup_startsWhereTheDetailStartsIt() {
    ZoneId tokyo = ZoneId.of("Asia/Tokyo");
    Instant departure = ride.getDateTime();
    RideGroup group = dataService.createRideGroup(user1, ride, "Groupe");
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Ride managed = rideRepository.findById(ride.getId());
              managed.setTimezone(tokyo.getId());
              // The list reads the route's stored length; the detail, its samples (30 km).
              managed.getRoute().setDistance(30_000f);
              RideGroup g = rideRepository.getEntityManager().find(RideGroup.class, group.getId());
              // It leaves with the ride.
              g.setAverageSpeed(30f);
            });
    planner.plan(Instant.now());
    worker.fetchDue();

    // 30 km at 30 km/h from the ride's own instant: Paris would have read it 7 hours off.
    assertEquals(departure.plus(Duration.ofHours(1)), listLastArrival());
    assertEquals(departure.plus(Duration.ofHours(1)), detailArrival(group.getId()));

    // Its own start, three hours later, in both.
    Instant stored = departure.plus(Duration.ofHours(3));
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                rideRepository
                    .getEntityManager()
                    .find(RideGroup.class, group.getId())
                    .setStartAt(stored));
    assertEquals(stored.plus(Duration.ofHours(1)), listLastArrival());
    assertEquals(stored.plus(Duration.ofHours(1)), detailArrival(group.getId()));
  }

  private Instant listLastArrival() {
    List<RideWindowHour> hours =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    hourlyRepository.findRideWindowHours(
                        List.of(ride.getId()),
                        CellKey.SQL_LAT_IDX,
                        CellKey.SQL_LON_IDX,
                        RideWeatherCalculator.DEFAULT_SPEED_KMH,
                        RideWeatherLookup.SLACK));
    assertTrue(!hours.isEmpty());
    return hours.getFirst().lastArrival();
  }

  private Instant detailArrival(Long groupId) {
    RideWeather weather =
        QuarkusTransaction.requiringNew()
            .call(() -> rideWeatherService.forRide(rideRepository.findById(ride.getId())));
    return weather.legs().stream()
        .filter(leg -> groupId.equals(leg.groupId()))
        .findFirst()
        .orElseThrow()
        .arrivalTime();
  }

  @Test
  void forRides_withNoRideInTheWindow_shouldCostNothing() {
    Ride far =
        dataService.createRide(
            team1, user1, "Loin", "loin", Instant.now().plus(10, ChronoUnit.DAYS));

    long[] statements = new long[1];
    RideWeatherSummaries summaries =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  List<Ride> rides = List.of(rideRepository.findById(far.getId()));
                  RideWeatherSummaries[] out = new RideWeatherSummaries[1];
                  statements[0] =
                      queryStats.measure(
                          "weather summaries [far ride]",
                          () -> out[0] = rideWeatherLookup.forRides(rides));
                  return out[0];
                });

    assertEquals(0, statements[0]);
    // No place, no route: nothing to promise either.
    assertNull(summaries.forRide(far.getId()));
  }

  @Test
  void fetchDue_whenTheProviderFails_shouldBackOffAndKeepTheCache() {
    planner.plan(Instant.now());
    worker.fetchDue();
    Instant firstFetch = cells().getFirst().getFetchedAt();
    QuarkusTransaction.requiringNew()
        .run(() -> cellRepository.update("nextRefreshAt = ?1", Instant.now().minusSeconds(1)));
    doThrow(new OpenMeteoException("Open-Meteo answered 502", false))
        .when(gateway)
        .forecast(anyList());

    int stored = worker.fetchDue();

    assertEquals(0, stored);
    for (WeatherCell cell : cells()) {
      assertEquals(1, cell.getAttempts());
      assertNotNull(cell.getLastError());
      assertNotNull(cell.getFetchedAt()); // the forecast is still there, served STALE later
      assertTrue(cell.getNextRefreshAt().isAfter(Instant.now().plus(Duration.ofMinutes(4))));
      assertNull(cell.getClaimedUntil());
    }
    assertNotNull(firstFetch);
    verify(breaker, never()).recordRateLimited(any());
  }

  @Test
  void fetchDue_whenRateLimited_shouldWaitForTheNextFullHour() {
    planner.plan(Instant.now());
    doThrow(new OpenMeteoException("429", true)).when(gateway).forecast(anyList());

    worker.fetchDue();

    Instant nextHour = Instant.now().truncatedTo(ChronoUnit.HOURS).plus(1, ChronoUnit.HOURS);
    assertTrue(cells().stream().allMatch(c -> !c.getNextRefreshAt().isBefore(nextHour)));
    verify(breaker, atLeastOnce()).recordRateLimited(any());
  }

  @Test
  void purge_shouldDropPastHoursAndForgottenCells() {
    planner.plan(Instant.now());
    worker.fetchDue();

    // Two days and a bit later, nobody planned anything since.
    housekeeping.purge(Instant.now().plus(Duration.ofDays(3)));

    assertTrue(cells().isEmpty());
    assertEquals(0, QuarkusTransaction.requiringNew().call(() -> hourlyRepository.count()));
  }

  // ------------------------------------------------------------------ GPX previews (API-149)

  @Inject fr.pedalons.repository.gpx.GpxPreviewRepository previewRepository;

  private fr.pedalons.domain.gpx.GpxPreview preview(Instant departure, Float speed) {
    return dataService.createGpxPreview(
        domain,
        user1,
        java.util.UUID.randomUUID(),
        northbound(30),
        1L,
        departure,
        "Europe/Paris",
        speed);
  }

  private RideWeather previewWeather(fr.pedalons.domain.gpx.GpxPreview preview) {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                rideWeatherService.forPreview(
                    previewRepository
                        .findWeatherRow(domain.getId(), preview.getPublicId())
                        .orElseThrow()));
  }

  @Test
  void forPreview_afterPlanAndFetch_isOk_withAndWithoutASpeed() {
    Instant departure = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    var withSpeed = preview(departure, 30f);
    var withoutSpeed = preview(departure.plus(1, ChronoUnit.HOURS), null);
    planner.plan(Instant.now());
    worker.fetchDue();

    RideWeather fast = previewWeather(withSpeed);
    RideWeather defaulted = previewWeather(withoutSpeed);

    // The planner asked for everything the read looks at: no checkpoint is left without weather
    for (RideWeather weather : List.of(fast, defaulted)) {
      assertEquals(WeatherStatus.OK, weather.status());
      assertEquals(1, weather.legs().size());
      assertNull(weather.legs().getFirst().groupId());
      assertEquals(3, weather.legs().getFirst().checkpoints().size());
      assertTrue(
          weather.legs().getFirst().checkpoints().stream().allMatch(c -> c.weather() != null));
    }
    assertEquals(30.0, fast.legs().getFirst().averageSpeed(), 1e-9);
    assertFalse(fast.legs().getFirst().speedIsDefault());
    assertEquals(25.0, defaulted.legs().getFirst().averageSpeed(), 1e-9);
    assertTrue(defaulted.legs().getFirst().speedIsDefault());
  }

  @Test
  void forPreview_aHotRead_costsThreeStatements_andNeverLoadsTheTracks() {
    var preview = preview(Instant.now().plus(1, ChronoUnit.DAYS), null);
    planner.plan(Instant.now());
    worker.fetchDue();
    previewWeather(preview); // warms the sample cache

    long statements =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  return queryStats.measure(
                      "preview weather [hot]",
                      () ->
                          rideWeatherService.forPreview(
                              previewRepository
                                  .findWeatherRow(domain.getId(), preview.getPublicId())
                                  .orElseThrow()));
                });

    // the projection, the cells, their hours: nothing for the tracks
    assertEquals(3, statements);
  }

  @Test
  void plan_theNumberOfStatements_doesNotDependOnTheNumberOfPreviews() {
    Instant departure = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    var first = preview(departure, null);
    previewWeather(first);
    planner.plan(Instant.now());
    long one = queryStats.counters().reads();
    planner.plan(Instant.now());
    long afterOne = queryStats.counters().reads() - one;

    for (int i = 0; i < 4; i++) {
      var more = preview(departure, 28f);
      previewWeather(more);
    }
    long before = queryStats.counters().reads();
    planner.plan(Instant.now());
    long afterFive = queryStats.counters().reads() - before;

    // The previews are one projection, then the cache: the same reads for five as for one
    assertEquals(afterOne, afterFive);
  }
}
