package fr.pedalons.service.route.generator;

import java.util.Arrays;
import java.util.BitSet;
import java.util.function.IntPredicate;
import org.jspecify.annotations.Nullable;

/**
 * Dijkstra / A* over directed edge states (design §4.2).
 *
 * <p>The label of a state is the cost of a path that ends by traversing it completely. Turns and
 * one-ways are enforced while relaxing, never after: the previous state is part of the key, which a
 * node-based search cannot offer. The turn rule applies at every real node and is measured on
 * windows walked along the label's own path ({@link SearchTurns}).
 *
 * <p>Not thread-safe: one instance per thread, arrays reused through a touched list.
 */
final class EdgeDijkstra {
  /**
   * @param backward searches from the targets towards the sources; labels are then costs from the
   *     state to a target, and {@code sourceStates} are the states arriving at the target
   * @param sourceStates first states of a path, weight included in {@code sourceCosts}
   * @param targetState stop at the first settled state matching; null = one-to-all
   * @param bannedEdges query-graph edge ids that cannot be used
   * @param nodePenalty added when a path passes through a node (indexed by query node), or null
   * @param aStarTargetNode node whose Euclidean distance gives the lower bound, or -1; forward
   *     one-to-one only
   * @param aStarFactor lower bound per metre, see {@link #minWeightPerMetre}
   */
  record Request(
      boolean backward,
      int[] sourceStates,
      double[] sourceCosts,
      double[] sourceMetres,
      @Nullable IntPredicate targetState,
      double[] stateWeight,
      @Nullable BitSet bannedEdges,
      double @Nullable [] nodePenalty,
      double costLimit,
      int aStarTargetNode,
      double aStarFactor) {}

  /** Labels of a one-to-all search (copies; valid for any later search). */
  static final class Tree {
    final boolean backward;
    final double[] cost;
    final double[] metres;
    final int[] pred;

    Tree(boolean backward, double[] cost, double[] metres, int[] pred) {
      this.backward = backward;
      this.cost = cost;
      this.metres = metres;
      this.pred = pred;
    }

    boolean reached(int state) {
      return cost[state] < Double.POSITIVE_INFINITY;
    }

    /** States of the path through {@code state}, in travel order. */
    int[] path(int state) {
      return EdgeDijkstra.chain(pred, state, backward);
    }
  }

  /**
   * @param path states in travel order, empty when nothing was found (one-to-one)
   * @param tree non-null for a one-to-all search
   */
  record Result(
      int targetState, double targetCost, double targetMetres, int[] path, @Nullable Tree tree) {
    boolean found() {
      return targetState >= 0;
    }
  }

  private static final int[] NONE = new int[0];

  private final QueryGraph g;
  private final double maxTurnDeg;
  private final int states;
  private final double[] cost;
  private final double[] metres;
  private final int[] pred;
  private final boolean[] settled;

  /** Diagnostics: transitions refused by a walked window across a short state. */
  int walkedTurnRefusals;

  private final IntList touched = new IntList();
  private final MinHeap heap = new MinHeap();

  EdgeDijkstra(QueryGraph g, double maxTurnDeg) {
    this.g = g;
    this.maxTurnDeg = maxTurnDeg;
    this.states = g.stateCount();
    this.cost = new double[states];
    this.metres = new double[states];
    this.pred = new int[states];
    this.settled = new boolean[states];
    Arrays.fill(cost, Double.POSITIVE_INFINITY);
    Arrays.fill(pred, -1);
  }

  /** Lower bound of the weight per metre over the usable states, for A*. */
  static double minWeightPerMetre(QueryGraph g, double[] stateWeight) {
    double min = Double.POSITIVE_INFINITY;
    for (int s = 0; s < g.stateCount(); s++) {
      int e = s >>> 1;
      double len = g.length(e);
      if (g.isMasked(e) || len <= 0 || !g.allowed(s)) {
        continue;
      }
      min = Math.min(min, stateWeight[s] / len);
    }
    return min == Double.POSITIVE_INFINITY ? 0 : min;
  }

  /**
   * May a route ride {@code out} right after {@code in}? Per-edge version of the rule (no history):
   * no reversal, and at a node where the turn rule applies a turn of less than {@code maxTurnDeg}.
   */
  static boolean canTurn(QueryGraph g, int in, int out, double maxTurnDeg) {
    if (out == (in ^ 1) || g.head(in) != g.tail(out) || !g.allowed(out)) {
      return false;
    }
    return !SearchTurns.applies(g, g.head(in))
        || Geo.turnAngleDeg(g.endHeading(in), g.startHeading(out)) < maxTurnDeg;
  }

  private void reset() {
    for (int i = 0; i < touched.size(); i++) {
      int s = touched.get(i);
      cost[s] = Double.POSITIVE_INFINITY;
      pred[s] = -1;
      settled[s] = false;
    }
    touched.clear();
    heap.clear();
  }

