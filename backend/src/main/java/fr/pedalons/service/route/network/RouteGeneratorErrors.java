package fr.pedalons.service.route.network;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import java.util.Locale;
import org.jspecify.annotations.Nullable;

/**
 * Every answer of the engine as an error code of the API (lot 3b plan §3). Pure.
 *
 * <p>The refusals of the engine stay 400 like the other {@code GENERATOR_*} codes; what is the
 * engine's or the network's fault is 503.
 */
final class RouteGeneratorErrors {
  private RouteGeneratorErrors() {}

  /**
   * The ten reasons of {@code generation_failed} of api 1.9. A reason added on the engine's side
   * is {@link #UNKNOWN} until the switch below says what it is.
   */
  enum Reason {
    START_TOO_FAR,
    END_TOO_FAR,
    DISTANCE_TOO_SHORT,
    NETWORK_TOO_SMALL,
    END_UNREACHABLE,
    NO_WAY_BACK,
    TAIL_TOO_LONG,
    NO_CANDIDATE,
    BUDGET,
    CHECKER_REJECTED,
    UNKNOWN;

    static Reason of(@Nullable String wire) {
      if (wire == null) {
        return UNKNOWN;
      }
      try {
        return valueOf(wire.toUpperCase(Locale.ROOT));
      } catch (IllegalArgumentException e) {
        return UNKNOWN;
      }
    }
  }

  /** An exhaustive switch: a reason added here does not compile until it is mapped. */
  static PedalonsException ofReason(Reason reason) {
    return switch (reason) {
      case START_TOO_FAR -> new BusinessException(ErrorCode.GENERATOR_START_TOO_FAR);
      case END_TOO_FAR -> new BusinessException(ErrorCode.GENERATOR_END_TOO_FAR);
      case DISTANCE_TOO_SHORT -> new BusinessException(ErrorCode.GENERATOR_DISTANCE_TOO_SHORT);
      case NETWORK_TOO_SMALL -> new BusinessException(ErrorCode.GENERATOR_NETWORK_TOO_SMALL);
      case END_UNREACHABLE,
          NO_WAY_BACK,
          TAIL_TOO_LONG,
          NO_CANDIDATE,
          BUDGET,
          CHECKER_REJECTED,
          UNKNOWN ->
          new BusinessException(ErrorCode.GENERATOR_NO_ROUTE);
    };
  }

  static PedalonsException of(RouteGeneratorException e) {
    return switch (e.kind()) {
      case OUT_OF_COVERAGE -> new BusinessException(ErrorCode.GENERATOR_OUT_OF_COVERAGE);
      case GENERATION_FAILED -> ofReason(Reason.of(e.reason()));
      case OVERLAY_REQUIRED -> new BusinessException(ErrorCode.GENERATOR_NETWORK_NOT_READY);
      case OVERLOADED, TIMEOUT, READ_TIMEOUT ->
          new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
      case DATA_UNAVAILABLE,
          NO_ANSWER,
          NOT_CONFIGURED,
          DEPOSIT_IN_PROGRESS,
          INSUFFICIENT_STORAGE,
          UNEXPECTED ->
          new ServiceUnavailableException(ErrorCode.GENERATOR_UNAVAILABLE);
    };
  }

  /** The answers the contract does not promise for a generation: a drift, logged as an error. */
  static boolean isDrift(RouteGeneratorException e) {
    return switch (e.kind()) {
      case DEPOSIT_IN_PROGRESS, INSUFFICIENT_STORAGE, UNEXPECTED -> true;
      default -> false;
    };
  }

  /** The metric label of a failure: a fixed set, never free text. */
  static String outcome(RouteGeneratorException e) {
    return switch (e.kind()) {
      case GENERATION_FAILED -> Reason.of(e.reason()).name().toLowerCase(Locale.ROOT);
      default -> e.kind().name().toLowerCase(Locale.ROOT);
    };
  }
}
