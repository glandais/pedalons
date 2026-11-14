package fr.pedalons.service.route.generator;

import java.util.Arrays;
import java.util.BitSet;
import org.jspecify.annotations.Nullable;

/**
 * Where the core of a route starts and ends, and the tails that join it to the start and the end
 * (design §5.4). The route is {@code tailS + core + tailE}; the core runs from {@code anchorS} to
 * {@code anchorE} and never touches a tail edge (they are in {@link #banned}).
 *
 * <p>The one-to-all searches both families need are computed on first use and shared.
 */
final class AnchorPair {
  final int anchorS;
  final int anchorE;
  final int[] tailS;
  final int[] tailE;
  final double tailLengthM;
  final double coreTargetM;
  final BitSet banned;

  private EdgeDijkstra.@Nullable Tree forward;
  private EdgeDijkstra.@Nullable Tree backward;
  private double @Nullable [] metresFromS;
  private double @Nullable [] metresToE;

  AnchorPair(
      int anchorS,
      int anchorE,
      int[] tailS,
      int[] tailE,
      double tailLengthM,
      double coreTargetM,
      BitSet banned) {
    this.anchorS = anchorS;
    this.anchorE = anchorE;
    this.tailS = tailS;
    this.tailE = tailE;
    this.tailLengthM = tailLengthM;
    this.coreTargetM = coreTargetM;
    this.banned = banned;
  }

  boolean loop() {
    return anchorS == anchorE;
  }

  int lastTailS() {
    return tailS.length == 0 ? -1 : tailS[tailS.length - 1];
  }

  int firstTailE() {
    return tailE.length == 0 ? -1 : tailE[0];
  }

  /** Nodes touched by a tail. */
  BitSet tailNodes(QueryGraph g) {
    BitSet nodes = new BitSet(g.nodeCount());
    for (int[] tail : new int[][] {tailS, tailE}) {
      for (int s : tail) {
        nodes.set(g.tail(s));
        nodes.set(g.head(s));
      }
    }
    return nodes;
  }

  /** Runs the two one-to-all searches once. */
  private void search(QueryContext ctx) {
    if (forward != null) {
      return;
    }
    QueryGraph g = ctx.g;
    IntList sources =
        tailS.length == 0 ? ctx.statesLeaving(anchorS, banned) : ctx.continuations(tailS, banned);
    EdgeDijkstra.Result f =
        ctx.dijkstra.search(
            ctx.forward(sources, null, ctx.weights, banned, null, Double.POSITIVE_INFINITY, -1, 0));
    EdgeDijkstra.Tree fwd = f.tree();
    forward = fwd;

    IntList arriving = new IntList();
    int n = g.outCount(anchorE);
    for (int i = 0; i < n; i++) {
      int s = g.outState(anchorE, i) ^ 1;
      if (g.allowed(s)
          && !banned.get(s >>> 1)
          && (tailE.length == 0 || EdgeDijkstra.canTurn(g, s, firstTailE(), ctx.p.maxTurnDeg()))) {
        arriving.add(s);
      }
    }
    int[] states = arriving.toArray();
    double[] costs = new double[states.length];
    double[] metres = new double[states.length];
    for (int i = 0; i < states.length; i++) {
      costs[i] = ctx.weights[states[i]];
      metres[i] = g.length(states[i] >>> 1);
    }
    EdgeDijkstra.Result b =
        ctx.dijkstra.search(
            new EdgeDijkstra.Request(
                true,
                states,
                costs,
                metres,
                null,
                ctx.weights,
                banned,
                null,
                Double.POSITIVE_INFINITY,
                -1,
                0));
    EdgeDijkstra.Tree bwd = b.tree();
    backward = bwd;

    double[] fromS = new double[g.nodeCount()];
    double[] toE = new double[g.nodeCount()];
    Arrays.fill(fromS, Double.POSITIVE_INFINITY);
    Arrays.fill(toE, Double.POSITIVE_INFINITY);
    for (int s = 0; s < g.stateCount(); s++) {
      if (fwd.reached(s)) {
        int h = g.head(s);
        fromS[h] = Math.min(fromS[h], fwd.metres[s]);
      }
      if (bwd.reached(s)) {
        int t = g.tail(s);
        toE[t] = Math.min(toE[t], bwd.metres[s]);
      }
    }
    metresFromS = fromS;
    metresToE = toE;
  }

  /** Shortest metres from the core's start to a node (arriving at it), infinite if unreached. */
  double metresFromS(QueryContext ctx, int node) {
    search(ctx);
    return java.util.Objects.requireNonNull(metresFromS)[node];
  }

  /** Shortest metres from a node (leaving it) to the core's end, infinite if unreached. */
  double metresToE(QueryContext ctx, int node) {
    search(ctx);
    return java.util.Objects.requireNonNull(metresToE)[node];
  }
}
