package fr.pedalons.infrastructure.routedetails;

import java.time.Duration;
import org.jspecify.annotations.Nullable;

/**
 * A failure of the route generator of osm-route-details, classified (lot 3b plan §1 and §3). The
 * message never carries a key, a team or a coordinate: it holds the status and the problem code
 * only.
 */
public final class RouteGeneratorException extends RuntimeException {

  /** What went wrong, from the point of view of the caller. */
  public enum Kind {
    /** 422 {@code out_of_coverage}. */
    OUT_OF_COVERAGE,
    /** 422 {@code generation_failed}, with a {@link #reason()}. */
    GENERATION_FAILED,
    /** 409 {@code overlay_required}, with a {@link #state()}. */
    OVERLAY_REQUIRED,
    /** 503 {@code overloaded}. */
    OVERLOADED,
    /** 504 {@code timeout}. */
    TIMEOUT,
    /** 503 {@code data_unavailable}, 502, and a 503 that says nothing else. */
    DATA_UNAVAILABLE,
    /** 409 {@code deposit_in_progress}. */
    DEPOSIT_IN_PROGRESS,
    /** 507 {@code insufficient_storage}. */
    INSUFFICIENT_STORAGE,
    /** The service was not reached (refused, reset, no route to it). */
    NO_ANSWER,
    /** The service was reached and did not answer within the read timeout. */
    READ_TIMEOUT,
    /** No key is configured: nothing was sent. */
    NOT_CONFIGURED,
    /**
     * Anything the contract does not promise for the call: 400, 404, 413, 415, 500, an answer that
     * cannot be read. A drift between the two repositories, to be logged as an error.
     */
    UNEXPECTED
  }

  private final Kind kind;
  private final int status;
  private final @Nullable String code;
  private final @Nullable String reason;
  private final @Nullable String state;
  private final @Nullable Duration retryAfter;

  public RouteGeneratorException(
      Kind kind,
      int status,
      @Nullable String code,
      @Nullable String reason,
      @Nullable String state,
      @Nullable Duration retryAfter,
      @Nullable Throwable cause) {
    super(
        "route generator: "
            + kind
            + (status > 0 ? " (HTTP " + status + ")" : "")
            + (code != null ? ", " + code : "")
            + (reason != null ? ", " + reason : ""),
        cause);
    this.kind = kind;
    this.status = status;
    this.code = code;
    this.reason = reason;
    this.state = state;
    this.retryAfter = retryAfter;
  }

  public static RouteGeneratorException of(Kind kind, @Nullable Throwable cause) {
    return new RouteGeneratorException(kind, 0, null, null, null, null, cause);
  }

  public Kind kind() {
    return kind;
  }

  /** The HTTP status, 0 when the service was not reached. */
  public int status() {
    return status;
  }

  /** The problem code ({@code overloaded}, {@code generation_failed}...), when there was one. */
  public @Nullable String code() {
    return code;
  }

  /** {@code details.reason} of a {@code generation_failed}. */
  public @Nullable String reason() {
    return reason;
  }

  /** {@code details.state} of an {@code overlay_required}: {@code absent} or {@code stale}. */
  public @Nullable String state() {
    return state;
  }

  /** {@code Retry-After}, when the service sent one. */
  public @Nullable Duration retryAfter() {
    return retryAfter;
  }
}
