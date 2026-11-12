package fr.pedalons.api.rides;

import static io.restassured.RestAssured.given;
import static org.geolatte.geom.builder.DSL.g;
import static org.geolatte.geom.builder.DSL.point;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoCircuitBreaker;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.service.weather.WeatherFetchWorker;
import fr.pedalons.service.weather.WeatherPlanner;
import fr.pedalons.service.weather.WeatherTestFixtures;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import io.restassured.response.Response;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code GET …/rides/{rideSlug}/weather} and {@code RideDto.weather}: who may read it, the state it
 * answers in, and the caching headers each state gets. Nothing here reaches Open-Meteo — the weather
 * is disabled in tests and the endpoint only ever reads the cache; the cache itself is covered by
 * {@code WeatherCacheTest}. The provider is mocked only for the tests that fill the cache first,
 * through the planner and the worker, as production does.
 */
@QuarkusTest
class RideWeatherResourceTest extends AbstractResourceTest {

  /** Field names that would place a point on the map — none may appear in the weather. */
  private static final Set<String> COORDINATE_KEYS =
      Set.of("lat", "lon", "lng", "latitude", "longitude", "coordinates", "geometry");

  @Inject PlaceRepository placeRepository;
  @Inject RideRepository rideRepository;
  @Inject WeatherPlanner planner;
  @Inject WeatherFetchWorker worker;
  @Inject ObjectMapper objectMapper;
  @Inject WeatherCellRepository weatherCellRepository;

  /** Only the cache-filling tests call it; the endpoint itself never does. */
  @InjectMock OpenMeteoGateway gateway;

