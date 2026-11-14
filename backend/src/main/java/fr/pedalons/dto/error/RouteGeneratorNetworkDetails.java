package fr.pedalons.dto.error;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.eclipse.microprofile.openapi.annotations.media.Schema;

/**
 * What the team's route generator network is made of, sent with {@code GENERATOR_NETWORK_TOO_SMALL}
 * so that the site can tell a network too small from one still being analysed (docs/LEDGER_*.md
 * API-198, lot 3). Lengths in metres.
 */
@RequiredArgsConstructor
@Getter
public class RouteGeneratorNetworkDetails implements ErrorDetails {
  @Schema(description = "Type", required = true)
  final ErrorCode type = ErrorCode.GENERATOR_NETWORK_TOO_SMALL;

  @Schema(description = "Routes the network is made of", required = true)
  final int routeCount;

  @Schema(
      description = "Routes whose roads are still being analysed and are not in the network yet",
      required = true)
  final int pendingRouteCount;

  @Schema(
      description = "Routes ticked \"ne pas utiliser pour générer des parcours\"",
      required = true)
  final int excludedRouteCount;

  @Schema(description = "Length of the whole network of the team, in metres", required = true)
  final double totalLengthM;

  @Schema(
      description = "True when pendingRouteCount is above zero: the network may still grow",
      required = true)
  final boolean incomplete;
}
