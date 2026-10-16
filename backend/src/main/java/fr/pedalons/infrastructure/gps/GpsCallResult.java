package fr.pedalons.infrastructure.gps;

import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

/**
 * The outcome of one route call to a GPS service (create, update, delete), with what the caller
 * needs to decide what comes next — which {@link RouteUploadResult} loses, keeping only a message.
 * docs/LEDGER_*.md API-120.
 */
public sealed interface GpsCallResult {

  /** Done. {@code externalId}: the service's id of the route, when it returned one. */
  record Ok(@Nullable String externalId) implements GpsCallResult {}

  /** 404 or 410: the route is not (or no longer) at the service — the user deleted it there. */
  record NotFound() implements GpsCallResult {}

  /** 401: the token is refused. Worth one refresh, then a reconnection. */
  record Unauthorized() implements GpsCallResult {}

  /** 412 (Garmin): the user withdrew the course permission. Only a reconnection fixes it. */
  record PermissionRevoked() implements GpsCallResult {}

  /** 429: no call to this service for this user before {@code retryAt}. */
  record RateLimited(Instant retryAt) implements GpsCallResult {}

  /**
   * Anything else.
   *
   * @param status the HTTP status, 0 when no response came (network, unreadable GPX)
   */
  record Failed(int status, String message) implements GpsCallResult {}

  /** When a 429 carries no usable {@code Retry-After}. */
  Duration DEFAULT_RATE_LIMIT_PAUSE = Duration.ofMinutes(15);

  /** The result of a response that is not a 2xx. */
  static GpsCallResult ofFailure(HttpResponse<?> response) {
    int status = response.statusCode();
    return switch (status) {
      case 401 -> new Unauthorized();
      case 404, 410 -> new NotFound();
      case 412 -> new PermissionRevoked();
      case 429 -> new RateLimited(retryAt(response.headers().firstValue("Retry-After")));
      default -> new Failed(status, "HTTP " + status);
    };
  }

  /** {@code Retry-After} in seconds; an HTTP date or nothing falls back on the default pause. */
  static Instant retryAt(Optional<String> retryAfter) {
    Instant now = Instant.now();
    if (retryAfter.isPresent()) {
      try {
        long seconds = Long.parseLong(retryAfter.get().trim());
        if (seconds > 0) {
          return now.plusSeconds(seconds);
        }
      } catch (NumberFormatException e) {
        // An HTTP date: rare enough not to parse.
      }
    }
    return now.plus(DEFAULT_RATE_LIMIT_PAUSE);
  }

  static boolean isSuccess(HttpResponse<?> response) {
    return response.statusCode() >= 200 && response.statusCode() < 300;
  }

  /** The manual upload's answer, which only knows success or a message. */
  default RouteUploadResult toUploadResult() {
    return switch (this) {
      case Ok ok -> RouteUploadResult.success(ok.externalId());
      case NotFound n -> RouteUploadResult.failure("Upload failed: 404");
      case Unauthorized u -> RouteUploadResult.failure("Upload failed: 401");
      case PermissionRevoked p -> RouteUploadResult.failure("Upload failed: 412");
      case RateLimited r -> RouteUploadResult.failure("Upload failed: 429");
      case Failed f ->
          RouteUploadResult.failure(
              "Upload failed: " + (f.status() > 0 ? Integer.toString(f.status()) : f.message()));
    };
  }
}
