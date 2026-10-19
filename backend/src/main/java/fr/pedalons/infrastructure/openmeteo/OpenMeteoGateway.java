package fr.pedalons.infrastructure.openmeteo;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.stream.Collectors;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jspecify.annotations.Nullable;

/**
 * The forecast request, and the reading of its answer.
 *
 * <p>Three things the REST client cannot do alone:
 *
 * <ul>
 *   <li><b>One location is an object, several are an array</b>, in the order asked. The answer is
 *       read as a tree and its length checked against the request: a short answer would otherwise
 *       store one place's weather under another's cell.
 *   <li><b>A 429 is not an ordinary failure</b>: it says the day's (or the minute's) quota is spent,
 *       and the worker waits for the next full hour rather than backing off by minutes. The
 *       client's default mapper is off for this client ({@code disable-default-mapper}), and a
 *       {@code WebApplicationException} it would still throw is read like the answer it carries:
 *       otherwise a 429 would surface as an ordinary failure.
 *   <li><b>The API key never reaches a log</b>: it travels as a query parameter, so no message built
 *       here quotes the URL, and the client's own exception messages are redacted.
 * </ul>
 *
 * <p>Refuses everything while {@code pedalons.weather.enabled} is false — the tests, so that nothing
 * there can reach the network; they mock this bean instead.
 */
@ApplicationScoped
public class OpenMeteoGateway {

  /** What Open-Meteo's CC BY 4.0 licence asks every display to credit. */
  public static final String ATTRIBUTION_NAME = "Open-Meteo.com";

  public static final String ATTRIBUTION_URL = "https://open-meteo.com/";

  static final String HOURLY =
      "temperature_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,"
          + "wind_speed_10m,wind_direction_10m,wind_gusts_10m";
  static final String DAILY = "sunrise,sunset";

  /** Seven days of horizon plus the length of the longest ride, and the end of the last day. */
  static final int FORECAST_DAYS = 8;

  @ConfigProperty(name = "pedalons.weather.enabled", defaultValue = "true")
  boolean enabled;

  @ConfigProperty(name = "pedalons.weather.api-key")
  Optional<String> apiKey;

  @Inject @RestClient OpenMeteoClient client;
  @Inject ObjectMapper objectMapper;

  /** A place to forecast. All the locations of one request have an elevation, or none has. */
  public record Location(double latitude, double longitude, @Nullable Double elevation) {}

  public boolean isEnabled() {
    return enabled;
  }

  /**
   * The forecasts of {@code locations}, in the same order.
   *
   * @throws OpenMeteoException on any failure, the request never half-read
   */
  public List<OpenMeteoForecast> forecast(List<Location> locations) {
    if (!enabled) {
      throw new OpenMeteoException("Weather disabled (pedalons.weather.enabled=false)", false);
    }
    if (locations.isEmpty()) {
      return List.of();
    }
    boolean withElevation = locations.getFirst().elevation() != null;
    if (locations.stream().anyMatch(l -> (l.elevation() != null) != withElevation)) {
      throw new IllegalArgumentException("Locations with and without elevation in one request");
    }
    String latitudes = join(locations, l -> coordinate(l.latitude()));
    String longitudes = join(locations, l -> coordinate(l.longitude()));
    String elevations =
        withElevation
            ? join(locations, l -> String.format(Locale.ROOT, "%.0f", l.elevation()))
            : null;

    Response response;
    try {
      response =
          client.forecast(
              latitudes,
              longitudes,
              elevations,
              HOURLY,
              DAILY,
              "auto",
              "unixtime",
              FORECAST_DAYS,
              "kmh",
              "best_match",
              "land",
              apiKey.filter(k -> !k.isBlank()).orElse(null));
    } catch (WebApplicationException e) {
      // A status >= 400 mapped by the REST client: the answer is still there, read as any other.
      response = e.getResponse();
      if (response == null) {
        throw new OpenMeteoException(
            "Open-Meteo request failed: WebApplicationException " + redact(e.getMessage()), false);
      }
    } catch (ProcessingException e) {
      throw new OpenMeteoException("Open-Meteo unreachable: " + redact(e.getMessage()), false);
    } catch (RuntimeException e) {
      throw new OpenMeteoException(
          "Open-Meteo request failed: "
              + e.getClass().getSimpleName()
              + " "
              + redact(e.getMessage()),
          false);
    }
    try (Response answer = response) {
      int status = answer.getStatus();
      String body = body(answer, status);
      if (status == 429) {
        throw new OpenMeteoException("Open-Meteo rate limit (429): " + reason(body), true);
      }
      if (status / 100 != 2) {
        throw new OpenMeteoException("Open-Meteo answered " + status + ": " + reason(body), false);
      }
      return parse(body, locations.size());
    } catch (ProcessingException e) {
      throw new OpenMeteoException(
          "Open-Meteo answer unreadable: " + redact(e.getMessage()), false);
    }
  }

  /**
   * The answer's body. On an error status a body that cannot be read — already consumed by a mapper,
   * cut short — is no reason to lose the status: it is read as empty.
   */
  private static String body(Response response, int status) {
    if (status / 100 == 2) {
      return response.hasEntity() ? response.readEntity(String.class) : "";
    }
    try {
      return response.hasEntity() ? response.readEntity(String.class) : "";
    } catch (RuntimeException e) {
      return "";
    }
  }

