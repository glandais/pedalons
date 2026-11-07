package fr.pedalons.api.gpx;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoCircuitBreaker;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.weather.WeatherCellRepository;
import fr.pedalons.service.weather.WeatherFetchWorker;
import fr.pedalons.service.weather.WeatherPlanner;
import fr.pedalons.service.weather.WeatherTestFixtures;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.Response;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code GET /api/gpx-previews/{id}/weather} (docs/LEDGER_*.md API-149): who may read it, the state
 * it answers in, the speed it assumes, and its caching headers. Like the ride's, the endpoint only
 * reads the cache; the cache-filling tests go through the planner and the worker, the provider
 * mocked.
 */
@QuarkusTest
class GpxPreviewWeatherResourceTest extends AbstractResourceTest {

  private static final Set<String> COORDINATE_KEYS =
      Set.of("lat", "lon", "lng", "latitude", "longitude", "coordinates", "geometry");

  @Inject WeatherPlanner planner;
  @Inject WeatherFetchWorker worker;
  @Inject GpxPreviewRepository previewRepository;
  @Inject WeatherCellRepository cellRepository;
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

  // ------------------------------------------------------------------ helpers

  private GpxPreview preview(Domain owner, User creator, Instant departure, Float speed) {
    return dataService.createGpxPreview(
        owner,
        creator,
        UUID.randomUUID(),
        WeatherTestFixtures.northbound(
            WeatherTestFixtures.LYON_LAT, WeatherTestFixtures.LYON_LON, 30, 170),
        1L,
        departure,
        departure == null ? null : "Europe/Paris",
        speed);
  }

  private GpxPreview preview(Instant departure, Float speed) {
    return preview(domain, user1, departure, speed);
  }

  private static Instant tomorrow() {
    return Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
  }

  private void fill() {
    planner.plan(Instant.now());
    worker.fetchDue();
  }

  private static String url(GpxPreview preview) {
    return "/api/gpx-previews/" + preview.getPublicId() + "/weather";
  }

