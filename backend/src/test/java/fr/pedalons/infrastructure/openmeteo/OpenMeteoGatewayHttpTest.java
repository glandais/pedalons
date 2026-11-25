package fr.pedalons.infrastructure.openmeteo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.sun.net.httpserver.HttpServer;
import fr.pedalons.AbstractBaseTest;
import fr.pedalons.infrastructure.openmeteo.OpenMeteoGateway.Location;
import io.quarkus.rest.client.reactive.QuarkusRestClientBuilder;
import io.quarkus.test.junit.QuarkusTest;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/**
 * {@link OpenMeteoGateway} through a real {@link OpenMeteoClient} against a local HTTP server: what
 * {@code OpenMeteoClientTest}, with its mocked client, cannot see — the REST client's own handling
 * of an error status. Its default exception mapper turns any status >= 400 into a {@code
 * WebApplicationException} before the gateway reads the {@code Response}; a 429 must still come out
 * rate-limited, or the worker backs off by minutes against a spent quota.
 *
 * <p>The client is built programmatically, so the default mapper stays on here whatever {@code
 * quarkus.rest-client.open-meteo.disable-default-mapper} says: the gateway must cope on its own.
 */
@QuarkusTest
class OpenMeteoGatewayHttpTest extends AbstractBaseTest {

  private HttpServer server;
  private OpenMeteoGateway gateway;

  private int status;
  private String body = "";

  @BeforeEach
  void start() throws IOException {
    server = HttpServer.create(new InetSocketAddress(InetAddress.getLoopbackAddress(), 0), 0);
    server.createContext(
        "/",
        exchange -> {
          byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
          exchange.getResponseHeaders().add("Content-Type", "application/json");
          exchange.sendResponseHeaders(status, bytes.length == 0 ? -1 : bytes.length);
          try (OutputStream out = exchange.getResponseBody()) {
            out.write(bytes);
          }
        });
    server.start();
    gateway = new OpenMeteoGateway();
    gateway.client =
        QuarkusRestClientBuilder.newBuilder()
            .baseUri(URI.create("http://127.0.0.1:" + server.getAddress().getPort()))
            .build(OpenMeteoClient.class);
    gateway.objectMapper = new ObjectMapper();
    gateway.enabled = true;
    gateway.apiKey = Optional.empty();
  }

  @AfterEach
  void stop() {
    server.stop(0);
  }

  private void answer(int status, String body) {
    this.status = status;
    this.body = body;
  }

  @Test
  void a429_shouldBeRateLimited() {
    answer(
        429,
        "{\"error\":true,\"reason\":\"Minutely API request limit exceeded. Please try again in one"
            + " minute.\"}");

    OpenMeteoException e =
        assertThrows(
            OpenMeteoException.class,
            () -> gateway.forecast(List.of(new Location(45.75, 4.85, null))));

    assertTrue(e.isRateLimited(), e.getMessage());
    assertTrue(e.getMessage().contains("Minutely API request limit"), e.getMessage());
  }

  @Test
  void a5xx_shouldBeAnOrdinaryFailure_withItsStatus() {
    answer(502, "");

    OpenMeteoException e =
        assertThrows(
            OpenMeteoException.class,
            () -> gateway.forecast(List.of(new Location(45.75, 4.85, null))));

    assertFalse(e.isRateLimited());
    assertTrue(e.getMessage().contains("502"), e.getMessage());
  }

  @Test
  void a200_shouldBeRead() {
    answer(
        200,
        """
        {"latitude":45.75,"longitude":4.85,"elevation":170,"utc_offset_seconds":7200,
         "timezone":"Europe/Paris",
         "hourly":{"time":[1791266400],"temperature_2m":[12.3],"apparent_temperature":[11.0],
                   "precipitation_probability":[10],"precipitation":[0.0],"weather_code":[3],
                   "wind_speed_10m":[14.2],"wind_direction_10m":[250],"wind_gusts_10m":[30.1]},
         "daily":{"time":[1791237600],"sunrise":[1791265200],"sunset":[1791306000]}}
        """);

    List<OpenMeteoForecast> forecasts = gateway.forecast(List.of(new Location(45.75, 4.85, null)));

    assertEquals(1, forecasts.size());
    assertEquals(1, forecasts.getFirst().hours().size());
  }
}