  List<OpenMeteoForecast> parse(String body, int expected) {
    JsonNode root;
    try {
      root = objectMapper.readTree(body);
    } catch (Exception e) {
      throw new OpenMeteoException("Open-Meteo answer is not JSON", false);
    }
    if (root == null) {
      throw new OpenMeteoException("Open-Meteo answer is empty", false);
    }
    if (root.isObject() && root.path("error").asBoolean(false)) {
      throw new OpenMeteoException("Open-Meteo error: " + reason(body), false);
    }
    List<JsonNode> nodes = new ArrayList<>();
    if (root.isArray()) {
      root.forEach(nodes::add);
    } else if (root.isObject()) {
      nodes.add(root);
    }
    if (nodes.size() != expected) {
      throw new OpenMeteoException(
          "Open-Meteo returned " + nodes.size() + " location(s) for " + expected, false);
    }
    List<OpenMeteoForecast> forecasts = new ArrayList<>(expected);
    for (JsonNode node : nodes) {
      forecasts.add(parseLocation(node));
    }
    return forecasts;
  }

  private static OpenMeteoForecast parseLocation(JsonNode node) {
    String timezone = node.hasNonNull("timezone") ? node.get("timezone").asText() : null;
    // Open-Meteo shifts the whole answer by today's offset, DST changes in the window included.
    ZoneOffset offset = ZoneOffset.ofTotalSeconds(node.path("utc_offset_seconds").asInt(0));

    JsonNode hourly = node.path("hourly");
    JsonNode times = hourly.path("time");
    List<OpenMeteoForecast.Hour> hours = new ArrayList<>(times.size());
    for (int i = 0; i < times.size(); i++) {
      Double temperature = number(hourly, "temperature_2m", i);
      Double apparent = number(hourly, "apparent_temperature", i);
      Double precipitation = number(hourly, "precipitation", i);
      Double code = number(hourly, "weather_code", i);
      Double windSpeed = number(hourly, "wind_speed_10m", i);
      Double windDirection = number(hourly, "wind_direction_10m", i);
      if (!times.get(i).isNumber()
          || temperature == null
          || apparent == null
          || precipitation == null
          || code == null
          || windSpeed == null
          || windDirection == null) {
        // Past the model's horizon the arrays carry nulls: no hour rather than a made-up one.
        continue;
      }
      Double probability = number(hourly, "precipitation_probability", i);
      hours.add(
          new OpenMeteoForecast.Hour(
              Instant.ofEpochSecond(times.get(i).asLong()),
              temperature,
              apparent,
              probability == null ? null : (int) Math.round(probability),
              precipitation,
              (int) Math.round(code),
              windSpeed,
              windDirection,
              number(hourly, "wind_gusts_10m", i)));
    }

    JsonNode daily = node.path("daily");
    JsonNode dates = daily.path("time");
    List<OpenMeteoForecast.Day> days = new ArrayList<>(dates.size());
    for (int i = 0; i < dates.size(); i++) {
      if (!dates.get(i).isNumber()) {
        continue;
      }
      // With timeformat=unixtime a date is its midnight at the answer's single offset, not in the
      // location's zone: past a DST change the zone would put it at 23:00 the day before, and two
      // days on one date make the daily upsert fail (21000) and the whole batch with it.
      LocalDate date = LocalDate.ofInstant(Instant.ofEpochSecond(dates.get(i).asLong()), offset);
      days.add(
          new OpenMeteoForecast.Day(date, epoch(daily, "sunrise", i), epoch(daily, "sunset", i)));
    }

    return new OpenMeteoForecast(
        node.path("latitude").asDouble(),
        node.path("longitude").asDouble(),
        node.hasNonNull("elevation") ? node.get("elevation").asDouble() : null,
        timezone,
        hours,
        days);
  }

  private static @Nullable Double number(JsonNode block, String field, int i) {
    JsonNode value = block.path(field).path(i);
    return value.isNumber() ? value.asDouble() : null;
  }

  private static @Nullable Instant epoch(JsonNode block, String field, int i) {
    JsonNode value = block.path(field).path(i);
    // A polar day or night has no sunrise; Open-Meteo then sends 0 or null.
    return value.isNumber() && value.asLong() > 0 ? Instant.ofEpochSecond(value.asLong()) : null;
  }

  private static String join(
      List<Location> locations, java.util.function.Function<Location, String> part) {
    return locations.stream().map(part).collect(Collectors.joining(","));
  }

  private static String coordinate(double degrees) {
    return String.format(Locale.ROOT, "%.4f", degrees);
  }

  /** The {@code reason} of an Open-Meteo error body, else a short excerpt of it. */
  private String reason(String body) {
    try {
      JsonNode node = objectMapper.readTree(body);
      if (node != null && node.hasNonNull("reason")) {
        return redact(node.get("reason").asText());
      }
    } catch (Exception e) {
      // Not JSON: quoted as text below.
    }
    return redact(body.length() <= 200 ? body : body.substring(0, 200));
  }

  /** Drops anything that looks like a query string or a key from a message. */
  public static String redact(@Nullable String message) {
    if (message == null) {
      return "";
    }
    String redacted = message.replaceAll("(?i)apikey=[^&\\s]*", "apikey=***");
    return redacted.replaceAll("\\?[^\\s]*", "?…");
  }
}
