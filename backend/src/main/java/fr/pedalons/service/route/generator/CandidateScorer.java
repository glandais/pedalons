package fr.pedalons.service.route.generator;

import java.util.HashSet;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * Metrics and score of a candidate that already passed {@link RouteGuarantees} (design §5.7).
 * Lower is better.
 *
 * <pre>
 * score = wDistance·distErr + wShared·shared/D + wCrossing·crossings
 *       + wBearing·bearingDev/180 + wFamiliarity·|f − zMean| + wJunction·junctions/10 km
 *       + wCorridor·corridorShare
 * </pre>
 */
final class CandidateScorer {
  private CandidateScorer() {}

  /** A candidate with its guarantee report and score. */
  record Scored(Candidate candidate, GuaranteeReport report, double score) {}

  static Scored score(QueryContext ctx, Candidate candidate, GuaranteeReport report) {
    GeneratorParameters p = ctx.p;
    int[] states = candidate.states();
    double length = report.lengthM();
    double distErr = Math.abs(length - ctx.distanceM) / ctx.distanceM;
    double shared = report.sharedM() / ctx.distanceM;
    Double bearingDev = bearingDeviation(ctx, states);
    double famDev = Math.abs(ctx.familiarity - meanFamiliarity(ctx.g, states, ctx.zSource));
    double junctions = length <= 0 ? 0 : junctionCount(ctx.g, states) / (length / 10_000);
    double corridor = corridorShare(ctx.g, states);
    double score =
        p.wDistance() * distErr
            + p.wShared() * shared
            + p.wCrossing() * report.crossings()
            + p.wBearing() * (bearingDev == null ? 0 : bearingDev / 180)
            + p.wFamiliarity() * famDev
            + p.wJunction() * junctions
            + p.wCorridor() * corridor;
    return new Scored(candidate, report, score);
  }

  /** Length-weighted mean of the normalised familiarity along the route. */
  static double meanFamiliarity(QueryGraph g, int[] states, ZSource source) {
    double sum = 0;
    double total = 0;
    for (int s : states) {
      double len = g.length(s >>> 1);
      sum += len * g.z(s >>> 1, source);
      total += len;
    }
    return total <= 0 ? 0 : sum / total;
  }

  /**
   * Angle between the wished bearing and the bearing from the start to the length-weighted
   * barycentre of the route; null when the bearing does not apply.
   */
  static @Nullable Double bearingDeviation(QueryContext ctx, int[] states) {
    if (!ctx.bearingApplies) {
      return null;
    }
    QueryGraph g = ctx.g;
    double sx = 0;
    double sy = 0;
    double total = 0;
    for (int s : states) {
      double len = g.length(s >>> 1);
      sx += len * (g.nodeX(g.tail(s)) + g.nodeX(g.head(s))) / 2;
      sy += len * (g.nodeY(g.tail(s)) + g.nodeY(g.head(s))) / 2;
      total += len;
    }
    if (total <= 0) {
      return 0.0;
    }
    double bx = sx / total;
    double by = sy / total;
    double x0 = g.nodeX(ctx.start);
    double y0 = g.nodeY(ctx.start);
    if (Math.hypot(bx - x0, by - y0) < 1) {
      return 0.0;
    }
    return Geo.turnAngleDeg(Geo.bearingDeg(x0, y0, bx, by), ctx.bearingDeg);
  }

  /** Interior route nodes where the route could have turned (team degree 3 or more). */
  static int junctionCount(QueryGraph g, int[] states) {
    int count = 0;
    for (int i = 0; i + 1 < states.length; i++) {
      if (g.degree(g.head(states[i])) >= 3) {
        count++;
      }
    }
    return count;
  }

  /**
   * Share of the route (distinct edges) that rides alongside another edge of the same route: both
   * carriageways of a dual carriageway, a path and the road beside it.
   */
  static double corridorShare(QueryGraph g, int[] states) {
    Set<Integer> parents = new HashSet<>();
    Set<Integer> edges = new HashSet<>();
    for (int s : states) {
      edges.add(s >>> 1);
      parents.add(g.parentEdge(s >>> 1));
    }
    double total = 0;
    double doubled = 0;
    for (int e : edges) {
      double len = g.length(e);
      total += len;
      for (int nb : g.corridorNeighbours(e)) {
        if (parents.contains(nb)) {
          doubled += len;
          break;
        }
      }
    }
    return total <= 0 ? 0 : doubled / total;
  }
}
