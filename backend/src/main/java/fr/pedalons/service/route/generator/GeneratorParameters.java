package fr.pedalons.service.route.generator;

/**
 * Every search and scoring tunable of the generator (design §5.1). The hard-rule fields are also
 * read by {@link RouteGuarantees}; the others are first guesses to be re-tuned on the real-data
 * bench (plan §9).
 */
public record GeneratorParameters(
    // snapping
    double snapMaxM,
    double snapToNodeM,
    // hard rules
    double maxTurnDeg,
    double tailMaxShare,
    int maxCrossings,
    double distanceTolerance,
    // feasibility
    double distanceTooShortFactor,
    double networkTooSmallFactor,
    double hubMinLengthFactor,
    // direction
    double bearingSectorDeg,
    // weights
    double beta,
    double junctionPenalty,
    double junctionRefM,
    double roadUncertainFactor,
    double gravelUnpavedFactor,
    double gravelMajorRoadFactor,
    double mtbOffroadFactor,
    double mtbMajorRoadFactor,
    int familiarityMinTracks,
    double familiarityMinNearShare,
    double crossingPenaltyM,
    double tailPenaltyPerM,
    // loop family
    int turningPoints,
    double turningRatioMin,
    double turningRatioMax,
    // polygon family
    int polygonEvaluations,
    int polygonViaMin,
    int polygonViaMax,
    double polygonJitterDeg,
    double initialDetour,
    int secantIterations,
    double viaMaxSnapFactor,
    // tails
    int extraTailAnchors,
    // corridor
    double maxCorridorShare,
    // scoring
    double wDistance,
    double wShared,
    double wCrossing,
    double wBearing,
    double wFamiliarity,
    double wJunction,
    double wCorridor,
    // output
    int maxResults,
    double diversityMaxShared) {

  /**
   * Defaults. Two differ from the first guesses of the design (§5.1): {@code networkTooSmallFactor}
   * is 0.9, not 1.5 (a 16 km square holds a 16 km loop, so the road within D/2 only has to hold
   * D·(1 − tolerance), a stricter factor would refuse the very loops the generator finds), and
   * {@code turningRatioMax} is 1.05, not 0.95 (with a distinct end the two disjoint paths need not
   * overlap, so the shortest ways to a turning point can already add up to the core length).
   */
  public static GeneratorParameters defaults() {
    return new GeneratorParameters(
        2000, 30, 150, 0.15, 2, 0.10, 1.05, 0.9, 0.6, 35, 1.0, 0.1, 500, 1.3, 0.75, 1.25, 0.6, 1.4,
        10, 0.5, 2000, 1.0, 16, 0.65, 1.05, 32, 2, 3, 15, 1.3, 3, 0.5, 1, 0.2, 4, 3, 0.15, 1, 1,
        0.02, 2, 3, 0.5);
  }
}
