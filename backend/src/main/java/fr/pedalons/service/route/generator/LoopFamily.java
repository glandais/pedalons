package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * "Out by one side, back by the other" (design §5.5, plan §5.2): for a series of turning points T,
 * two edge-disjoint paths from T to the two anchors, found together by {@link EdgeDisjointPaths}.
 *
 * <p>T may be any node of degree 2 or more: the design restricts it to junctions, but then a square
 * with its only junction taken by the anchor (a start on a branch) would have no turning point at
 * all. Turning at a degree-2 node is not a U-turn, the route simply goes on.
 *
 * <p>T is chosen so that the shortest way A_S → T plus T → A_E is close to the core length (a band
 * below 1 because the second disjoint path is longer than the shortest one) and, when the bearing
 * applies, within the bearing sector. The band places T on the S–E ellipse when no bearing does.
 */
final class LoopFamily {
  /** More turning points are tried, up to this multiple of the budget, while none fits the distance. */
  private static final int EXTRA_FACTOR = 4;

  private LoopFamily() {}

  static List<Candidate> candidates(QueryContext ctx, AnchorPair pair, int budget) {
    QueryGraph g = ctx.g;
    GeneratorParameters p = ctx.p;
    double dc = pair.coreTargetM;
    List<Integer> eligible = new ArrayList<>();
    List<double[]> outside = new ArrayList<>(); // node, distance of the ratio to the band
    for (int t = 0; t < g.nodeCount(); t++) {
      if (g.degree(t) < 2 || g.dangling(t) || t == pair.anchorS || t == pair.anchorE) {
        continue;
      }
      // two edge-disjoint paths from t back to the anchor exist only inside its 2-edge-connected
      // component: a node beyond a bridge costs two full-graph searches for nothing
      if (pair.loop() && g.component(t) != g.component(pair.anchorS)) {
        continue;
      }
      double out = pair.metresFromS(ctx, t);
      double back = pair.metresToE(ctx, t);
      if (out == Double.POSITIVE_INFINITY || back == Double.POSITIVE_INFINITY) {
        continue;
      }
      if (ctx.bearingApplies
          && Geo.turnAngleDeg(ctx.bearingToNode(t), ctx.bearingDeg) > p.bearingSectorDeg()) {
        continue;
      }
      double ratio = (out + back) / dc;
      if (ratio >= p.turningRatioMin() && ratio <= p.turningRatioMax() && out >= 0.2 * dc) {
        eligible.add(t);
      } else {
        double gap =
            ratio < p.turningRatioMin()
                ? p.turningRatioMin() - ratio
                : Math.max(ratio - p.turningRatioMax(), 0.2 - out / dc);
        outside.add(new double[] {t, gap});
      }
    }
    int maxEvaluations = budget * EXTRA_FACTOR;
    Collections.shuffle(eligible, ctx.rnd);
    // When the band holds too few nodes (a cycle whose two sides are very unequal, for instance),
    // the nearest ones to the band fill the budget: the checker still has the last word.
    outside.sort((x, y) -> x[1] != y[1] ? Double.compare(x[1], y[1]) : Double.compare(x[0], y[0]));
    for (double[] o : outside) {
      if (eligible.size() >= maxEvaluations) {
        break;
      }
      eligible.add((int) o[0]);
    }

    List<Candidate> out = new ArrayList<>();
    int evaluated = 0;
    boolean fits = false;
    for (int t : eligible) {
      if (evaluated >= maxEvaluations || (evaluated >= budget && fits)) {
        break;
      }
      evaluated++;
      EdgeDisjointPaths.Solution core =
          ctx.disjoint.solve(
              t, pair.anchorS, pair.anchorE, pair.tailS, pair.tailE, ctx.weights, pair.banned);
      if (core != null) {
        int[] states = QueryContext.concat(pair.tailS, core.core(), pair.tailE);
        if (!SearchTurns.pathOk(g, states, 0, states.length, p.maxTurnDeg())) {
          ctx.disjointJoinRejected++;
          continue;
        }
        out.add(new Candidate(states, Candidate.Family.LOOP));
        fits |= ctx.withinTolerance(ctx.length(states));
      }
    }
    ctx.loopCandidates += out.size();
    return out;
  }
}
