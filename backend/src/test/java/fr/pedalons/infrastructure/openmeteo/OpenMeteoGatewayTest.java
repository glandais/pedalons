package fr.pedalons.infrastructure.openmeteo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/** Reading Open-Meteo's answer: its two shapes, its holes, and what never reaches a log. */
class OpenMeteoGatewayTest {

  private OpenMeteoGateway gateway;

  /**
   * One location in Paris, over a DST change, as Open-Meteo really answers on 19 October 2026: one
   * offset (+02:00) for the whole window, 26 October included although Paris is then at +01:00.
   */
  private static final String ONE =
      """
      {"latitude":48.85,"longitude":2.35,"elevation":42.0,"utc_offset_seconds":7200,
       "timezone":"Europe/Paris",
       "hourly":{"time":[1792908000,1792911600,1792915200],
                 "temperature_2m":[12.3,12.1,null],
                 "apparent_temperature":[11.0,10.8,10.5],
                 "precipitation_probability":[10,null,30],
                 "precipitation":[0.0,0.1,0.0],
                 "weather_code":[3,61,2],
                 "wind_speed_10m":[14.2,15.0,13.0],
                 "wind_direction_10m":[250,260,270],
                 "wind_gusts_10m":[30.1,null,25.0]},
       "daily":{"time":[1792879200,1792965600],
                "sunrise":[1792908720,1792995180],
                "sunset":[1792946640,1793032920]}}
      """;

  @BeforeEach
  void setUp() {
    gateway = new OpenMeteoGateway();
    gateway.objectMapper = new ObjectMapper();
  }

  @Test
  void parse_oneLocation_isAnObject() {
    List<OpenMeteoForecast> forecasts = gateway.parse(ONE, 1);

    OpenMeteoForecast paris = forecasts.getFirst();
    assertEquals("Europe/Paris", paris.timezone());
    assertEquals(42.0, paris.elevation());
    // The third hour has no temperature: dropped rather than invented.
    assertEquals(2, paris.hours().size());
    assertEquals(Instant.ofEpochSecond(1792908000), paris.hours().getFirst().time());
    assertNull(paris.hours().get(1).precipitationProbability());
    assertNull(paris.hours().get(1).windGusts());
    assertEquals(61, paris.hours().get(1).weatherCode());
  }

  @Test
  void parse_dailyDates_shouldReadTheAnswersOffsetAcrossADstChange() {
    OpenMeteoForecast paris = gateway.parse(ONE, 1).getFirst();

    // 1792879200 = 2026-10-25T00:00+02:00, 1792965600 = 2026-10-26T00:00+02:00. Read in
    // Europe/Paris, the second is 2026-10-25T23:00+01:00: two days on the 25th.
    assertEquals(LocalDate.of(2026, 10, 25), paris.days().getFirst().date());
    assertEquals(LocalDate.of(2026, 10, 26), paris.days().get(1).date());
  }

  @Test
  void parse_severalLocations_isAnArrayInOrder() {
    List<OpenMeteoForecast> forecasts = gateway.parse("[" + ONE + "," + ONE + "]", 2);

    assertEquals(2, forecasts.size());
  }

  @Test
  void parse_aShortAnswer_shouldFailRatherThanMisplaceAForecast() {
    OpenMeteoException e =
        assertThrows(OpenMeteoException.class, () -> gateway.parse("[" + ONE + "]", 2));
    assertFalse(e.isRateLimited());
  }

  @Test
  void parse_anErrorBody_shouldFail() {
    assertThrows(
        OpenMeteoException.class,
        () -> gateway.parse("{\"error\":true,\"reason\":\"Latitude must be in range\"}", 1));
  }

  @Test
  void redact_shouldNeverLetTheKeyThrough() {
    String message =
        OpenMeteoGateway.redact(
            "Connection reset:"
                + " https://customer-api.open-meteo.com/v1/forecast?latitude=1&apikey=SECRET");
    assertFalse(message.contains("SECRET"));
    assertTrue(message.contains("customer-api.open-meteo.com"));
  }
}
