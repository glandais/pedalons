package fr.pedalons.service.route.generator;

import java.util.EnumMap;
import java.util.Map;

/**
 * Counters for the real-data bench. They never influence a result.
 *
 * @param loopCandidates candidates produced by the "out by one side, back by the other" family
 * @param polygonCandidates candidates produced by the polygon family
 * @param validLoop candidates of the loop family that passed every guarantee and the corridor rule
 * @param validPolygon the same for the polygon family
 * @param rejections guarantee violations of the rejected candidates (one count per violation)
 * @param disjointInfeasible turning points without two edge-disjoint paths
 * @param disjointFallbacks turning points solved by the sequential fallback
 * @param walkedTurnRefusals search transitions refused by a window walked across a short state
 * @param disjointJoinRejected loop candidates whose joins with the tails broke the turn rule
 * @param familiarityFallback the per-type familiarity was replaced by the all-kinds one
 */
public record GeneratorDiagnostics(
    int loopCandidates,
    int polygonCandidates,
    int validLoop,
    int validPolygon,
    Map<Violation, Integer> rejections,
    int disjointInfeasible,
    int disjointFallbacks,
    int walkedTurnRefusals,
    int disjointJoinRejected,
    boolean familiarityFallback) {

  static GeneratorDiagnostics empty() {
    return new GeneratorDiagnostics(0, 0, 0, 0, new EnumMap<>(Violation.class), 0, 0, 0, 0, false);
  }
}