  @InjectMock OpenMeteoCircuitBreaker breaker;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    when(breaker.isClosed(any())).thenReturn(true);
    when(breaker.remainingBudget(any())).thenReturn(1_000);
    answerWithTemperature(15);
  }

  private void answerWithTemperature(double temperature) {
    when(gateway.forecast(anyList()))
        .thenAnswer(invocation -> {
          List<Location> locations = invocation.getArgument(0);
          return locations.stream()
              .map(l -> WeatherTestFixtures.forecast(l, 48, temperature, 0))
              .toList();
        });
  }

  /** A ride tomorrow from Bellecour along 30 km due north, its cache filled as the jobs would. */
  private Ride forecastRide(String slug, Visibility visibility) {
    Ride ride = rideAt(slug, Instant.now().plus(1, ChronoUnit.DAYS), visibility, true);
    Route route =
        dataService.createRouteWithTracks(
            team1,
            user1,
            "Nord " + slug,
            Visibility.PUBLIC,
            List.of(
                WeatherTestFixtures.northbound(
                    WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170)));
    QuarkusTransaction.requiringNew()
        .run(() ->
            rideRepository
                .findById(ride.getId())
                .setRoute(rideRepository.getEntityManager().find(Route.class, route.getId())));
    planner.plan(Instant.now());
    worker.fetchDue();
    return ride;
  }

  /** Every field name of {@code node}, at any depth. */
  private static void collectKeys(JsonNode node, String path, List<String> into) {
    if (node.isObject()) {
      node.properties()
          .forEach(e -> {
            into.add(path + "." + e.getKey());
            collectKeys(e.getValue(), path + "." + e.getKey(), into);
          });
    } else if (node.isArray()) {
      for (int i = 0; i < node.size(); i++) {
        collectKeys(node.get(i), path + "[" + i + "]", into);
      }
    }
  }

  private void assertNoCoordinate(JsonNode node, String what) {
    List<String> keys = new ArrayList<>();
    collectKeys(node, "$", keys);
    List<String> leaks =
        keys.stream()
            .filter(k ->
                COORDINATE_KEYS.contains(
                    k.substring(k.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT)))
            .toList();
    assertTrue(leaks.isEmpty(), what + " leaks coordinates: " + leaks);
  }

  private Ride rideAt(String slug, Instant dateTime, Visibility visibility, boolean withPlace) {
    Ride ride =
        dataService.createRide(
            team1, user1, "Ride " + slug, slug, dateTime, visibility, Status.PUBLISHED);
    if (withPlace) {
      QuarkusTransaction.requiringNew()
          .run(() -> {
            Place place = new Place(user1, team1, "Bellecour " + slug, true, true);
            place.setGeometry(point(WGS84, g(4.8320, 45.7578)));
            placeRepository.persist(place);
            rideRepository.findById(ride.getId()).setStart(place);
          });
    }
    return ride;
  }

  private String weatherUrl(String slug) {
    return "/api/teams/" + team1Slug + "/rides/" + slug + "/weather";
  }

  @Test
  void weather_ofARideTheCallerMayNotRead_isNotFound() {
    rideAt("team-only", Instant.now().plus(1, ChronoUnit.DAYS), Visibility.TEAM, true);

    given().when().get(weatherUrl("team-only")).then().statusCode(404);
  }

  @Test
  void weather_beyondTheHorizon_isNotYetAvailable_andRevalidates() {
    Instant departure = Instant.now().plus(10, ChronoUnit.DAYS);
    rideAt("far-ride", departure, Visibility.PUBLIC, true);

    Response response =
        given()
            .when()
            .get(weatherUrl("far-ride"))
            .then()
            .statusCode(200)
            .header("Cache-Control", equalTo("private, no-cache"))
            .header("ETag", notNullValue())
            .body("status", equalTo("NOT_YET_AVAILABLE"))
            .body("availableFrom", notNullValue())
            .body("departure.status", equalTo("NOT_YET_AVAILABLE"))
            .body("legs", empty())
            .body("attribution.name", equalTo("Open-Meteo.com"))
            .extract()
            .response();
    String etag = response.header("ETag");

    given()
        .header("If-None-Match", etag)
        .when()
        .get(weatherUrl("far-ride"))
        .then()
        .statusCode(304)
        .header("ETag", equalTo(etag));
  }

  @Test
  void weather_ofATeamRide_isReadByItsMembers() {
    rideAt("members-only", Instant.now().plus(1, ChronoUnit.DAYS), Visibility.TEAM, true);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get(weatherUrl("members-only"))
        .then()
        .statusCode(200)
        .body("status", equalTo("UNAVAILABLE"));
  }

  @Test
  void weather_ofAnUnknownRide_isNotFound() {
    given().when().get(weatherUrl("no-such-ride")).then().statusCode(404);
  }

  /** J-8: one day short of the horizon, the forecast opens a day later. */
  @Test
  void weather_eightDaysAhead_isNotYetAvailable_untilSevenDaysBefore() {
    Instant departure = Instant.now().plus(8, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    rideAt("next-week", departure, Visibility.PUBLIC, true);

    String availableFrom =
        given()
            .when()
            .get(weatherUrl("next-week"))
            .then()
            .statusCode(200)
            .body("status", equalTo("NOT_YET_AVAILABLE"))
            .body("$", not(hasKey("fetchedAt")))
            .extract()
            .path("availableFrom");

    assertEquals(departure.minus(7, ChronoUnit.DAYS), Instant.parse(availableFrom));
  }

  @Test
  void weather_ofACancelledRide_isOutOfRange() {
    dataService.createRide(
        team1,
        user1,
        "Ride cancelled",
        "cancelled-ride",
        Instant.now().plus(1, ChronoUnit.DAYS),
        Visibility.PUBLIC,
        Status.CANCELLED);

    given()
        .when()
        .get(weatherUrl("cancelled-ride"))
        .then()
        .statusCode(200)
        .body("status", equalTo("OUT_OF_RANGE"))
        .body("legs", empty());
  }

  @Test
  void weather_withAForecast_isOk_andCarriesNoCoordinate() throws Exception {
    forecastRide("forecast-ride", Visibility.PUBLIC);

    Response response =
        given()
            .when()
            .get(weatherUrl("forecast-ride"))
            .then()
            .statusCode(200)
            .header("Cache-Control", equalTo("private, no-cache"))
            .header("ETag", notNullValue())
            .body("status", equalTo("OK"))
            .body("fetchedAt", notNullValue())
            .body("departure.status", equalTo("OK"))
            .body("departure.conditions.temperature", equalTo(15.0f))
            .body("legs", hasSize(1))
            .body("legs[0].speedIsDefault", equalTo(true))
            .body("legs[0].averageSpeed", equalTo(25.0f))
            .body("legs[0].checkpoints", hasSize(3))
            .body("legs[0].checkpoints[0].kind", equalTo("START"))
            .body("legs[0].checkpoints[2].kind", equalTo("FINISH"))
            .body("legs[0].checkpoints[2].relativeWind", equalTo("HEAD"))
            .extract()
            .response();

    assertNoCoordinate(objectMapper.readTree(response.asString()), "GET …/weather");

    // The card's line, in the detail and in the list, is no more precise.
    JsonNode detail =
        objectMapper.readTree(
            given()
                .when()
                .get("/api/teams/" + team1Slug + "/rides/forecast-ride")
                .then()
                .statusCode(200)
                .extract()
                .asString());
    assertEquals("OK", detail.path("weather").path("status").asText());
    assertNoCoordinate(detail.path("weather"), "RideDto.weather");
    JsonNode list =
        objectMapper.readTree(
            given()
                .when()
                .get("/api/teams/" + team1Slug + "/publications?type=RIDE")
                .then()
                .statusCode(200)
                .extract()
                .asString());
    for (JsonNode publication : list.path("publications")) {
      assertNoCoordinate(publication.path("weather"), "publication weather");
    }
  }

  @Test
  void weather_aRefreshedForecast_shouldChangeTheETag() {
    forecastRide("refreshed-ride", Visibility.PUBLIC);
    String etag =
        given()
            .when()
            .get(weatherUrl("refreshed-ride"))
            .then()
            .statusCode(200)
            .extract()
            .header("ETag");

    QuarkusTransaction.requiringNew()
        .run(() ->
            weatherCellRepository.update("nextRefreshAt = ?1", Instant.now().minusSeconds(1)));
    answerWithTemperature(22);
    worker.fetchDue();

    given()
        .header("If-None-Match", etag)
        .when()
        .get(weatherUrl("refreshed-ride"))
        .then()
        .statusCode(200)
        .header("ETag", not(equalTo(etag)))
        .body("departure.conditions.temperature", equalTo(22.0f));
  }

  /** In the window, nothing in cache: the client offers a retry, so nothing may keep it. */
  @Test
  void weather_inTheWindowWithNothingCached_isUnavailable_andNotStored() {
    rideAt("soon-ride", Instant.now().plus(1, ChronoUnit.DAYS), Visibility.PUBLIC, true);

    Response response =
        given()
            .when()
            .get(weatherUrl("soon-ride"))
            .then()
            .statusCode(200)
            .header("Cache-Control", equalTo("no-store"))
            .body("status", equalTo("UNAVAILABLE"))
            .extract()
            .response();
    assertNull(response.header("ETag"));
  }

  @Test
  void weather_ofARideWithNoPlace_isNoLocation() {
    rideAt("nowhere-ride", Instant.now().plus(1, ChronoUnit.DAYS), Visibility.PUBLIC, false);

    given()
        .when()
        .get(weatherUrl("nowhere-ride"))
        .then()
        .statusCode(200)
        .body("status", equalTo("NO_LOCATION"))
        .body("legs", empty());
  }

  @Test
  void weather_ofAFinishedRide_isOutOfRange() {
    // Two days back: whatever the hour, the local day of its end is over (API-183).
    rideAt("past-ride", Instant.now().minus(2, ChronoUnit.DAYS), Visibility.PUBLIC, true);

    given()
        .when()
        .get(weatherUrl("past-ride"))
        .then()
        .statusCode(200)
        .body("status", equalTo("OUT_OF_RANGE"))
        .body("legs", empty());
  }

  /**
   * A ride from Bellecour along 30 km due north, leaving at {@code departure}, one group per
   * {@code groupStarts}, its end stored at {@code end} as {@code PublicationEndCalculator} would,
   * then its cache filled by the planner and the worker.
   */
  private Ride groupedRide(String slug, Instant departure, Instant end, Instant... groupStarts) {
    Ride ride = rideAt(slug, departure, Visibility.PUBLIC, true);
    Route route =
        dataService.createRouteWithTracks(
            team1,
            user1,
            "Nord " + slug,
            Visibility.PUBLIC,
            List.of(
                WeatherTestFixtures.northbound(
                    WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170)));
    QuarkusTransaction.requiringNew()
        .run(() -> {
          Ride managed = rideRepository.findById(ride.getId());
          managed.setRoute(rideRepository.getEntityManager().find(Route.class, route.getId()));
          managed.setEndDateTime(end);
        });
    for (int i = 0; i < groupStarts.length; i++) {
      RideGroup group = dataService.createRideGroup(user1, ride, "G" + i, i);
      dataService.setRideGroupStart(group, groupStarts[i]);
    }
    planner.plan(Instant.now());
    worker.fetchDue();
    return ride;
  }

  /**
   * docs/LEDGER_*.md API-170: left an hour ago, its second group still to leave — the forecast is
   * still served, the late group's leg with it.
   */
  @Test
  void weather_ofARideUnderWay_isServedUntilItsEnd() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    Instant later = now.plus(2, ChronoUnit.HOURS);
    groupedRide(
        "underway-ride",
        now.minus(1, ChronoUnit.HOURS),
        now.plus(4, ChronoUnit.HOURS),
        now.minus(1, ChronoUnit.HOURS),
        later);

    String body =
        given()
            .when()
            .get(weatherUrl("underway-ride"))
            .then()
            .statusCode(200)
            .body("status", not(equalTo("OUT_OF_RANGE")))
            .body("legs", hasSize(2))
            .body("legs[1].status", equalTo("OK"))
            .extract()
            .asString();
    assertEquals(later, Instant.parse(jsonPath(body, "legs[1].startTime")));

    // The card line is not cut at the departure either.
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/rides/underway-ride")
        .then()
        .statusCode(200)
        .body("weather", notNullValue());
  }

  /**
   * The local day of its stored end is over: nothing to show. 26 hours back is another day
   * whatever the hour; the same day past the estimated arrival is {@code
   * RideWeatherCalculatorTest}'s, on a fixed clock (docs/LEDGER_*.md API-183).
   */
  @Test
  void weather_ofARidePastTheDayOfItsEnd_isOutOfRange() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    groupedRide(
        "over-ride",
        now.minus(30, ChronoUnit.HOURS),
        now.minus(26, ChronoUnit.HOURS),
        now.minus(30, ChronoUnit.HOURS));

    given()
        .when()
        .get(weatherUrl("over-ride"))
        .then()
        .statusCode(200)
        .body("status", equalTo("OUT_OF_RANGE"))
        .body("legs", empty());
  }

  /**
   * docs/LEDGER_*.md API-169: each leg carries its one-line summary and the meeting point's
   * weather at the group's own start, sunrise and sunset included.
   */
  @Test
  void weather_eachLeg_carriesItsSummary_andItsDepartureAtTheGroupsStart() {
    Instant departure = Instant.now().plus(3, ChronoUnit.HOURS).truncatedTo(ChronoUnit.SECONDS);
    Instant later = departure.plus(5, ChronoUnit.HOURS);
    groupedRide("two-starts", departure, later.plus(2, ChronoUnit.HOURS), departure, later);

    String body =
        given()
            .when()
            .get(weatherUrl("two-starts"))
            .then()
            .statusCode(200)
            .body("status", equalTo("OK"))
            .body("legs", hasSize(2))
            .body("legs[0].summary.status", equalTo("OK"))
            .body("legs[0].summary.temperature", equalTo(15.0f))
            .body("legs[0].departure.status", equalTo("OK"))
            .body("legs[1].summary.status", equalTo("OK"))
            .body("legs[1].departure.status", equalTo("OK"))
            .body("legs[1].departure.conditions.temperature", equalTo(15.0f))
            .body("legs[1].departure.sunrise", notNullValue())
            .body("legs[1].departure.sunset", notNullValue())
            .extract()
            .asString();

    // The ride's block is at the ride's time, the late group's at its own.
    Instant rideHour = Instant.parse(jsonPath(body, "departure.conditions.time"));
    Instant lateHour = Instant.parse(jsonPath(body, "legs[1].departure.conditions.time"));
    assertTrue(
        Duration.between(rideHour, departure).abs().toMinutes() <= 30, "ride block at " + rideHour);
    assertTrue(
        Duration.between(lateHour, later).abs().toMinutes() <= 30,
        "late group block at " + lateHour);
    assertEquals(rideHour, Instant.parse(jsonPath(body, "legs[0].departure.conditions.time")));
  }

  private static String jsonPath(String body, String path) {
    return JsonPath.from(body).getString(path);
  }

  @Test
  void rideDto_carriesTheWeatherLine_onlyWhenThereIsSomethingToShow() {
    rideAt("far-ride", Instant.now().plus(10, ChronoUnit.DAYS), Visibility.PUBLIC, true);
    rideAt("soon-ride", Instant.now().plus(1, ChronoUnit.DAYS), Visibility.PUBLIC, true);

    // Beyond the horizon: the card says when the forecast opens, in the detail and in the list.
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/rides/far-ride")
        .then()
        .statusCode(200)
        .body("weather.status", equalTo("NOT_YET_AVAILABLE"))
        .body("weather.availableFrom", notNullValue())
        .body("weather.temperature", nullValue());
    // In the window but nothing cached: no line at all, not an empty one.
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/rides/soon-ride")
        .then()
        .statusCode(200)
        .body("$", not(hasKey("weather")));

    Response list =
        given()
            .when()
            .get("/api/teams/" + team1Slug + "/publications?type=RIDE")
            .then()
            .statusCode(200)
            .extract()
            .response();
    assertNotNull(
        list.path("publications.find { it.slug == 'far-ride' }.weather"),
        "far ride carries its line");
    assertNull(
        list.path("publications.find { it.slug == 'soon-ride' }.weather"), "soon ride has none");
  }
}