  private void setSpeed(GpxPreview preview, Float speed) {
    QuarkusTransaction.requiringNew()
        .run(() -> previewRepository.findById(preview.getId()).setAverageSpeed(speed));
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

  // ------------------------------------------------------------------ states

  @Test
  void weather_withoutADate_isOutOfRange() {
    GpxPreview preview = preview(null, 30f);

    given()
        .when()
        .get(url(preview))
        .then()
        .statusCode(200)
        .body("status", equalTo("OUT_OF_RANGE"))
        .body("departure.status", equalTo("OUT_OF_RANGE"))
        .body("legs", empty());
  }

  @Test
  void weather_ofADatePast_isOutOfRange() {
    GpxPreview preview = preview(Instant.now().minus(2, ChronoUnit.HOURS), null);

    given()
        .when()
        .get(url(preview))
        .then()
        .statusCode(200)
        .body("status", equalTo("OUT_OF_RANGE"))
        .body("legs", empty());
  }

  @Test
  void weather_eightDaysAhead_isNotYetAvailable_untilSevenDaysBefore() {
    Instant departure = Instant.now().plus(8, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    GpxPreview preview = preview(departure, null);

    String availableFrom =
        given()
            .when()
            .get(url(preview))
            .then()
            .statusCode(200)
            .header("Cache-Control", equalTo("private, no-cache"))
            .body("status", equalTo("NOT_YET_AVAILABLE"))
            .body("legs", empty())
            .extract()
            .path("availableFrom");

    assertEquals(departure.minus(7, ChronoUnit.DAYS), Instant.parse(availableFrom));
  }

  @Test
  void weather_inTheWindowWithAnEmptyCache_isUnavailable_notCached_andCallsNoProvider() {
    GpxPreview preview = preview(tomorrow(), null);

    given()
        .when()
        .get(url(preview))
        .then()
        .statusCode(200)
        .header("Cache-Control", equalTo("no-store"))
        .header("ETag", org.hamcrest.Matchers.nullValue())
        .body("status", equalTo("UNAVAILABLE"));

    verify(gateway, never()).forecast(anyList());
  }

  @Test
  void weather_withoutAnyPoint_hasNoLocation() {
    GpxPreview preview =
        dataService.createGpxPreview(
            domain, user1, UUID.randomUUID(), List.of(), 1L, tomorrow(), "Europe/Paris", null);

    given().when().get(url(preview)).then().statusCode(200).body("status", equalTo("NO_LOCATION"));
  }

  // ------------------------------------------------------------------ forecast

  @Test
  void weather_withoutASpeed_assumesTheDefaultOne_asOneLegWithoutGroup() throws Exception {
    GpxPreview preview = preview(tomorrow(), null);
    fill();

    Response response =
        given()
            .when()
            .get(url(preview))
            .then()
            .statusCode(200)
            .header("Cache-Control", equalTo("private, no-cache"))
            .header("ETag", notNullValue())
            .body("status", equalTo("OK"))
            .body("departure.status", equalTo("OK"))
            .body("legs", hasSize(1))
            .body("legs[0]", not(hasKey("groupId")))
            .body("legs[0].speedIsDefault", equalTo(true))
            .body("legs[0].averageSpeed", equalTo(25.0f))
            .body("legs[0].checkpoints", hasSize(3))
            .body("attribution.name", equalTo("Open-Meteo.com"))
            .extract()
            .response();

    List<String> keys = new ArrayList<>();
    collectKeys(objectMapper.readTree(response.asString()), "$", keys);
    List<String> leaks =
        keys.stream()
            .filter(
                k ->
                    COORDINATE_KEYS.contains(
                        k.substring(k.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT)))
            .toList();
    assertTrue(leaks.isEmpty(), "leaks coordinates: " + leaks);
  }

  @Test
  void weather_withASpeed_usesIt_andTimesThePassagesWithIt() {
    Instant departure = tomorrow();
    GpxPreview preview = preview(departure, 30f);
    fill();

    String arrival =
        given()
            .when()
            .get(url(preview))
            .then()
            .statusCode(200)
            .body("status", equalTo("OK"))
            .body("legs[0].speedIsDefault", equalTo(false))
            .body("legs[0].averageSpeed", equalTo(30.0f))
            .extract()
            .path("legs[0].arrivalTime");

    // 30 km at 30 km/h
    assertEquals(departure.plus(1, ChronoUnit.HOURS), Instant.parse(arrival));
  }

  @Test
  void weather_revalidates_andAChangedSpeedChangesTheETag() {
    GpxPreview preview = preview(tomorrow(), 25f);
    fill();
    String etag = given().when().get(url(preview)).then().statusCode(200).extract().header("ETag");

    given()
        .header("If-None-Match", etag)
        .when()
        .get(url(preview))
        .then()
        .statusCode(304)
        .header("ETag", equalTo(etag));

    setSpeed(preview, 30f);
    fill();
    String changed =
        given().when().get(url(preview)).then().statusCode(200).extract().header("ETag");
    assertNotEquals(etag, changed);
  }

  // ------------------------------------------------------------------ access

  @Test
  void weather_isReadByAnonymousHoldersOfTheLink_andByMembers() {
    GpxPreview preview = preview(tomorrow(), null);

    given().when().get(url(preview)).then().statusCode(200);
    given().auth().oauth2(getAccessToken(USER4)).when().get(url(preview)).then().statusCode(200);
  }

  @Test
  void weather_ofAnUnknownOrMalformedIdentifier_isNotFound() {
    given()
        .when()
        .get("/api/gpx-previews/" + UUID.randomUUID() + "/weather")
        .then()
        .statusCode(404);
    given().when().get("/api/gpx-previews/not-a-uuid/weather").then().statusCode(404);
  }

  @Test
  void weather_ofAPreviewOfAnotherDomain_isNotFound() {
    Domain other = dataService.createDomain("club.example", "Club", "https://club.example");
    User stranger = dataService.createUser(other, "rider@club.example", "Rider");
    GpxPreview preview = preview(other, stranger, tomorrow(), null);

    given().when().get(url(preview)).then().statusCode(404);
  }
}
