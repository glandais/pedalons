package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException.Kind;
import java.time.Duration;
import org.jspecify.annotations.Nullable;

/**
 * An error answer of the generator as a {@link RouteGeneratorException}: {@code status}, problem
 * {@code code}, {@code details.reason}, {@code details.state}, {@code Retry-After} (lot 3b plan §1).
 * Pure, like {@link RouteDetailsErrors}. A body that is not a problem (a proxy's page) is classed
 * on its status alone.
 */
public final class RouteGeneratorProblems {
  private RouteGeneratorProblems() {}

  /** The longest wait a {@code Retry-After} is believed for. */
  static final Duration MAX_RETRY_AFTER = Duration.ofSeconds(120);

  public static RouteGeneratorException classify(
      int status, byte @Nullable [] body, @Nullable String retryAfterHeader, ObjectMapper mapper) {
    String code = null;
    String reason = null;
    String state = null;
    if (body != null && body.length > 0) {
      try {
        JsonNode root = mapper.readTree(body);
        JsonNode c = root.get("code");
        if (c != null && c.isTextual()) {
          code = safe(c.asText());
        }
        JsonNode details = root.get("details");
        if (details != null && details.isObject()) {
          JsonNode r = details.get("reason");
          if (r != null && r.isTextual()) {
            reason = safe(r.asText());
          }
          JsonNode s = details.get("state");
          if (s != null && s.isTextual()) {
            state = safe(s.asText());
          }
        }
      } catch (Exception e) {
        // not a problem body: the status decides
      }
    }
    return new RouteGeneratorException(
        kind(status, code), status, code, reason, state, retryAfter(retryAfterHeader), null);
  }

  /** The engine's codes are snake_case words; anything else is not echoed into a log line. */
  private static @Nullable String safe(String text) {
    return text.matches("[a-z_]{1,40}") ? text : null;
  }

  static Kind kind(int status, @Nullable String code) {
    if (code != null) {
      switch (code) {
        case "out_of_coverage":
          return Kind.OUT_OF_COVERAGE;
        case "generation_failed":
          return Kind.GENERATION_FAILED;
        case "overlay_required":
          return Kind.OVERLAY_REQUIRED;
        case "overloaded":
          return Kind.OVERLOADED;
        case "timeout":
          return Kind.TIMEOUT;
        case "data_unavailable":
          return Kind.DATA_UNAVAILABLE;
        case "deposit_in_progress":
          return Kind.DEPOSIT_IN_PROGRESS;
        case "insufficient_storage":
          return Kind.INSUFFICIENT_STORAGE;
        default:
          break;
      }
    }
    return switch (status) {
      case 502, 503 -> Kind.DATA_UNAVAILABLE;
      case 504 -> Kind.TIMEOUT;
      case 507 -> Kind.INSUFFICIENT_STORAGE;
      default -> Kind.UNEXPECTED;
    };
  }

  /** Seconds only (the service sends no date); capped, never negative. */
  static @Nullable Duration retryAfter(@Nullable String header) {
    if (header == null) {
      return null;
    }
    try {
      long seconds = Long.parseLong(header.trim());
      if (seconds < 0) {
        return null;
      }
      Duration d = Duration.ofSeconds(seconds);
      return d.compareTo(MAX_RETRY_AFTER) > 0 ? MAX_RETRY_AFTER : d;
    } catch (NumberFormatException e) {
      return null;
    }
  }
}
