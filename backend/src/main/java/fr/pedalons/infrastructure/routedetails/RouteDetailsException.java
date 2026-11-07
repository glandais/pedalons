package fr.pedalons.infrastructure.routedetails;

import java.time.Duration;
import org.jspecify.annotations.Nullable;

/**
 * A failed osm-route-details call, classified for its caller (docs/LEDGER_*.md API-150). The
 * message carries the status, the problem {@code code} and its {@code detail}: safe to log, the
 * request is never quoted.
 */
public class RouteDetailsException extends RuntimeException {

  /** What the caller should do about it. */
  public enum Kind {
    /**
     * Down, overloaded, out of time, unreachable (503 {@code data_unavailable} / {@code
     * overloaded}, 504 {@code timeout}, no answer): ask again later, the queue retries.
     */
    TRANSIENT,
    /** No data from any source on the whole route (422 {@code out_of_coverage}): never retried. */
    DEFINITIVE,
    /**
     * A request the service should never have received — invalid input (400), a slice over the
     * bounds (413), a wrong content type (415) — or an answer that cannot be read: a bug of ours
     * or of the service's, logged as an error and never retried.
     */
    BUG
  }

  private final Kind kind;
  private final int status;
  private final @Nullable String code;
  private final @Nullable String detail;
  private final @Nullable Duration retryAfter;

  /**
   * @param status the HTTP status, 0 when there was no answer
   * @param code the problem's {@code code} extension, when the body was a problem
   * @param retryAfter the {@code Retry-After} of a 503, when it was given in seconds
   */
  public RouteDetailsException(
      Kind kind,
      int status,
      @Nullable String code,
      @Nullable String detail,
      @Nullable Duration retryAfter,
      @Nullable Throwable cause) {
    super(message(status, code, detail), cause);
    this.kind = kind;
    this.status = status;
    this.code = code;
    this.detail = detail;
    this.retryAfter = retryAfter;
  }

  private static String message(int status, @Nullable String code, @Nullable String detail) {
    StringBuilder out = new StringBuilder("osm-route-details ");
    out.append(status == 0 ? "unreachable" : "answered " + status);
    if (code != null) {
      out.append(' ').append(code);
    }
    if (detail != null && !detail.isBlank()) {
      out.append(": ").append(detail);
    }
    return out.toString();
  }

  public Kind kind() {
    return kind;
  }

  public boolean isTransient() {
    return kind == Kind.TRANSIENT;
  }

  /** The HTTP status, 0 when the service did not answer (connection refused, read timeout). */
  public int status() {
    return status;
  }

  public @Nullable String code() {
    return code;
  }

  public @Nullable String detail() {
    return detail;
  }

  public @Nullable Duration retryAfter() {
    return retryAfter;
  }
}