  Result search(Request r) {
    reset();
    double[] w = r.stateWeight();
    BitSet banned = r.bannedEdges();
    double[] penalty = r.nodePenalty();
    boolean astar = !r.backward() && r.aStarTargetNode() >= 0 && r.aStarFactor() > 0;
    double tx = astar ? g.nodeX(r.aStarTargetNode()) : 0;
    double ty = astar ? g.nodeY(r.aStarTargetNode()) : 0;
    double factor = r.aStarFactor();

    for (int i = 0; i < r.sourceStates().length; i++) {
      int s = r.sourceStates()[i];
      if (!g.allowed(s) || (banned != null && banned.get(s >>> 1))) {
        continue;
      }
      double c = r.sourceCosts()[i];
      if (c < cost[s]) {
        if (cost[s] == Double.POSITIVE_INFINITY) {
          touched.add(s);
        }
        cost[s] = c;
        metres[s] = r.sourceMetres()[i];
        pred[s] = -1;
        heap.push(c + (astar ? bound(s, tx, ty, factor) : 0), s);
      }
    }

    int found = -1;
    while (!heap.isEmpty()) {
      int s = heap.pop();
      if (settled[s]) {
        continue;
      }
      settled[s] = true;
      if (cost[s] > r.costLimit()) {
        break;
      }
      if (r.targetState() != null && r.targetState().test(s)) {
        found = s;
        break;
      }
      if (r.backward()) {
        relaxBackward(s, w, banned, penalty);
      } else {
        relaxForward(s, w, banned, penalty, astar, tx, ty, factor);
      }
    }

    if (r.targetState() == null) {
      Tree tree = snapshot(r.backward());
      return new Result(-1, Double.POSITIVE_INFINITY, 0, NONE, tree);
    }
    if (found < 0) {
      return new Result(-1, Double.POSITIVE_INFINITY, 0, NONE, null);
    }
    return new Result(found, cost[found], metres[found], chain(pred, found, r.backward()), null);
  }

  private double bound(int s, double tx, double ty, double factor) {
    int h = g.head(s);
    return factor * Math.hypot(g.nodeX(h) - tx, g.nodeY(h) - ty);
  }

  private void relaxForward(
      int s,
      double[] w,
      @Nullable BitSet banned,
      double @Nullable [] penalty,
      boolean astar,
      double tx,
      double ty,
      double factor) {
    int h = g.head(s);
    double pen = penalty == null ? 0 : penalty[h];
    int n = g.outCount(h);
    for (int i = 0; i < n; i++) {
      int s2 = g.outState(h, i);
      if (s2 == (s ^ 1) || !g.allowed(s2) || (banned != null && banned.get(s2 >>> 1))) {
        continue;
      }
      if (!SearchTurns.ok(g, pred, s, s2, maxTurnDeg)) {
        if (SearchTurns.isShort(g, s)) {
          walkedTurnRefusals++;
        }
        continue;
      }
      double c = cost[s] + w[s2] + pen;
      if (c < cost[s2]) {
        if (cost[s2] == Double.POSITIVE_INFINITY) {
          touched.add(s2);
        }
        cost[s2] = c;
        metres[s2] = metres[s] + g.length(s2 >>> 1);
        pred[s2] = s;
        settled[s2] = false;
        heap.push(c + (astar ? bound(s2, tx, ty, factor) : 0), s2);
      }
    }
  }

  private void relaxBackward(
      int s, double[] w, @Nullable BitSet banned, double @Nullable [] penalty) {
    int t = g.tail(s);
    double pen = penalty == null ? 0 : penalty[t];
    int n = g.outCount(t);
    for (int i = 0; i < n; i++) {
      int s0 = g.outState(t, i) ^ 1; // a state arriving at t
      if (s0 == (s ^ 1) || !g.allowed(s0) || (banned != null && banned.get(s0 >>> 1))) {
        continue;
      }
      if (!SearchTurns.okBackward(g, pred, s0, s, maxTurnDeg)) {
        if (SearchTurns.isShort(g, s)) {
          walkedTurnRefusals++;
        }
        continue;
      }
      double c = cost[s] + w[s0] + pen;
      if (c < cost[s0]) {
        if (cost[s0] == Double.POSITIVE_INFINITY) {
          touched.add(s0);
        }
        cost[s0] = c;
        metres[s0] = metres[s] + g.length(s0 >>> 1);
        pred[s0] = s;
        settled[s0] = false;
        heap.push(c, s0);
      }
    }
  }

  private Tree snapshot(boolean backward) {
    double[] c = new double[states];
    double[] m = new double[states];
    int[] p = new int[states];
    Arrays.fill(c, Double.POSITIVE_INFINITY);
    Arrays.fill(p, -1);
    for (int i = 0; i < touched.size(); i++) {
      int s = touched.get(i);
      c[s] = cost[s];
      m[s] = metres[s];
      p[s] = pred[s];
    }
    return new Tree(backward, c, m, p);
  }

  /** Follows {@code pred} from {@code state}; travel order in both directions of search. */
  static int[] chain(int[] pred, int state, boolean backward) {
    IntList list = new IntList();
    for (int s = state; s >= 0; s = pred[s]) {
      list.add(s);
    }
    int[] out = list.toArray();
    if (!backward) {
      for (int i = 0, j = out.length - 1; i < j; i++, j--) {
        int tmp = out[i];
        out[i] = out[j];
        out[j] = tmp;
      }
    }
    return out;
  }
}
