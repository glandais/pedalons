package fr.pedalons.service.route.network;

import java.util.HashMap;
import java.util.Map;

/**
 * What the team graph is made of, for the answer and for the details of {@code
 * GENERATOR_NETWORK_TOO_SMALL}.
 *
 * @param routeCount routes counted: not excluded, with at least one track, every track current
 * @param pendingRouteCount routes not excluded with a track that has no current document yet (the
 *     analysis is still running): the network is {@code incomplete}
 * @param excludedRouteCount routes ticked "ne pas utiliser pour générer des parcours"
 * @param totalLengthM length of the whole graph, in metres
 * @param droppedEdges stored edges that could not be used
 */
public record TeamNetworkSummary(
    int routeCount,
    int pendingRouteCount,
    int excludedRouteCount,
    double totalLengthM,
    int droppedEdges) {

  public boolean incomplete() {
    return pendingRouteCount > 0;
  }

  /** Counts the routes while the tracks stream by. Routes without a track never show up. */
  static final class Tally {
    private final Map<Long, boolean[]> routes = new HashMap<>(); // [excluded, pending]

    void track(long routeId, boolean excluded, boolean current) {
      boolean[] state = routes.computeIfAbsent(routeId, id -> new boolean[] {excluded, false});
      if (!current) {
        state[1] = true;
      }
    }

    TeamNetworkSummary build(double totalLengthM, int droppedEdges) {
      int counted = 0;
      int pending = 0;
      int excluded = 0;
      for (boolean[] s : routes.values()) {
        if (s[0]) {
          excluded++;
        } else if (s[1]) {
          pending++;
        } else {
          counted++;
        }
      }
      return new TeamNetworkSummary(counted, pending, excluded, totalLengthM, droppedEdges);
    }
  }
}
