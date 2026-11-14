package fr.pedalons.service.route.generator;

/** Graph-builder tunables (design §3.1 and §12.2). */
public record NetworkParameters(
    double nodeMergeM,
    double dedupMeanDistM,
    double dedupLengthRatio,
    int dedupSamples,
    double headingNearM,
    double headingFarM,
    double corridorDistM,
    double corridorMinOverlapM,
    double corridorEndIgnoreM,
    double corridorSampleStepM,
    double minEdgeLengthM,
    double dedupLengthAbsM,
    int dedupMaxMembers,
    double coverageGapM,
    double supportMinCoverM,
    double supportMinCoverShare,
    double contractionMaxTurnDeg) {

  public static NetworkParameters defaults() {
    return new NetworkParameters(
        2.5, 10, 0.03, 16, 30, 50, 25, 200, 30, 10, 1.0, 5, 8, 5, 100, 0.5, 120);
  }
}
