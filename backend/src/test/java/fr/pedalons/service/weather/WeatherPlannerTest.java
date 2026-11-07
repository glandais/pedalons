package fr.pedalons.service.weather;

import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.domain.weather.WeatherCell;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.trip.TripStageRepository;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import io.quarkus.narayana.jta.QuarkusTransaction;
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
import java.util.UUID;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@link WeatherPlanner}: which rides it plans, which cells it asks for and with what passage —
 * across every domain, since the cache is global — and that a replayed tick writes the same rows.
 * Never calls the provider: nothing is mocked because nothing would be called.
 */
@QuarkusTest
class WeatherPlannerTest extends AbstractResourceTest {

  private static final ZoneId PARIS = ZoneId.of("Europe/Paris");

  @Inject WeatherPlanner planner;
  @Inject WeatherCellRepository cellRepository;
  @Inject RideRepository rideRepository;
  @Inject PlaceRepository placeRepository;
  @Inject DomainResolver domainResolver;
  @Inject TripStageRepository tripStageRepository;
  @Inject GpxPreviewRepository previewRepository;

  /** A second tenant: its own domain, user and team. */
  private Domain otherDomain;

  private User otherUser;
  private Team otherTeam;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(dataService.getOrCreateDefaultDomain());
    otherDomain = dataService.createDomain("club.example", "Club", "https://club.example");
    otherUser = dataService.createUser(otherDomain, "rider@club.example", "Rider");
    otherTeam = dataService.createTeam(otherDomain, otherUser, "Club", "club", Visibility.PUBLIC);
  }

  /** Tomorrow at {@code time}, Paris time, to the second. */
  private static Instant tomorrowAt(LocalTime time) {
    return LocalDate.now(PARIS).plusDays(1).atTime(time).atZone(PARIS).toInstant();
  }

  private Ride ride(Team team, User user, String slug, Instant dateTime, Status status) {
    return dataService.createRide(
        team, user, "Ride " + slug, slug, dateTime, Visibility.PUBLIC, status);
  }

  /** Puts the ride's meeting point at ({@code lat}, {@code lon}), and its route if given. */
  private void locate(Ride ride, double lat, double lon, @Nullable Route route) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Ride managed = rideRepository.findById(ride.getId());
              Place place = new Place(managed.getCreatedBy(), managed.getTeam(), "RDV", true, true);
              place.setGeometry(point(WGS84, g(lon, lat)));
              placeRepository.persist(place);
              managed.setStart(place);
              if (route != null) {
                managed.setRoute(
                    rideRepository.getEntityManager().find(Route.class, route.getId()));
              }
            });
  }

  private void setGroup(RideGroup group, @Nullable LocalTime time, @Nullable Float averageSpeed) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              RideGroup managed =
                  rideRepository.getEntityManager().find(RideGroup.class, group.getId());
              Ride ride = managed.getRide();
              EventTimezoneResolver.setStart(managed, ride.getDateTime(), time, ride.zone());
              managed.setAverageSpeed(averageSpeed);
            });
  }

  private List<WeatherCell> cells() {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                cellRepository.listAll().stream()
                    .sorted(Comparator.comparing(WeatherCell::getId))
                    .toList());
  }

  private @Nullable WeatherCell cell(CellKey key) {
    return QuarkusTransaction.requiringNew()
        .call(() -> WeatherTestFixtures.cell(cellRepository, key));
  }

  @Test
  void plan_twoDomainsLeavingFromTheSamePlace_shouldShareOneCell() {
    Instant nine = tomorrowAt(LocalTime.of(9, 0));
    Ride here = ride(team1, user1, "here", nine, Status.PUBLISHED);
    Ride there =
        ride(otherTeam, otherUser, "there", nine.plus(Duration.ofHours(1)), Status.PUBLISHED);
    // Bellecour for one club, 300 m away for the other: the same 0.05° cell.
    locate(here, 45.7578, 4.8320, null);
    locate(there, 45.7600, 4.8350, null);

    Instant now = Instant.now();
    int planned = planner.plan(now);

    assertEquals(1, planned);
    List<WeatherCell> cells = cells();
    assertEquals(1, cells.size());
    WeatherCell cell = cells.getFirst();
    assertNull(cell.getEleBand());
    // The earlier of the two departures sets the refresh interval.
    assertEquals(nine, cell.getNearestNeedAt());
    // The provider is asked about the centre of the cell, never about either meeting point.
    CellKey key = CellKey.of(45.7578, 4.8320);
    assertEquals(key.centerLat(), cell.getLatitude(), 1e-9);
    assertEquals(key.centerLon(), cell.getLongitude(), 1e-9);
    // Never fetched: due at once.
    assertNull(cell.getFetchedAt());
    assertEquals(0, cell.getAttempts());
  }

  @Test
  void plan_twoDomainsInDifferentPlaces_shouldPlanBoth() {
    Instant nine = tomorrowAt(LocalTime.of(9, 0));
    locate(ride(team1, user1, "lyon", nine, Status.PUBLISHED), 45.7578, 4.8320, null);
    locate(ride(otherTeam, otherUser, "grenoble", nine, Status.PUBLISHED), 45.1885, 5.7245, null);

    assertEquals(2, planner.plan(Instant.now()));

    assertNotNull(cell(CellKey.of(45.7578, 4.8320)));
    assertNotNull(cell(CellKey.of(45.1885, 5.7245)));
  }

  @Test
  void plan_shouldOnlyPlanPublishedLiveRidesInTheWindow() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    // One cell per ride, 0.1° apart, so each one's presence says whether its ride was planned.
    Ride published =
        ride(team1, user1, "published", now.plus(Duration.ofDays(1)), Status.PUBLISHED);
    Ride underway =
        ride(team1, user1, "underway", now.minus(Duration.ofHours(2)), Status.PUBLISHED);
    Ride draft = ride(team1, user1, "draft", now.plus(Duration.ofDays(1)), Status.DRAFT);
    Ride cancelled =
        ride(team1, user1, "cancelled", now.plus(Duration.ofDays(1)), Status.CANCELLED);
    Ride deleted = ride(team1, user1, "deleted", now.plus(Duration.ofDays(1)), Status.PUBLISHED);
    Ride tooFar = ride(team1, user1, "too-far", now.plus(Duration.ofDays(8)), Status.PUBLISHED);
    Ride tooOld = ride(team1, user1, "too-old", now.minus(Duration.ofHours(13)), Status.PUBLISHED);
    Ride deletedTeam =
        ride(otherTeam, otherUser, "deleted-team", now.plus(Duration.ofDays(1)), Status.PUBLISHED);
    List<Ride> rides =
        List.of(published, underway, draft, cancelled, deleted, tooFar, tooOld, deletedTeam);
    for (int i = 0; i < rides.size(); i++) {
      locate(rides.get(i), 44.0 + i * 0.1, 4.0, null);
    }
    dataService.deleteRide(deleted);
    dataService.softDeleteTeam(otherTeam);

    assertEquals(1, planner.plan(now));

    assertNotNull(cell(CellKey.of(44.0, 4.0)), "published");
    // Already gone, even by two hours: OUT_OF_RANGE on the read side, so nothing to fetch for it.
    for (int i = 1; i < rides.size(); i++) {
      assertNull(cell(CellKey.of(44.0 + i * 0.1, 4.0)), rides.get(i).getSlug());
    }
  }

  /** The cells of a stage leaving tomorrow along 30 km due north of ({@code lat}, 4.0). */
  private TripStage routedStage(Trip trip, String name, double lat, Instant dateTime) {
    TripStage stage = dataService.createTripStage(user1, trip, name, 0);
    Route route =
        dataService.createRouteWithTracks(
            team1,
            user1,
            "Route " + name,
            Visibility.PUBLIC,
            List.of(WeatherTestFixtures.northbound(lat, 4.0, 30, 170)));
    dataService.setTripStageRoute(stage, route);
    QuarkusTransaction.requiringNew()
        .run(() -> tripStageRepository.findById(stage.getId()).setDateTime(dateTime));
    return stage;
  }

  private boolean plannedAround(double lat) {
    int latIdx = CellKey.of(lat, 4.0).latIdx();
    return cells().stream().anyMatch(c -> c.getLatIdx() == latIdx);
  }

  /** docs/LEDGER_*.md API-76: a trip's stages are planned as rides are, stage by stage. */
  @Test
  void plan_shouldPlanTheStagesOfPublishedTripsLeavingInTheWindow() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    Instant tomorrow = now.plus(Duration.ofDays(1));
    Trip published =
        dataService.createTrip(
            team1, user1, "Published trip", now, Visibility.PUBLIC, Status.PUBLISHED, null);
    Trip draft =
        dataService.createTrip(
            team1, user1, "Draft trip", now, Visibility.PUBLIC, Status.DRAFT, null);
    routedStage(published, "Trip tomorrow", 44.0, tomorrow);
    routedStage(published, "Trip gone", 45.0, now.minus(Duration.ofHours(2)));
    routedStage(published, "Trip too far", 46.0, now.plus(Duration.ofDays(8)));
    routedStage(draft, "Draft tomorrow", 47.0, tomorrow);

    assertTrue(planner.plan(now) > 0);

    assertTrue(plannedAround(44.0), "the published stage leaving tomorrow");
    assertFalse(plannedAround(45.0), "a stage already gone");
    assertFalse(plannedAround(46.0), "a stage beyond the horizon");
    assertFalse(plannedAround(47.0), "a stage of a draft trip");
  }

  @Test
  void plan_aRideWithoutAnyPlace_shouldPlanNothing() {
    ride(team1, user1, "nowhere", tomorrowAt(LocalTime.of(9, 0)), Status.PUBLISHED);

    assertEquals(0, planner.plan(Instant.now()));
    assertTrue(cells().isEmpty());
  }

  @Test
  void plan_replayed_shouldWriteTheSameRows() {
    Route route =
        dataService.createRouteWithTracks(
            team1,
            user1,
            "Nord",
            Visibility.PUBLIC,
            List.of(
                WeatherTestFixtures.northbound(
                    WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170)));
    Ride ride = ride(team1, user1, "replay", tomorrowAt(LocalTime.of(9, 0)), Status.PUBLISHED);
    locate(ride, WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, route);

    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    int first = planner.plan(now);
    List<WeatherCell> before = cells();
    int second = planner.plan(now);
    List<WeatherCell> after = cells();

    assertEquals(first, second);
    // The departure (no band) and the 0, 15 and 30 km samples (with one).
    assertEquals(4, first);
    assertEquals(before.size(), after.size());
    for (int i = 0; i < before.size(); i++) {
      WeatherCell a = before.get(i);
      WeatherCell b = after.get(i);
      assertEquals(a.getId(), b.getId());
      assertEquals(a.getNearestNeedAt(), b.getNearestNeedAt());
      assertEquals(a.getNextRefreshAt(), b.getNextRefreshAt());
      assertEquals(a.getLastDemandAt(), b.getLastDemandAt());
    }
  }

  @Test
  void plan_shouldTimeEachSampleWithItsGroupsTimeAndSpeed_theDefaultOnlyWhenNoneIsGiven() {
    List<TrackPoint> points =
        WeatherTestFixtures.northbound(
            WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170);
    Route route =
        dataService.createRouteWithTracks(team1, user1, "Nord", Visibility.PUBLIC, List.of(points));
    Instant nine = tomorrowAt(LocalTime.of(9, 0));
    Ride ride = ride(team1, user1, "groups", nine, Status.PUBLISHED);
    locate(ride, WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, route);
    // Fast: leaves at 10:00 local, 30 km/h → at 30 km at 11:00.
    RideGroup fast = dataService.createRideGroup(user1, ride, "Rapides", 0);
    setGroup(fast, LocalTime.of(10, 0), 30f);
    // No time, no speed: leaves with the ride at 09:00, 25 km/h → at 30 km at 10:12.
    dataService.createRideGroup(user1, ride, "Balade", 1);

    planner.plan(Instant.now());

    RouteSamples samples = RouteSampleLookup.sample(List.of(points), 15_000);
    WeatherCell finish = cell(samples.samples().getLast().cell());
    assertNotNull(finish);
    assertEquals(nine.plus(Duration.ofMinutes(72)), finish.getNearestNeedAt());
    WeatherCell start = cell(samples.samples().getFirst().cell());
    assertNotNull(start);
    assertEquals(nine, start.getNearestNeedAt());
  }

  @Test
  void plan_aGroupWithItsOwnTimeAndSpeed_shouldBeTimedWithThem() {
    List<TrackPoint> points =
        WeatherTestFixtures.northbound(
            WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170);
    Route route =
        dataService.createRouteWithTracks(team1, user1, "Nord", Visibility.PUBLIC, List.of(points));
    Instant nine = tomorrowAt(LocalTime.of(9, 0));
    Ride ride = ride(team1, user1, "one-group", nine, Status.PUBLISHED);
    locate(ride, WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, route);
    RideGroup group = dataService.createRideGroup(user1, ride, "Rapides", 0);
    setGroup(group, LocalTime.of(10, 0), 30f);

    planner.plan(Instant.now());

    RouteSamples samples = RouteSampleLookup.sample(List.of(points), 15_000);
    Instant ten = tomorrowAt(LocalTime.of(10, 0));
    WeatherCell middle = cell(samples.samples().get(1).cell());
    assertNotNull(middle);
    assertEquals(ten.plus(Duration.ofMinutes(30)), middle.getNearestNeedAt());
    WeatherCell finish = cell(samples.samples().getLast().cell());
    assertNotNull(finish);
    assertEquals(ten.plus(Duration.ofHours(1)), finish.getNearestNeedAt());
  }

  // ------------------------------------------------------------------ GPX previews (API-149)

  private GpxPreview datedPreview(
      Domain owner, User creator, double lat, @Nullable Instant departure, @Nullable Float speed) {
    return dataService.createGpxPreview(
        owner,
        creator,
        UUID.randomUUID(),
        WeatherTestFixtures.northbound(lat, 4.0, 30, 170),
        1L,
        departure,
        departure == null ? null : "Europe/Paris",
        speed);
  }

  @Test
  void plan_shouldPlanTheDatedPreviewsOfTheWindow_onEveryDomain() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    Instant tomorrow = now.plus(Duration.ofDays(1));
    datedPreview(domain, user1, 44.0, tomorrow, null);
    datedPreview(otherDomain, otherUser, 45.0, tomorrow, null);
    datedPreview(domain, user1, 46.0, null, 30f);
    datedPreview(domain, user1, 47.0, now.minus(Duration.ofHours(2)), null);
    datedPreview(domain, user1, 48.0, now.plus(Duration.ofDays(8)), null);

    assertTrue(planner.plan(now) > 0);

    assertTrue(plannedAround(44.0), "a preview of the first domain");
    assertTrue(plannedAround(45.0), "a preview of another domain");
    assertFalse(plannedAround(46.0), "no date");
    assertFalse(plannedAround(47.0), "a date past");
    assertFalse(plannedAround(48.0), "beyond the horizon");
  }

  @Test
  void plan_aPreviewOfADeletedDomain_isLeftOut() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    datedPreview(otherDomain, otherUser, 44.0, now.plus(Duration.ofDays(1)), null);
    dataService.deleteDomain(otherDomain);

    planner.plan(now);

    assertFalse(plannedAround(44.0));
  }

  @Test
  void plan_aPreviewTick_replayed_shouldWriteTheSameRows() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    datedPreview(domain, user1, 44.0, now.plus(Duration.ofDays(1)), 28f);

    int first = planner.plan(now);
    List<WeatherCell> before = cells();
    int second = planner.plan(now);
    List<WeatherCell> after = cells();

    assertEquals(first, second);
    // The start (no band) and the 0, 15 and 30 km samples (with one)
    assertEquals(4, first);
    assertEquals(before.size(), after.size());
    for (int i = 0; i < before.size(); i++) {
      assertEquals(before.get(i).getId(), after.get(i).getId());
      assertEquals(before.get(i).getNearestNeedAt(), after.get(i).getNearestNeedAt());
    }
  }

  @Test
  void plan_aPreview_shouldTimeItsSamplesWithItsSpeed_theDefaultOnlyWhenNoneIsGiven() {
    Instant departure = Instant.now().plus(Duration.ofDays(1)).truncatedTo(ChronoUnit.SECONDS);
    List<TrackPoint> points = WeatherTestFixtures.northbound(44.0, 4.0, 30, 170);
    GpxPreview fast = datedPreview(domain, user1, 44.0, departure, 30f);
    RouteSamples samples = RouteSampleLookup.sample(List.of(points), 15_000);
    CellKey finishCell = samples.samples().getLast().cell();

    planner.planPreview(fast.getId(), Instant.now());

    // 30 km at 30 km/h
    assertEquals(departure.plus(Duration.ofHours(1)), cell(finishCell).getNearestNeedAt());

    GpxPreview defaulted = datedPreview(domain, user1, 44.0, departure, null);
    QuarkusTransaction.requiringNew().run(() -> previewRepository.deleteById(fast.getId()));
    planner.planPreview(defaulted.getId(), Instant.now());

    // 30 km at the 25 km/h default: 72 minutes
    assertEquals(departure.plus(Duration.ofMinutes(72)), cell(finishCell).getNearestNeedAt());
  }

  @Test
  void planPreview_touchesOnlyThatPreview_andNothingOutsideTheWindow() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    GpxPreview mine = datedPreview(domain, user1, 44.0, now.plus(Duration.ofDays(1)), null);
    datedPreview(domain, user1, 45.0, now.plus(Duration.ofDays(1)), null);
    GpxPreview far = datedPreview(domain, user1, 46.0, now.plus(Duration.ofDays(9)), null);

    assertEquals(4, planner.planPreview(mine.getId(), now));

    assertTrue(plannedAround(44.0));
    assertFalse(plannedAround(45.0));
    assertEquals(0, planner.planPreview(far.getId(), now));
    assertFalse(plannedAround(46.0));
  }

  @Test
  void requestPreview_withTheWeatherOff_doesNothing_andNeverFails() {
    Instant now = Instant.now().plus(Duration.ofDays(1));
    GpxPreview preview = datedPreview(domain, user1, 44.0, now, null);

    planner.requestPreview(preview.getId());
    planner.requestPreview(-1L);

    assertTrue(cells().isEmpty());
  }

  @Test
  void plan_aNewRevision_asksForTheCellsOfTheNewGeometry() {
    Instant departure = Instant.now().plus(Duration.ofDays(1)).truncatedTo(ChronoUnit.SECONDS);
    GpxPreview preview = datedPreview(domain, user1, 44.0, departure, null);
    planner.plan(Instant.now());
    assertTrue(plannedAround(44.0));

    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxPreview managed = previewRepository.findById(preview.getId());
              managed.setTracks(
                  List.of(
                      new GpxPreview.PreviewTrack(
                          "t",
                          WeatherTestFixtures.northbound(49.0, 4.0, 30, 170),
                          List.of(),
                          30_000f,
                          0f,
                          0f)));
              managed.setFilesRevision(2L);
            });
    planner.plan(Instant.now());

    assertTrue(plannedAround(49.0), "the cells of the new geometry");
  }
}
