package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.core.JacksonException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.infrastructure.routedetails.RouteDetailsException.Kind;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.Response;
import java.io.IOException;
import java.time.Duration;
import org.jspecify.annotations.Nullable;

/**
 * Reading the RFC 9457 problems of osm-route-details ({@code application/problem+json}, contract
 * §5): {@code status}, {@code detail} and the {@code code} extension, the stable machine code. The
 * status decides first, the code refines it: a body that is not a problem (a proxy's HTML page, an
 * empty 502) is classified on its status alone.
 */
public final class RouteDetailsErrors {

  public static final String DATA_UNAVAILABLE = "data_unavailable";
  public static final String OVERLOADED = "overloaded";
  public static final String TIMEOUT = "timeout";
  public static final String OUT_OF_COVERAGE = "out_of_coverage";
  public static final String ROUTE_TOO_LARGE = "route_too_large";
  public static final String INVALID_INPUT = "invalid_input";

  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
  private static final int MAX_DETAIL = 300;

  private RouteDetailsErrors() {}

  /**
   * The kind of an error status. 503 ({@code data_unavailable}, {@code overloaded}) and 504
   * ({@code timeout}) are transient, and so is a 502: the service restarting behind the shared
   * network. 422 {@code out_of_coverage} is definitive. Everything else — 400, 413 (the slicing
   * missed a bound), 415, 404, 500 — is a bug: retrying the same request would only fail again.
   */
  public static Kind classify(int status, @Nullable String code) {
    if (status == 502 || status == 503 || status == 504) {
      return Kind.TRANSIENT;
    }
    if (status == 422 && (code == null || OUT_OF_COVERAGE.equals(code))) {
      return Kind.DEFINITIVE;
    }
    return Kind.BUG;
  }

  /** The exception for an error answer; its body is read here, whatever it holds. */
  public static RouteDetailsException fromResponse(Response response, @Nullable Throwable cause) {
    int status = response.getStatus();
    String code = null;
    String detail = null;
    String body = body(response);
    if (body != null && !body.isBlank()) {
      try {
        JsonNode problem = OBJECT_MAPPER.readTree(body);
        if (problem != null && problem.isObject()) {
          code = text(problem, "code");
          detail = text(problem, "detail");
        }
      } catch (IOException | RuntimeException e) {
        // Not a problem body: quoted as text, the status alone decides.
        detail = excerpt(body);
      }
    }
    return new RouteDetailsException(
        classify(status, code), status, code, detail, retryAfter(response), cause);
  }

  /**
   * The exception for a call that got no usable answer: refused connection, read timeout (both
   * transient), or a 200 whose JSON cannot be read (a bug: the same answer would come back).
   */
  public static RouteDetailsException noAnswer(Throwable cause) {
    for (Throwable t = cause; t != null; t = t.getCause()) {
      if (t instanceof JacksonException) {
        return new RouteDetailsException(
            Kind.BUG, 200, null, "answer unreadable: " + t.getClass().getSimpleName(), null, cause);
      }
    }
    return new RouteDetailsException(
        Kind.TRANSIENT, 0, null, cause.getClass().getSimpleName(), null, cause);
  }

  private static @Nullable String body(Response response) {
    try {
      return response.hasEntity() ? response.readEntity(String.class) : null;
    } catch (RuntimeException e) {
      // Already consumed or cut short: no reason to lose the status.
      return null;
    }
  }

  private static @Nullable String text(JsonNode node, String field) {
    JsonNode value = node.get(field);
    return value != null && value.isTextual() ? excerpt(value.asText()) : null;
  }

  private static String excerpt(String text) {
    return text.length() <= MAX_DETAIL ? text : text.substring(0, MAX_DETAIL) + "…";
  }

  /** {@code Retry-After} in seconds, the form the service sends; a date is ignored. */
  private static @Nullable Duration retryAfter(Response response) {
    String value = response.getHeaderString(HttpHeaders.RETRY_AFTER);
    if (value == null) {
      return null;
    }
    try {
      long seconds = Long.parseLong(value.trim());
      return seconds >= 0 ? Duration.ofSeconds(seconds) : null;
    } catch (NumberFormatException e) {
      return null;
    }
  }
}
