package fr.pedalons.api.publications;

import static io.restassured.RestAssured.given;
import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.repository.weather.WeatherDailyRepository;
import fr.pedalons.repository.weather.WeatherHourlyRepository;
import fr.pedalons.service.weather.CellKey;
import fr.pedalons.service.weather.WeatherTestFixtures;
import fr.pedalons.util.QueryStats;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Database-cost budget for the publication list endpoints. See {@link AbstractQueryCountTest}. */
@QuarkusTest
class PublicationQueryCountTest extends AbstractQueryCountTest {

  @Inject PlaceRepository placeRepository;
  @Inject RideRepository rideRepository;
  @Inject WeatherCellRepository weatherCellRepository;
  @Inject WeatherHourlyRepository weatherHourlyRepository;
  @Inject WeatherDailyRepository weatherDailyRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  /**
   * Seeds rides that exercise the full {@code RideDto} mapping: every ride has groups, every group
   * has participations, every participation has a distinct user. A ride with no participants would
   * never touch the association walk the DTO actually performs in production, so the test would
   * pass while the endpoint stayed quadratic.
   */
  private void seedRides(int count) {
    seedRides(count, Instant.now().plus(7, ChronoUnit.DAYS));
  }

  private List<Ride> seedRides(int count, Instant base) {
    List<User> participants = List.of(user1, user2, user3, user4, user5);
    List<Ride> rides = new ArrayList<>(count);
    for (int i = 0; i < count; i++) {
      Ride ride =
          dataService.createRide(
              team1,
              user1,
              "Budget Ride " + i,
              "budget-ride-" + i,
              base.plusSeconds(i),
              Visibility.PUBLIC,
              Status.PUBLISHED);
      for (int g = 0; g < 2; g++) {
        RideGroup group = dataService.createRideGroup(user1, ride, "Group " + g, g);
        for (User participant : participants) {
          dataService.createParticipation(group, participant);
        }
      }
      rides.add(ride);
    }
    return rides;
  }

