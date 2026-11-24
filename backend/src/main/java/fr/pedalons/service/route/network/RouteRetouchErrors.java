package fr.pedalons.service.route.network;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import java.util.Locale;
import org.jspecify.annotations.Nullable;

/**
 * Every refusal of the engine to a retouch as an error code of the API (docs/plans/2026-11-24-retouche-parcours-lot7c.md
 * §5). Pure. A refusal is an answer, not a failure: shortening is refused almost half of the
 * time, and says {@code ROUTE_RETOUCH_NO_SHORTER}, whatever the engine's reason.
 */
final class RouteRetouchErrors {
  private RouteRetouchErrors() {}

  /**
   * The reasons of {@code generation_failed} of {@code POST /v1/generator/routes/edit} (api 1.17).
   * A reason added on the engine's side is {@link #UNKNOWN} until the switch below says what it is.
   */
  enum EditReason {
    CHANGE_TOO_SMALL,
    CHANGE_TOO_LARGE,
    ROUTE_OFF_COVERAGE,
    ROUTE_MISMATCH,
    ROUTE_NOT_MATCHED,
    ORDER_ANOMALY,
    NO_SEAM,
    END_TOO_FAR,
    END_UNREACHABLE,
    JUNCTION_CUT,
    NO_ECONOMY,
    NO_WINDOW,
    NO_CANDIDATE,
    CHECKER_REJECTED,
    OFF_TARGET,
    BUDGET,
    UNKNOWN;

    static EditReason of(@Nullable String wire) {
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

  /**
   * An exhaustive switch: a reason added here does not compile until it is mapped.
   *
   * @param shortening a {@code resize} that asks for less than the route's length
   */
  static PedalonsException ofReason(EditReason reason, boolean shortening) {
    return switch (reason) {
      case CHANGE_TOO_SMALL -> new BusinessException(ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL);
      case CHANGE_TOO_LARGE -> new BusinessException(ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE);
      case ROUTE_OFF_COVERAGE -> new BusinessException(ErrorCode.GENERATOR_OUT_OF_COVERAGE);
      case ROUTE_NOT_MATCHED, ROUTE_MISMATCH ->
          new BusinessException(ErrorCode.ROUTE_RETOUCH_UNSUPPORTED);
      case ORDER_ANOMALY -> new BusinessException(ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY);
      case END_TOO_FAR -> new BusinessException(ErrorCode.GENERATOR_END_TOO_FAR);
      case NO_ECONOMY -> new BusinessException(ErrorCode.ROUTE_RETOUCH_NO_SHORTER);
      // The reasons that mean "no proposal": a normal answer, the one of shortening above all
      case NO_SEAM,
          END_UNREACHABLE,
          JUNCTION_CUT,
          NO_WINDOW,
          NO_CANDIDATE,
          CHECKER_REJECTED,
          OFF_TARGET,
          BUDGET,
          UNKNOWN ->
          noProposal(reason, shortening);
    };
  }

  private static PedalonsException noProposal(EditReason reason, boolean shortening) {
    if (shortening) {
      return new BusinessException(ErrorCode.ROUTE_RETOUCH_NO_SHORTER);
    }
    return switch (reason) {
      case NO_SEAM -> new BusinessException(ErrorCode.ROUTE_RETOUCH_UNSUPPORTED);
      case END_UNREACHABLE, JUNCTION_CUT ->
          new BusinessException(ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE);
      default -> new BusinessException(ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL);
    };
  }

  static PedalonsException of(RouteGeneratorException e, boolean shortening) {
    // A body or a document the engine refuses (413, 400) is refused again as often as it is sent:
    // not a breakdown to retry
    if (e.kind() == RouteGeneratorException.Kind.UNEXPECTED
        && (e.status() == 400 || e.status() == 413)) {
      return new BusinessException(ErrorCode.ROUTE_RETOUCH_UNSUPPORTED);
    }
    return switch (e.kind()) {
      case OUT_OF_COVERAGE -> new BusinessException(ErrorCode.GENERATOR_OUT_OF_COVERAGE);
      case GENERATION_FAILED -> ofReason(EditReason.of(e.reason()), shortening);
      case OVERLOADED, TIMEOUT, READ_TIMEOUT ->
          new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
      case DATA_UNAVAILABLE,
          OVERLAY_REQUIRED,
          NO_ANSWER,
          NOT_CONFIGURED,
          DEPOSIT_IN_PROGRESS,
          INSUFFICIENT_STORAGE,
          UNEXPECTED ->
          new ServiceUnavailableException(ErrorCode.GENERATOR_UNAVAILABLE);
    };
  }

  /** The answers the contract does not promise for an edit: a drift, logged as an error. */
  static boolean isDrift(RouteGeneratorException e) {
    return switch (e.kind()) {
      case OVERLAY_REQUIRED, DEPOSIT_IN_PROGRESS, INSUFFICIENT_STORAGE, UNEXPECTED -> true;
      default -> false;
    };
  }

  /** The engine says a track it should have matched does not match: the stored document lies. */
  static boolean isStaleDocument(RouteGeneratorException e) {
    return e.kind() == RouteGeneratorException.Kind.GENERATION_FAILED
        && EditReason.of(e.reason()) == EditReason.ROUTE_MISMATCH;
  }

  /** The metric label of a failure: a fixed set, never free text. */
  static String outcome(RouteGeneratorException e) {
    return switch (e.kind()) {
      case GENERATION_FAILED -> EditReason.of(e.reason()).name().toLowerCase(Locale.ROOT);
      default -> e.kind().name().toLowerCase(Locale.ROOT);
    };
  }
}
