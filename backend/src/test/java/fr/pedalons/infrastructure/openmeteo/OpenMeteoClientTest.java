package fr.pedalons.infrastructure.openmeteo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/**
 * The request {@link OpenMeteoGateway} sends through {@link OpenMeteoClient}, and what it makes of
 * the provider's answers — the REST client mocked, as in {@code GeocodingLookupTest}, so nothing
 * here reaches the network.
 *
 * <p>A plain unit test rather than a {@code @QuarkusTest}: the weather is disabled in the test
 * profile ({@code %test.pedalons.weather.enabled=false}), which the gateway honours by refusing every
 * request — the very guard tested last here.
 */
class OpenMeteoClientTest {

  private static final String LOCATION =
      """
      {"latitude":45.75,"longitude":4.85,"elevation":%s,"utc_offset_seconds":7200,
       "timezone":"Europe/Paris",
       "hourly":{"time":[1791266400,1791270000],
                 "temperature_2m":[12.3,12.1],
                 "apparent_temperature":[11.0,10.8],
                 "precipitation_probability":[10,20],
                 "precipitation":[0.0,0.1],
                 "weather_code":[3,61],
                 "wind_speed_10m":[14.2,15.0],
                 "wind_direction_10m":[250,260],
                 "wind_gusts_10m":[30.1,31.0]},
       "daily":{"time":[1791237600],"sunrise":[1791265200],"sunset":[1791306000]}}
      """;

  private OpenMeteoClient client;
  private OpenMeteoGateway gateway;

  @BeforeEach
  void setUp() {
    client = mock(OpenMeteoClient.class);
    gateway = new OpenMeteoGateway();
    gateway.client = client;
    gateway.objectMapper = new ObjectMapper();
    gateway.enabled = true;
    gateway.apiKey = Optional.empty();
  }

  private static String location(double elevation) {
    return LOCATION.formatted(elevation);
  }

  /** A mocked answer: an outbound {@code Response} cannot be read back as a client one. */
  private static Response answer(int status, String body) {
    Response response = mock(Response.class);
    when(response.getStatus()).thenReturn(status);
    when(response.hasEntity()).thenReturn(!body.isEmpty());
    when(response.readEntity(String.class)).thenReturn(body);
    return response;
  }

  private void answers(Response response) {
    when(client.forecast(
            anyString(),
            anyString(),
            any(),
            anyString(),
            anyString(),
            anyString(),
            anyString(),
            anyInt(),
            anyString(),
            anyString(),
            anyString(),
            any()))
        .thenReturn(response);
  }

  @Test
  void forecast_oneLocation_shouldSendTheAgreedParametersAndReadAnObject() {
    answers(answer(200, location(170)));

    List<OpenMeteoForecast> forecasts = gateway.forecast(List.of(new Location(45.75, 4.85, null)));

    assertEquals(1, forecasts.size());
    assertEquals("Europe/Paris", forecasts.getFirst().timezone());
    assertEquals(2, forecasts.getFirst().hours().size());
    assertEquals(1, forecasts.getFirst().days().size());
    verify(client)
        .forecast(
            eq("45.7500"),
            eq("4.8500"),
            isNull(), // no elevation: the provider's own model decides
            eq(OpenMeteoGateway.HOURLY),
            eq("sunrise,sunset"),
            eq("auto"),
            eq("unixtime"),
            eq(8),
            eq("kmh"),
            eq("best_match"),
            eq("land"),
            isNull()); // free plan: no apikey parameter at all
  }

  @Test
  void forecast_severalLocations_shouldSendListsAndReadAnArrayInOrder() {
    answers(answer(200, "[" + location(300) + "," + location(400) + "]"));

    List<OpenMeteoForecast> forecasts =
        gateway.forecast(List.of(new Location(45.75, 4.85, 300.0), new Location(45.8, 4.9, 400.0)));

    assertEquals(2, forecasts.size());
    assertEquals(300.0, forecasts.get(0).elevation());
    assertEquals(400.0, forecasts.get(1).elevation());
    verify(client)
        .forecast(
            eq("45.7500,45.8000"),
            eq("4.8500,4.9000"),
            eq("300,400"),
            anyString(),
            anyString(),
            anyString(),
            anyString(),
            anyInt(),
            anyString(),
            anyString(),
            anyString(),
            isNull());
  }

  @Test
  void forecast_anObjectForTwoLocations_shouldFailRatherThanMisplaceAForecast() {
    answers(answer(200, location(300)));

    OpenMeteoException e =
        assertThrows(
            OpenMeteoException.class,
            () ->
                gateway.forecast(
                    List.of(new Location(45.75, 4.85, 300.0), new Location(45.8, 4.9, 400.0))));

    assertFalse(e.isRateLimited());
    assertTrue(e.getMessage().contains("1 location(s) for 2"));
  }

  @Test
  void forecast_aLongerArray_shouldFailToo() {
    answers(answer(200, "[" + location(300) + "," + location(300) + "]"));

    assertThrows(
        OpenMeteoException.class,
        () -> gateway.forecast(List.of(new Location(45.75, 4.85, 300.0))));
  }

  @Test
  void forecast_a429_shouldBeRateLimited() {
    answers(
        answer(
            429,
            "{\"error\":true,\"reason\":\"Daily API request limit exceeded. Please try again"
                + " tomorrow.\"}"));

    OpenMeteoException e =
        assertThrows(
            OpenMeteoException.class,
            () -> gateway.forecast(List.of(new Location(45.75, 4.85, null))));

    assertTrue(e.isRateLimited());
    assertTrue(e.getMessage().contains("Daily API request limit exceeded"));
  }