  /**
   * Gives every ride the same meeting point and fills its forecast cell, so the weather line of
   * each card is actually computed — an empty cache would let a per-row read go unnoticed.
   */
  private void locateWithForecast(List<Ride> rides) {
    Instant now = Instant.now();
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Place place = new Place(user1, team1, "Bellecour", true, true);
              place.setGeometry(
                  point(WGS84, g(WeatherTestFixtures.LYON_LON, WeatherTestFixtures.LYON_LAT)));
              placeRepository.persist(place);
              for (Ride ride : rides) {
                rideRepository.findById(ride.getId()).setStart(place);
              }
              Instant firstHour = now.truncatedTo(ChronoUnit.HOURS).minus(2, ChronoUnit.HOURS);
              WeatherTestFixtures.seedCell(
                  weatherCellRepository,
                  weatherHourlyRepository,
                  weatherDailyRepository,
                  CellKey.of(WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON),
                  now,
                  now,
                  WeatherTestFixtures.hours(firstHour, firstHour.plus(72, ChronoUnit.HOURS)),
                  14,
                  WeatherTestFixtures.dates(
                      LocalDate.now(ZoneOffset.UTC).minusDays(1),
                      LocalDate.now(ZoneOffset.UTC).plusDays(3)));
            });
  }

  /** Trips carry stages and participations, the {@code TripDto} equivalent of groups/participants. */
  private void seedTrips(int count) {
    Instant base = Instant.now().plus(7, ChronoUnit.DAYS);
    List<User> participants = List.of(user1, user2, user3, user4, user5);
    for (int i = 0; i < count; i++) {
      Trip trip =
          dataService.createTrip(
              team1, user1, "Budget Trip " + i, base.plusSeconds(i), Visibility.PUBLIC);
      for (int s = 0; s < 3; s++) {
        dataService.createTripStage(user1, trip, "Trip " + i + " Stage " + s, s);
      }
      for (User participant : participants) {
        dataService.createTripParticipation(trip, participant);
      }
    }
  }

  /**
   * docs/LEDGER_*.md API-6: posts by as many distinct authors as rows, half signed by the team — so
   * a per-row walk of {@code createdBy}, or a per-row membership check, would show.
   */
  private void seedPostsByDistinctAuthors(int count) {
    Instant base = Instant.now().minus(1, ChronoUnit.DAYS);
    for (int i = 0; i < count; i++) {
      User author = dataService.createUser("author" + i + "@example.com", "Author " + i);
      Post post = dataService.createPost(team1, author, "Budget Post " + i, base.plusSeconds(i));
      dataService.setPostSignedAsTeam(post, i % 2 == 0);
    }
  }

  @Test
  void listTeamPosts_authorsCostAPageNotARow() {
    seedPostsByDistinctAuthors(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/publications?type=POST",
        asUser1(),
        "/api/teams/" + team1Slug + "/publications?type=POST");
  }

  @Test
  void listTeamPostsAnonymous_authorsCostAPageNotARow() {
    seedPostsByDistinctAuthors(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/publications?type=POST anonymous",
        anonymous(),
        "/api/teams/" + team1Slug + "/publications?type=POST");
  }

  @Test
  void listTeamRides_costDoesNotScaleWithRowCount() {
    seedRides(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/publications?type=RIDE",
        asUser1(),
        "/api/teams/" + team1Slug + "/publications?type=RIDE");
  }

  @Test
  void listAllPublications_costDoesNotScaleWithRowCount() {
    seedRides(LARGE_PAGE);
    assertFlatQueryCount("GET /api/publications", asUser1(), "/api/publications");
  }

  /** Ledger API-137: a platform admin's cross-team listing takes the real-role query shape. */
  @Test
  void listAllPublications_asPlatformAdmin_costDoesNotScaleWithRowCount() {
    seedRides(LARGE_PAGE);
    dataService.createPlatformAdminUser("root@example.com", "Root");
    assertFlatQueryCount(
        "GET /api/publications platform admin",
        () -> given().auth().oauth2(getAccessToken("root")),
        "/api/publications");
  }

  /** The lists of the one team a platform admin opens keep the full view, at the same cost. */
  @Test
  void listTeamRides_asPlatformAdmin_costDoesNotScaleWithRowCount() {
    seedRides(LARGE_PAGE);
    dataService.createPlatformAdminUser("root@example.com", "Root");
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/publications?type=RIDE platform admin",
        () -> given().auth().oauth2(getAccessToken("root")),
        "/api/teams/" + team1Slug + "/publications?type=RIDE");
  }

  /** The same list seen by an anonymous visitor — a different query shape (no UserTeam join). */
  @Test
  void listAllPublicationsAnonymous_costDoesNotScaleWithRowCount() {
    seedRides(LARGE_PAGE);
    assertFlatQueryCount("GET /api/publications anonymous", anonymous(), "/api/publications");
  }

  /**
   * Rides leaving tomorrow, inside the forecast horizon: the weather line of every card is read for
   * the whole page in one query (RideWeatherLookup), never one per ride.
   */
  @Test
  void listTeamRides_inTheForecastWindow_weatherCostsAPageNotARow() {
    locateWithForecast(seedRides(LARGE_PAGE, Instant.now().plus(1, ChronoUnit.DAYS)));
    // Not vacuous: every card of the page carries its line.
    List<String> statuses =
        asUser1()
            .get()
            .when()
            .get("/api/teams/" + team1Slug + "/publications?type=RIDE&size=" + LARGE_PAGE)
            .then()
            .statusCode(200)
            .extract()
            .path("publications.weather.status");
    assertEquals(LARGE_PAGE, statuses.size());
    assertTrue(statuses.stream().allMatch("OK"::equals), statuses.toString());
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/publications?type=RIDE in forecast window",
        asUser1(),
        "/api/teams/" + team1Slug + "/publications?type=RIDE");
  }

  /**
   * docs/LEDGER_*.md API-80: every ride sits on a route of its own carrying both themed thumbnails,
   * and one ride in three has its own light thumbnail too. The row's picture is the ride's own, else
   * its route's — resolved for the whole page by {@code ThumbnailLookup.forRides}, never by walking
   * {@code ride.getRoute().getAssets()} per row.
   *
   * <p>Only statements are budgeted here, not hydrated entities: {@code MediaDto} still reads each
   * ride's own asset inventory, and since rides and routes share the {@code TeamEntity.assets}
   * collection role, Hibernate's batch fetch may initialise the routes' collections alongside —
   * a cost of the media inventory, not of the thumbnail.
   */
  @Test
  void listTeamRides_routeThumbnails_costAPageNotARow() {
    Instant base = Instant.now().plus(7, ChronoUnit.DAYS);
    Map<String, String> expectedThumbnailBySlug = new HashMap<>();
    for (int i = 0; i < LARGE_PAGE; i++) {
      String slug = "routed-ride-" + i;
      Ride ride =
          dataService.createRide(
              team1,
              user1,
              "Routed Ride " + i,
              slug,
              base.plusSeconds(i),
              Visibility.PUBLIC,
              Status.PUBLISHED);
      Route route = dataService.createRoute(team1, user1, "Routed route " + i);
      Asset routeLight =
          dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "light.png");
      dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_DARK, "dark.png");
      dataService.setRideRoute(ride, route);
      Asset expected = routeLight;
      if (i % 3 == 0) {
        expected = dataService.attachAsset(ride, user1, AssetType.RIDE_THUMBNAIL_LIGHT, "own.png");
      }
      expectedThumbnailBySlug.put(slug, TsidUtils.toString(expected.getId()));
    }

    // Not vacuous: every row carries a picture, the ride's own when it has one, else its route's.
    List<Map<String, Object>> rows =
        asUser1()
            .get()
            .when()
            .get("/api/teams/" + team1Slug + "/publications?type=RIDE&size=" + LARGE_PAGE)
            .then()
            .statusCode(200)
            .extract()
            .path("publications");
    assertEquals(LARGE_PAGE, rows.size());
    for (Map<String, Object> row : rows) {
      String thumbnailUrl = (String) row.get("thumbnailUrl");
      String expectedAssetId = expectedThumbnailBySlug.get((String) row.get("slug"));
      assertTrue(
          thumbnailUrl != null && thumbnailUrl.contains("/" + expectedAssetId + "/"),
          () -> row.get("slug") + " expected asset " + expectedAssetId + ", got " + thumbnailUrl);
    }

    String path = "/api/teams/" + team1Slug + "/publications?type=RIDE&size=";
    QueryStats.Counters small =
        queryStats.measureAll(
            "GET /api/teams/{teamSlug}/publications?type=RIDE routed [" + SMALL_PAGE + " rows]",
            () -> asUser1().get().when().get(path + SMALL_PAGE).then().statusCode(200));
    QueryStats.Counters large =
        queryStats.measureAll(
            "GET /api/teams/{teamSlug}/publications?type=RIDE routed [" + LARGE_PAGE + " rows]",
            () -> asUser1().get().when().get(path + LARGE_PAGE).then().statusCode(200));
    long growth = large.statements() - small.statements();
    assertTrue(
        growth <= MAX_STATEMENT_GROWTH,
        () ->
            "N+1 on the ride row thumbnails: "
                + SMALL_PAGE
                + " rows cost "
                + small.statements()
                + " SQL statements, "
                + LARGE_PAGE
                + " rows cost "
                + large.statements()
                + " (+"
                + growth
                + ", budget +"
                + MAX_STATEMENT_GROWTH
                + ")");
  }

  /**
   * docs/LEDGER_*.md API-82: trips whose first stage has gone and whose second leaves tomorrow, on a
   * route starting in a cell whose forecast is cached — with its elevation band, as the planner
   * fetches a stage's first sample. The weather line of every card is that of the next stage, read
   * for the whole page in one query (TripWeatherLookup), never by loading each trip's stages.
   */
  @Test
  void listTeamTrips_inTheForecastWindow_weatherCostsAPageNotARow() {
    Instant now = Instant.now();
    Route route =
        dataService.createRouteWithTracks(
            team1,
            user1,
            "Trip weather route",
            Visibility.PUBLIC,
            List.of(
                WeatherTestFixtures.northbound(
                    WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170)));
    for (int i = 0; i < LARGE_PAGE; i++) {
      Trip trip =
          dataService.createTrip(
              team1,
              user1,
              "Weather Trip " + i,
              now.minus(1, ChronoUnit.DAYS).plusSeconds(i),
              Visibility.PUBLIC);
      TripStage gone =
          dataService.createTripStage(
              user1, trip, "Weather Trip " + i + " Day 1", 0, now.minus(1, ChronoUnit.DAYS));
      dataService.setTripStageRoute(gone, route);
      TripStage next =
          dataService.createTripStage(
              user1, trip, "Weather Trip " + i + " Day 2", 1, now.plus(1, ChronoUnit.DAYS));
      dataService.setTripStageRoute(next, route);
      // The next stage is read in a zone of its own, not the trip's (its first stage's): the
      // card's times follow it (docs/LEDGER_*.md API-60).
      dataService.setTimezone(next.getId(), "Asia/Tokyo");
    }
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Instant firstHour = now.truncatedTo(ChronoUnit.HOURS).minus(2, ChronoUnit.HOURS);
              WeatherTestFixtures.seedCell(
                  weatherCellRepository,
                  weatherHourlyRepository,
                  weatherDailyRepository,
                  // The first track point, at 170 m: the 200 m band.
                  CellKey.of(WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 170.0),
                  now,
                  now,
                  WeatherTestFixtures.hours(firstHour, firstHour.plus(72, ChronoUnit.HOURS)),
                  14,
                  WeatherTestFixtures.dates(
                      LocalDate.now(ZoneOffset.UTC).minusDays(1),
                      LocalDate.now(ZoneOffset.UTC).plusDays(3)));
            });
    // Not vacuous: every card of the page carries its line, read from the cached cell.
    List<Map<String, Object>> weather =
        asUser1()
            .get()
            .when()
            .get("/api/teams/" + team1Slug + "/publications?type=TRIP&size=" + LARGE_PAGE)
            .then()
            .statusCode(200)
            .extract()
            .path("publications.weather");
    assertEquals(LARGE_PAGE, weather.size());
    for (Map<String, Object> line : weather) {
      assertEquals("OK", line.get("status"), weather.toString());
      assertEquals(14.0f, ((Number) line.get("temperature")).floatValue(), weather.toString());
      assertEquals("Asia/Tokyo", line.get("timezone"), weather.toString());
    }
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/publications?type=TRIP in forecast window",
        asUser1(),
        "/api/teams/" + team1Slug + "/publications?type=TRIP");
  }

  /**
   * docs/LEDGER_*.md API-83: every trip sits on a route of its own carrying both themed thumbnails,
   * and one trip in three has its own light thumbnail too. The row's picture is the trip's own, else
   * its route's — resolved for the whole page by {@code ThumbnailLookup.forTrips}, never by walking
   * {@code trip.getRoute().getAssets()} per row.
   *
   * <p>Only statements are budgeted, as for rides: {@code MediaDto} still reads each trip's own
   * asset inventory, and the {@code TeamEntity.assets} collection role is shared with the routes.
   */
  @Test
  void listTeamTrips_routeThumbnails_costAPageNotARow() {
    Instant base = Instant.now().plus(7, ChronoUnit.DAYS);
    Map<String, String> expectedThumbnailByTripId = new HashMap<>();
    for (int i = 0; i < LARGE_PAGE; i++) {
      Trip trip =
          dataService.createTrip(
              team1, user1, "Routed Trip " + i, base.plusSeconds(i), Visibility.PUBLIC);
      Route route = dataService.createRoute(team1, user1, "Routed trip route " + i);
      Asset routeLight =
          dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "light.png");
      dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_DARK, "dark.png");
      dataService.setTripRoute(trip, route);
      Asset expected = routeLight;
      if (i % 3 == 0) {
        expected = dataService.attachAsset(trip, user1, AssetType.TRIP_THUMBNAIL_LIGHT, "own.png");
      }
      expectedThumbnailByTripId.put(
          TsidUtils.toString(trip.getId()), TsidUtils.toString(expected.getId()));
    }

    // Not vacuous: every row carries a picture, the trip's own when it has one, else its route's.
    List<Map<String, Object>> rows =
        asUser1()
            .get()
            .when()
            .get("/api/teams/" + team1Slug + "/publications?type=TRIP&size=" + LARGE_PAGE)
            .then()
            .statusCode(200)
            .extract()
            .path("publications");
    assertEquals(LARGE_PAGE, rows.size());
    for (Map<String, Object> row : rows) {
      String thumbnailUrl = (String) row.get("thumbnailUrl");
      String expectedAssetId = expectedThumbnailByTripId.get((String) row.get("id"));
      assertTrue(
          thumbnailUrl != null && thumbnailUrl.contains("/" + expectedAssetId + "/"),
          () -> row.get("slug") + " expected asset " + expectedAssetId + ", got " + thumbnailUrl);
    }

    String path = "/api/teams/" + team1Slug + "/publications?type=TRIP&size=";
    QueryStats.Counters small =
        queryStats.measureAll(
            "GET /api/teams/{teamSlug}/publications?type=TRIP routed [" + SMALL_PAGE + " rows]",
            () -> asUser1().get().when().get(path + SMALL_PAGE).then().statusCode(200));
    QueryStats.Counters large =
        queryStats.measureAll(
            "GET /api/teams/{teamSlug}/publications?type=TRIP routed [" + LARGE_PAGE + " rows]",
            () -> asUser1().get().when().get(path + LARGE_PAGE).then().statusCode(200));
    long growth = large.statements() - small.statements();
    assertTrue(
        growth <= MAX_STATEMENT_GROWTH,
        () ->
            "N+1 on the trip row thumbnails: "
                + SMALL_PAGE
                + " rows cost "
                + small.statements()
                + " SQL statements, "
                + LARGE_PAGE
                + " rows cost "
                + large.statements()
                + " (+"
                + growth
                + ", budget +"
                + MAX_STATEMENT_GROWTH
                + ")");
  }

  @Test
  void listTeamTrips_costDoesNotScaleWithRowCount() {
    seedTrips(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/publications?type=TRIP",
        asUser1(),
        "/api/teams/" + team1Slug + "/publications?type=TRIP");
  }

  /**
   * The ride detail endpoint walks groups -> participations -> user for the full participant list,
   * so its cost must be flat in the number of participants, not one SELECT per participant.
   */
  @Test
  void rideDetail_queryCountDoesNotScaleWithParticipantCount() {
    Instant base = Instant.now().plus(7, ChronoUnit.DAYS);
    List<User> participants = List.of(user1, user2, user3, user4, user5);

    Ride small = dataService.createRide(team1, user1, "Small", "small-ride", base);
    dataService.createParticipation(
        dataService.createRideGroup(user1, small, "Only group", 0), user1);

    Ride large = dataService.createRide(team1, user1, "Large", "large-ride", base.plusSeconds(1));
    for (int g = 0; g < 6; g++) {
      RideGroup group = dataService.createRideGroup(user1, large, "Group " + g, g);
      for (User participant : participants) {
        dataService.createParticipation(group, participant);
      }
    }

    QueryStats.Counters smallCounters =
        measureDetail("GET /api/teams/{teamSlug}/rides/{rideSlug} [1 participant]", "small-ride");
    QueryStats.Counters largeCounters =
        measureDetail("GET /api/teams/{teamSlug}/rides/{rideSlug} [30 participants]", "large-ride");

    long growth = largeCounters.statements() - smallCounters.statements();
    assertTrue(
        growth <= MAX_STATEMENT_GROWTH,
        () ->
            "N+1 on the ride detail endpoint: 1 participant cost "
                + smallCounters.statements()
                + " SQL statements, 30 participants cost "
                + largeCounters.statements()
                + " (+"
                + growth
                + ", budget +"
                + MAX_STATEMENT_GROWTH
                + ")");
  }

  /**
   * Every group of the detail carries its route's thumbnail (ledger API-3). They are resolved for
   * the whole ride in one query, so six groups on six routes must cost what one group on one route
   * does — not one asset walk per group.
   */
  @Test
  void rideDetail_groupRouteThumbnails_costDoesNotScaleWithGroupCount() {
    Instant base = Instant.now().plus(7, ChronoUnit.DAYS);
    Ride small = dataService.createRide(team1, user1, "Small", "small-ride", base);
    seedGroupOnThumbnailedRoute(small, 0);
    Ride large = dataService.createRide(team1, user1, "Large", "large-ride", base.plusSeconds(1));
    for (int g = 0; g < 6; g++) {
      seedGroupOnThumbnailedRoute(large, g);
    }

    QueryStats.Counters smallCounters =
        measureDetail("GET /api/teams/{teamSlug}/rides/{rideSlug} [1 routed group]", "small-ride");
    QueryStats.Counters largeCounters =
        measureDetail("GET /api/teams/{teamSlug}/rides/{rideSlug} [6 routed groups]", "large-ride");

    long growth = largeCounters.statements() - smallCounters.statements();
    assertTrue(
        growth <= MAX_STATEMENT_GROWTH,
        () ->
            "N+1 on the group route thumbnails: 1 group cost "
                + smallCounters.statements()
                + " SQL statements, 6 groups cost "
                + largeCounters.statements()
                + " (+"
                + growth
                + ", budget +"
                + MAX_STATEMENT_GROWTH
                + ")");
  }

  private void seedGroupOnThumbnailedRoute(Ride ride, int index) {
    RideGroup group = dataService.createRideGroup(user1, ride, "Group " + index, index);
    Route route = dataService.createRoute(team1, user1, ride.getName() + " route " + index);
    dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "light.png");
    dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_DARK, "dark.png");
    dataService.setRideGroupRoute(group, route);
  }

  private QueryStats.Counters measureDetail(String label, String rideSlug) {
    return queryStats.measureAll(
        label,
        () ->
            given()
                .auth()
                .oauth2(getAccessToken(USER1))
                .when()
                .get("/api/teams/" + team1Slug + "/rides/" + rideSlug)
                .then()
                .statusCode(200));
  }
}
