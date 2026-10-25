package fr.pedalons.api.trips;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoCircuitBreaker;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import fr.pedalons.repository.trip.TripStageRepository;
import fr.pedalons.service.weather.WeatherFetchWorker;
import fr.pedalons.service.weather.WeatherPlanner;
import fr.pedalons.service.weather.WeatherTestFixtures;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * {@code GET …/trips/{tripSlug}/weather} (docs/LEDGER_*.md API-76): who may read it, the state of
 * the trip and of each stage, the caching headers. As for rides, nothing here reaches Open-Meteo:
 * the provider is mocked for the tests that fill the cache through the planner and the worker.
 */
@QuarkusTest
class TripWeatherResourceTest extends AbstractResourceTest {

  /** Field names that would place a point on the map — none may appear in the weather. */
  private static final Set<String> COORDINATE_KEYS =
      Set.of("lat", "lon", "lng", "latitude", "longitude", "coordinates", "geometry");

  @Inject TripStageRepository tripStageRepository;
  @Inject WeatherPlanner planner;
  @Inject WeatherFetchWorker worker;
  @Inject ObjectMapper objectMapper;

  @InjectMock OpenMeteoGateway gateway;

  @InjectMock OpenMeteoCircuitBreaker breaker;

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
              return locations.stream()
                  .map(l -> WeatherTestFixtures.forecast(l, 48, 15, 0))
                  .toList();
            });
  }

  private String weatherUrl(String slug) {
    return "/api/teams/" + team1Slug + "/trips/" + slug + "/weather";
  }

  private Trip trip(String name, Instant dateTime, Visibility visibility, Status status) {
    return dataService.createTrip(team1, user1, name, dateTime, visibility, status, null);
  }

  /** A stage leaving at {@code dateTime}, along 30 km due north of Lyon when {@code routed}. */
  private TripStage stage(Trip trip, String name, int order, Instant dateTime, boolean routed) {
    TripStage stage = dataService.createTripStage(user1, trip, name, order);
    if (routed) {
      Route route =
          dataService.createRouteWithTracks(
              team1,
              user1,
              "Route " + name,
              Visibility.PUBLIC,
              List.of(
                  WeatherTestFixtures.northbound(
                      WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170)));
      // Merges the detached stage: before the date is set, which it would otherwise overwrite.
      dataService.setTripStageRoute(stage, route);
    }
    QuarkusTransaction.requiringNew()
        .run(() -> tripStageRepository.findById(stage.getId()).setDateTime(dateTime));
    return stage;
  }

  private static void collectKeys(JsonNode node, String path, List<String> into) {
    if (node.isObject()) {
      node.properties()
          .forEach(
              e -> {
                into.add(path + "." + e.getKey());
                collectKeys(e.getValue(), path + "." + e.getKey(), into);
              });
    } else if (node.isArray()) {
      for (int i = 0; i < node.size(); i++) {
        collectKeys(node.get(i), path + "[" + i + "]", into);
      }
    }
  }

  @Test
  void weather_ofATripTheCallerMayNotRead_isNotFound() {
    Trip trip =
        trip(
            "Team only trip",
            Instant.now().plus(1, ChronoUnit.DAYS),
            Visibility.TEAM,
            Status.PUBLISHED);
    stage(trip, "Team only day 1", 0, Instant.now().plus(1, ChronoUnit.DAYS), true);

    given().when().get(weatherUrl(trip.getSlug())).then().statusCode(404);
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get(weatherUrl(trip.getSlug()))
        .then()
        .statusCode(200);
  }

  @Test
  void weather_ofADraftTrip_isOutOfRange() {
    Trip trip =
        trip("Draft trip", Instant.now().plus(1, ChronoUnit.DAYS), Visibility.PUBLIC, Status.DRAFT);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get(weatherUrl(trip.getSlug()))
        .then()
        .statusCode(200)
        .body("status", equalTo("OUT_OF_RANGE"))
        .body("stages", empty());
  }

  /** Each stage has its own state: gone, within range, beyond the horizon, without a route. */
  @Test
  void weather_shouldGiveEachStageItsOwnState_inStageOrder() throws Exception {
    Instant start = Instant.now().minus(1, ChronoUnit.DAYS);
    Trip trip = trip("Long trip", start, Visibility.PUBLIC, Status.PUBLISHED);
    TripStage gone = stage(trip, "Long day 1", 0, start, true);
    TripStage soon = stage(trip, "Long day 2", 1, Instant.now().plus(1, ChronoUnit.DAYS), true);
    TripStage unrouted =
        stage(trip, "Long day 3", 2, Instant.now().plus(2, ChronoUnit.DAYS), false);
    Instant farStart = Instant.now().plus(9, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    TripStage far = stage(trip, "Long day 4", 3, farStart, true);
    planner.plan(Instant.now());
    worker.fetchDue();

    String body =
        given()
            .when()
            .get(weatherUrl(trip.getSlug()))
            .then()
            .statusCode(200)
            .header("Cache-Control", equalTo("private, no-cache"))
            .header("ETag", notNullValue())
            .body("status", equalTo("OK"))
            .body("fetchedAt", notNullValue())
            .body("attribution.name", equalTo("Open-Meteo.com"))
            .body("stages", hasSize(4))
            .body("stages[0].stageId", equalTo(TsidUtils.toString(gone.getId())))
            .body("stages[0].leg.status", equalTo("OUT_OF_RANGE"))
            .body("stages[0]", not(hasKey("summary")))
            .body("stages[1].stageId", equalTo(TsidUtils.toString(soon.getId())))
            .body("stages[1].leg.status", equalTo("OK"))
            .body("stages[1].leg.speedIsDefault", equalTo(true))
            .body("stages[1].leg.groupId", nullValue())
            .body("stages[1].leg.checkpoints", hasSize(3))
            .body("stages[1].summary.status", equalTo("OK"))
            .body("stages[1].summary.temperature", equalTo(15.0f))
            .body("stages[2].stageId", equalTo(TsidUtils.toString(unrouted.getId())))
            .body("stages[2].leg.status", equalTo("NO_LOCATION"))
            .body("stages[3].stageId", equalTo(TsidUtils.toString(far.getId())))
            .body("stages[3].leg.status", equalTo("NOT_YET_AVAILABLE"))
            .body("stages[3].summary.status", equalTo("NOT_YET_AVAILABLE"))
            .extract()
            .asString();

    JsonNode json = objectMapper.readTree(body);
    assertEquals(
        farStart.minus(7, ChronoUnit.DAYS),
        Instant.parse(json.path("stages").get(3).path("leg").path("availableFrom").asString()));
    List<String> keys = new ArrayList<>();
    collectKeys(json, "$", keys);
    List<String> leaks =
        keys.stream()
            .filter(
                k ->
                    COORDINATE_KEYS.contains(
                        k.substring(k.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT)))
            .toList();
    assertTrue(leaks.isEmpty(), "GET …/trips/{tripSlug}/weather leaks coordinates: " + leaks);
  }

  @Test
  void weather_withEveryRoutedStageBeyondTheHorizon_isNotYetAvailable() {
    Instant farStart = Instant.now().plus(10, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    Trip trip = trip("Far trip", farStart, Visibility.PUBLIC, Status.PUBLISHED);
    stage(trip, "Far day 1", 0, farStart, true);
    stage(trip, "Far day 2", 1, farStart.plus(1, ChronoUnit.DAYS), true);

    String availableFrom =
        given()
            .when()
            .get(weatherUrl(trip.getSlug()))
            .then()
            .statusCode(200)
            .body("status", equalTo("NOT_YET_AVAILABLE"))
            .body("stages", hasSize(2))
            .extract()
            .path("availableFrom");

    assertEquals(farStart.minus(7, ChronoUnit.DAYS), Instant.parse(availableFrom));
  }

  /** In the window, nothing in cache: the client offers a retry, so nothing may keep it. */
  @Test
  void weather_inTheWindowWithNothingCached_isUnavailable_andNotStored() {
    Instant tomorrow = Instant.now().plus(1, ChronoUnit.DAYS);
    Trip trip = trip("Soon trip", tomorrow, Visibility.PUBLIC, Status.PUBLISHED);
    stage(trip, "Soon day 1", 0, tomorrow, true);

    given()
        .when()
        .get(weatherUrl(trip.getSlug()))
        .then()
        .statusCode(200)
        .header("Cache-Control", equalTo("no-store"))
        .header("ETag", nullValue())
        .body("status", equalTo("UNAVAILABLE"))
        .body("stages[0].leg.status", equalTo("UNAVAILABLE"))
        .body("stages[0]", not(hasKey("summary")));
  }

  @Test
  void weather_ofATripWithoutStages_ridesItsOwnRoute() {
    Instant tomorrow = Instant.now().plus(1, ChronoUnit.DAYS);
    Trip trip = trip("Day trip", tomorrow, Visibility.PUBLIC, Status.PUBLISHED);
    Route route =
        dataService.createRouteWithTracks(
            team1,
            user1,
            "Route day trip",
            Visibility.PUBLIC,
            List.of(
                WeatherTestFixtures.northbound(
                    WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170)));
    dataService.setTripRoute(trip, route);
    planner.plan(Instant.now());
    worker.fetchDue();

    given()
        .when()
        .get(weatherUrl(trip.getSlug()))
        .then()
        .statusCode(200)
        .body("status", equalTo("OK"))
        .body("stages", hasSize(1))
        .body("stages[0]", not(hasKey("stageId")))
        .body("stages[0].leg.status", equalTo("OK"));
  }

  @Test
  void weather_ofAFinishedTrip_isOutOfRange() {
    Instant start = Instant.now().minus(3, ChronoUnit.DAYS);
    Trip trip = trip("Past trip", start, Visibility.PUBLIC, Status.PUBLISHED);
    stage(trip, "Past day 1", 0, start, true);

    given()
        .when()
        .get(weatherUrl(trip.getSlug()))
        .then()
        .statusCode(200)
        .body("status", equalTo("OUT_OF_RANGE"))
        .body("stages", hasSize(1))
        .body("stages[0].leg.status", equalTo("OUT_OF_RANGE"));
  }
}