  @Test
  void forecast_a429RaisedByTheClientsDefaultMapper_shouldStillBeRateLimited() {
    Response response = answer(429, "{\"error\":true,\"reason\":\"Minutely API request limit\"}");
    when(client.forecast(
            anyString(),
            anyString(),
            any(),
            anyString(),
            anyString(),
            anyString(),
            anyString(),
            anyInt(),
            anyString(),
            anyString(),
            anyString(),
            any()))
        .thenThrow(new WebApplicationException("Too Many Requests, status code 429", response));

    OpenMeteoException e =
        assertThrows(
            OpenMeteoException.class,
            () -> gateway.forecast(List.of(new Location(45.75, 4.85, null))));

    assertTrue(e.isRateLimited());
    assertTrue(e.getMessage().contains("Minutely API request limit"), e.getMessage());
  }

  @Test
  void forecast_a5xx_shouldBeAnOrdinaryFailure() {
    answers(answer(502, "Bad Gateway"));

    OpenMeteoException e =
        assertThrows(
            OpenMeteoException.class,
            () -> gateway.forecast(List.of(new Location(45.75, 4.85, null))));

    assertFalse(e.isRateLimited());
    assertTrue(e.getMessage().contains("502"));
  }

  @Test
  void forecast_anErrorBodyWith200_shouldFail() {
    answers(answer(200, "{\"error\":true,\"reason\":\"Cannot initialize WeatherVariable\"}"));

    assertThrows(
        OpenMeteoException.class, () -> gateway.forecast(List.of(new Location(45.75, 4.85, null))));
  }

  @Test
  void forecast_withAKey_shouldSendItButNeverQuoteIt() {
    gateway.apiKey = Optional.of("SECRET-KEY");
    when(client.forecast(
            anyString(),
            anyString(),
            any(),
            anyString(),
            anyString(),
            anyString(),
            anyString(),
            anyInt(),
            anyString(),
            anyString(),
            anyString(),
            eq("SECRET-KEY")))
        .thenThrow(
            new ProcessingException(
                "Connect timed out: https://customer-api.open-meteo.com/v1/forecast"
                    + "?latitude=45.75&apikey=SECRET-KEY"));

    OpenMeteoException e =
        assertThrows(
            OpenMeteoException.class,
            () -> gateway.forecast(List.of(new Location(45.75, 4.85, null))));

    assertFalse(e.isRateLimited());
    assertFalse(e.getMessage().contains("SECRET-KEY"), e.getMessage());
    assertFalse(e.getMessage().contains("latitude="), e.getMessage());
  }

  @Test
  void forecast_aBlankKey_isTheFreePlan() {
    gateway.apiKey = Optional.of("  ");
    answers(answer(200, location(170)));

    gateway.forecast(List.of(new Location(45.75, 4.85, null)));

    verify(client)
        .forecast(
            anyString(),
            anyString(),
            any(),
            anyString(),
            anyString(),
            anyString(),
            anyString(),
            anyInt(),
            anyString(),
            anyString(),
            anyString(),
            isNull());
  }

  @Test
  void forecast_mixingLocationsWithAndWithoutElevation_isRefusedBeforeAnyCall() {
    assertThrows(
        IllegalArgumentException.class,
        () ->
            gateway.forecast(
                List.of(new Location(45.75, 4.85, 300.0), new Location(45.8, 4.9, null))));

    verifyNoInteractions(client);
  }

  @Test
  void forecast_noLocation_isNoCall() {
    assertTrue(gateway.forecast(List.of()).isEmpty());

    verifyNoInteractions(client);
  }

  @Test
  void forecast_whileDisabled_shouldNeverReachTheProvider() {
    gateway.enabled = false;

    OpenMeteoException e =
        assertThrows(
            OpenMeteoException.class,
            () -> gateway.forecast(List.of(new Location(45.75, 4.85, null))));

    assertFalse(e.isRateLimited());
    verify(client, never())
        .forecast(
            anyString(),
            anyString(),
            any(),
            anyString(),
            anyString(),
            anyString(),
            anyString(),
            anyInt(),
            anyString(),
            anyString(),
            anyString(),
            any());
  }

  @Test
  void forecast_anHourPastTheModelHorizon_isDroppedNotInvented() {
    answers(
        answer(
            200,
            """
            {"latitude":45.75,"longitude":4.85,"timezone":"Europe/Paris",
             "hourly":{"time":[1791266400,1791270000],
                       "temperature_2m":[12.3,null],"apparent_temperature":[11.0,null],
                       "precipitation_probability":[null,null],"precipitation":[0.0,null],
                       "weather_code":[3,null],"wind_speed_10m":[14.2,null],
                       "wind_direction_10m":[250,null],"wind_gusts_10m":[null,null]},
             "daily":{"time":[],"sunrise":[],"sunset":[]}}
            """));

    OpenMeteoForecast forecast =
        gateway.forecast(List.of(new Location(45.75, 4.85, null))).getFirst();

    assertEquals(1, forecast.hours().size());
    assertNull(forecast.hours().getFirst().precipitationProbability());
    assertNull(forecast.hours().getFirst().windGusts());
    assertNull(forecast.elevation());
  }
}
