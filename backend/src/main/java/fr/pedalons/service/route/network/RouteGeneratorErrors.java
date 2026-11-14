package fr.pedalons.service.route.network;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.RouteGeneratorNetworkDetails;
import fr.pedalons.service.route.generator.GeneratorFailure;

/** The engine's failures as the {@code GENERATOR_*} error codes (docs/LEDGER_*.md API-198, lot 3). */
final class RouteGeneratorErrors {
  private RouteGeneratorErrors() {}

  /** An exhaustive switch: a new {@link GeneratorFailure} does not compile until it is mapped. */
  static BusinessException of(GeneratorFailure failure, TeamNetworkSummary network) {
    return switch (failure) {
      case START_TOO_FAR -> new BusinessException(ErrorCode.GENERATOR_START_TOO_FAR);
      case END_TOO_FAR -> new BusinessException(ErrorCode.GENERATOR_END_TOO_FAR);
      case DISTANCE_TOO_SHORT -> new BusinessException(ErrorCode.GENERATOR_DISTANCE_TOO_SHORT);
      case NETWORK_TOO_SMALL -> networkTooSmall(network);
      case NO_ROUTE -> new BusinessException(ErrorCode.GENERATOR_NO_ROUTE);
    };
  }

  /** Also the answer to an empty graph, which the engine would call "start too far". */
  static BusinessException networkTooSmall(TeamNetworkSummary network) {
    return new BusinessException(
        ErrorCode.GENERATOR_NETWORK_TOO_SMALL,
        new RouteGeneratorNetworkDetails(
            network.routeCount(),
            network.pendingRouteCount(),
            network.excludedRouteCount(),
            network.totalLengthM(),
            network.incomplete()),
        null);
  }
}
