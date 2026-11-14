package fr.pedalons.service.route.generator;

import java.util.Arrays;
import java.util.BitSet;
import org.jspecify.annotations.Nullable;

/**
 * Two edge-disjoint paths from a turning point T to the two anchors, Suurballe on the split line
 * graph (design §4.3, plan §5.2).
 *
 * <p>The route goes S → A_S, then back from A_S to T by the first path reversed, then T → A_E by
 * the second, then to E. A virtual sink τ joined to A_S (σS) and A_E (σE) makes the loop case
 * (A_S = A_E, capacity 2 on σS→τ) the same computation as the S ≠ E case.
 *
 * <p>The graph L′ is implicit. Each state s is split into in(s) and out(s) joined by a unit-capacity
 * arc of cost w[s]; out(s) reaches in(s′) at cost 0 for every legal transition. Two Dijkstra passes
 * with <em>truncated</em> potentials π = min(dist₁, D₁) keep the reduced costs of the residual
 * graph non-negative even though pass 1 stops when τ is settled.
 *
 * <p>What the flow does not model is checked afterwards, and a failure falls back to a sequential
 * "shortest path, then shortest path with the first banned": one-ways on either side (the flow rides a
 * state if either of its directions is allowed, the route rides the S side backwards), the same edge used in both directions by
 * the two paths (capacity is per state, not per undirected edge), and the turn at T.
 *
 * <p>Not thread-safe; arrays are reused across calls.
 */
final class EdgeDisjointPaths {

  /** A core route from A_S to A_E through T, in travel order; tails are not included. */
  record Solution(int[] core, boolean fallback) {}

  /** Diagnostics counters for the bench. */
  int calls;

  int infeasible;
  int postCheckFailures;

  /** Solutions refused because a turn of tail + core + tail, on walked windows, was illegal. */
  int joinRejected;

  int fallbacks;

  private final QueryGraph g;
  private final double maxTurnDeg;
  private final int stateCount;
  private final int base4;
  private final int sigT;
  private final int sigS;
  private final int sigE;
  private final int tau;
  private final int vertexCount;

  private double[] dist1;
  private int[] pred1;
  private boolean[] settled1;
  private final IntList touched1 = new IntList();
  private double[] dist2;
  private int[] pred2;
  private boolean[] settled2;
  private final IntList touched2 = new IntList();
  private int[] succ1;
  private int[] pred1on;
  private final IntList touchedP1 = new IntList();
  private int[] succ2;
  private final IntList touchedP2 = new IntList();
  private final MinHeap heap = new MinHeap();

  private int[] arcTo = new int[64];
  private double[] arcCost = new double[64];

  private @Nullable EdgeDijkstra dijkstra;

  // per-call context
  private int turning;
  private int anchorS;
  private int anchorE;
  private int lastTailS;
  private int firstTailE;
  private double[] w = new double[0];
  private @Nullable BitSet banned;
  private boolean loop;

  EdgeDisjointPaths(QueryGraph g, double maxTurnDeg) {
    this.g = g;
    this.maxTurnDeg = maxTurnDeg;
    this.stateCount = g.stateCount();
    this.base4 = 2 * stateCount;
    this.sigT = base4;
    this.sigS = base4 + 1;
    this.sigE = base4 + 2;
    this.tau = base4 + 3;
    this.vertexCount = base4 + 4;
  }

  /** The arrays are allocated on the first solve: a request that never uses the flow pays nothing. */
  private void ensure() {
    if (dist1 != null) {
      return;
    }
    dist1 = new double[vertexCount];
    dist2 = new double[vertexCount];
    pred1 = new int[vertexCount];
    pred2 = new int[vertexCount];
    settled1 = new boolean[vertexCount];
    settled2 = new boolean[vertexCount];
    succ1 = new int[vertexCount];
    succ2 = new int[vertexCount];
    pred1on = new int[vertexCount];
    Arrays.fill(dist1, Double.POSITIVE_INFINITY);
    Arrays.fill(dist2, Double.POSITIVE_INFINITY);
    Arrays.fill(pred1, -1);
    Arrays.fill(pred2, -1);
    Arrays.fill(succ1, -1);
    Arrays.fill(succ2, -1);
    Arrays.fill(pred1on, -1);
  }

  /**
   * @param tailS states from S to {@code anchorS}, in route order (possibly empty)
   * @param tailE states from {@code anchorE} to E, in route order (possibly empty)
   * @param w weight per state
   * @param banned query edge ids that cannot be used (tails included)
   * @return the core from {@code anchorS} to {@code anchorE} through T, or null
   */
  @Nullable Solution solve(
      int t,
      int anchorS,
      int anchorE,
      int[] tailS,
      int[] tailE,
      double[] w,
      @Nullable BitSet banned) {
    calls++;
    ensure();
    if (t == anchorS || t == anchorE) {
      return null;
    }
    this.turning = t;
    this.anchorS = anchorS;
    this.anchorE = anchorE;
    this.lastTailS = tailS.length == 0 ? -1 : tailS[tailS.length - 1];
    this.firstTailE = tailE.length == 0 ? -1 : tailE[0];
    this.w = w;
    this.banned = banned;
    this.loop = anchorS == anchorE;

    int[][] paths = flow();
    if (paths == null) {
      infeasible++;
      return null;
    }
    int[] core = null;
    if (loop) {
      core = assemble(paths[0], paths[1]);
      if (core == null) {
        core = assemble(paths[1], paths[0]);
      }
    } else {
      core = assemble(paths[0], paths[1]); // paths[0] ends at σS, paths[1] at σE
    }
    if (core != null && !joinsOk(core, tailS, tailE)) {
      joinRejected++;
      core = null;
    }
    if (core != null) {
      return new Solution(core, false);
    }
    postCheckFailures++;
    fallbacks++;
    int[] seq = sequential();
    if (seq != null && !joinsOk(seq, tailS, tailE)) {
      joinRejected++;
      seq = null;
    }
    return seq == null ? null : new Solution(seq, true);
  }

  // ---- implicit arcs of L′ --------------------------------------------------------------------

  private boolean usable(int s) {
    return g.allowed(s) && (banned == null || !banned.get(s >>> 1));
  }

  private boolean sideSOk(int s) {
    return g.allowed(s ^ 1)
        && (lastTailS < 0 || EdgeDijkstra.canTurn(g, lastTailS, s ^ 1, maxTurnDeg));
  }

  private boolean sideEOk(int s) {
    return g.allowed(s) && (firstTailE < 0 || EdgeDijkstra.canTurn(g, s, firstTailE, maxTurnDeg));
  }

  /**
   * A state the flow may ride. The flow does not know which of the two paths becomes the S side
   * (ridden backwards by the route) and which the E side, so a state counts if either of its two
   * directions is allowed; {@link #assemble} then checks the real directions.
   */
  private boolean flowUsable(int s) {
    return (g.allowed(s) || g.allowed(s ^ 1)) && (banned == null || !banned.get(s >>> 1));
  }

  private void addArc(int k, int to, double cost) {
    if (k == arcTo.length) {
      arcTo = Arrays.copyOf(arcTo, k * 2);
      arcCost = Arrays.copyOf(arcCost, k * 2);
    }
    arcTo[k] = to;
    arcCost[k] = cost;
  }

  /** Fills {@code arcTo}/{@code arcCost} with the arcs leaving {@code v}; returns their count. */
  private int arcs(int v) {
    int k = 0;
    if (v < base4) {
      int s = v >> 1;
      if ((v & 1) == 0) {
        if (flowUsable(s)) {
          addArc(k++, v + 1, w[s]);
        }
      } else {
        int h = g.head(s);
        boolean checked = SearchTurns.applies(g, h);
        double inHeading = g.endHeading(s);
        int n = g.outCount(h);
        for (int i = 0; i < n; i++) {
          int s2 = g.outState(h, i);
          if (s2 == (s ^ 1) || !flowUsable(s2)) {
            continue;
          }
          if (checked && Geo.turnAngleDeg(inHeading, g.startHeading(s2)) >= maxTurnDeg) {
            continue;
          }
          addArc(k++, 2 * s2, 0);
        }
        if (h == anchorS && (sideSOk(s) || (loop && sideEOk(s)))) {
          addArc(k++, sigS, 0);
        }
        if (!loop && h == anchorE && sideEOk(s)) {
          addArc(k++, sigE, 0);
        }
      }
    } else if (v == sigT) {
      int n = g.outCount(turning);
      for (int i = 0; i < n; i++) {
        int s = g.outState(turning, i);
        if (flowUsable(s)) {
          addArc(k++, 2 * s, 0);
        }
      }
    } else if (v == sigS || v == sigE) {
      addArc(k++, tau, 0);
    }
    return k;
  }

  // ---- Suurballe ------------------------------------------------------------------------------

  private void resetPass1() {
    for (int i = 0; i < touched1.size(); i++) {
      int v = touched1.get(i);
      dist1[v] = Double.POSITIVE_INFINITY;
      pred1[v] = -1;
      settled1[v] = false;
    }
    touched1.clear();
    for (int i = 0; i < touchedP1.size(); i++) {
      int v = touchedP1.get(i);
      succ1[v] = -1;
      pred1on[v] = -1;
    }
    touchedP1.clear();
  }

  private void resetPass2() {
    for (int i = 0; i < touched2.size(); i++) {
      int v = touched2.get(i);
      dist2[v] = Double.POSITIVE_INFINITY;
      pred2[v] = -1;
      settled2[v] = false;
    }
    touched2.clear();
    for (int i = 0; i < touchedP2.size(); i++) {
      succ2[touchedP2.get(i)] = -1;
    }
    touchedP2.clear();
  }

  /** Returns the two vertex-level paths ending at σS and σE (or both at σS in a loop). */
  private int @Nullable [][] flow() {
    resetPass1();
    resetPass2();
    // pass 1
    heap.clear();
    dist1[sigT] = 0;
    touched1.add(sigT);
    heap.push(0, sigT);
    double d1 = Double.POSITIVE_INFINITY;
    while (!heap.isEmpty()) {
      int v = heap.pop();
      if (settled1[v]) {
        continue;
      }
      settled1[v] = true;
      if (v == tau) {
        d1 = dist1[v];
        break;
      }
      int k = arcs(v);
      for (int i = 0; i < k; i++) {
        int to = arcTo[i];
        double nd = dist1[v] + arcCost[i];
        if (nd < dist1[to]) {
          if (dist1[to] == Double.POSITIVE_INFINITY) {
            touched1.add(to);
          }
          dist1[to] = nd;
          pred1[to] = v;
          heap.push(nd, to);
        }
      }
    }
    if (d1 == Double.POSITIVE_INFINITY) {
      return null;
    }
    for (int v = tau; v != sigT; v = pred1[v]) {
      int p = pred1[v];
      succ1[p] = v;
      pred1on[v] = p;
      touchedP1.add(p);
      touchedP1.add(v);
    }

    // pass 2 on the residual graph, reduced costs
    heap.clear();
    dist2[sigT] = 0;
    touched2.add(sigT);
    heap.push(0, sigT);
    boolean reached = false;
    while (!heap.isEmpty()) {
      int v = heap.pop();
      if (settled2[v]) {
        continue;
      }
      settled2[v] = true;
      if (v == tau) {
        reached = true;
        break;
      }
      double piV = Math.min(dist1[v], d1);
      int k = arcs(v);
      for (int i = 0; i < k; i++) {
        int to = arcTo[i];
        if (succ1[v] == to && !(loop && v == sigS && to == tau)) {
          continue; // saturated by P1
        }
        double reduced = Math.max(0, arcCost[i] + piV - Math.min(dist1[to], d1));
        relax2(v, to, reduced);
      }
      int back = pred1on[v];
      if (back >= 0) {
        relax2(v, back, 0);
      }
    }
    if (!reached) {
      return null;
    }
    // P2 and cancellation
    for (int v = tau; v != sigT; v = pred2[v]) {
      int x = pred2[v];
      if (succ1[v] == x) {
        succ1[v] = -2; // P2 undoes this P1 arc
      } else {
        succ2[x] = v;
        touchedP2.add(x);
      }
    }
    int[] starts = new int[2];
    int found = 0;
    if (succ1[sigT] >= 0) {
      starts[found++] = succ1[sigT];
    }
    if (succ2[sigT] >= 0) {
      starts[found++] = succ2[sigT];
    }
    if (found != 2) {
      return null;
    }
    int[][] result = new int[2][];
    int[] ends = new int[2];
    for (int i = 0; i < 2; i++) {
      IntList states = new IntList();
      int v = starts[i];
      int guard = 0;
      while (v != sigS && v != sigE) {
        if (v < base4 && (v & 1) == 0) {
          states.add(v >> 1);
        }
        int next = succ1[v] >= 0 ? succ1[v] : succ2[v];
        if (next < 0 || ++guard > vertexCount) {
          return null;
        }
        v = next;
      }
      result[i] = states.toArray();
      ends[i] = v;
    }
    if (loop) {
      return ends[0] == sigS && ends[1] == sigS ? result : null;
    }
    if (ends[0] == sigS && ends[1] == sigE) {
      return result;
    }
    if (ends[0] == sigE && ends[1] == sigS) {
      return new int[][] {result[1], result[0]};
    }
    return null;
  }

  private void relax2(int from, int to, double reduced) {
    double nd = dist2[from] + reduced;
    if (nd < dist2[to]) {
      if (dist2[to] == Double.POSITIVE_INFINITY) {
        touched2.add(to);
      }
      dist2[to] = nd;
      pred2[to] = from;
      heap.push(nd, to);
    }
  }

  /** Every turn of {@code tailS + core + tailE} on walked windows, the flow having no history. */
  private boolean joinsOk(int[] core, int[] tailS, int[] tailE) {
    int[] all = QueryContext.concat(tailS, core, tailE);
    return SearchTurns.pathOk(g, all, 0, all.length, maxTurnDeg);
  }

  // ---- post-checks ----------------------------------------------------------------------------

  /** Builds the core from the S-side flow path (towards T) and the E-side one; null if illegal. */
  private int @Nullable [] assemble(int[] sPath, int[] ePath) {
    if (sPath.length == 0 || ePath.length == 0) {
      return null;
    }
    int[] core = new int[sPath.length + ePath.length];
    for (int i = 0; i < sPath.length; i++) {
      int s = sPath[sPath.length - 1 - i] ^ 1;
      if (!g.allowed(s)) {
        return null; // one-way on the S side
      }
      core[i] = s;
    }
    for (int s : ePath) {
      if (!g.allowed(s)) {
        return null; // one-way on the E side: the flow also rides states allowed only backwards
      }
    }
    System.arraycopy(ePath, 0, core, sPath.length, ePath.length);
    java.util.HashSet<Integer> edges = new java.util.HashSet<>();
    for (int s : core) {
      if (!edges.add(s >>> 1)) {
        return null; // an edge used twice, e.g. in both directions
      }
    }
    if (!EdgeDijkstra.canTurn(g, core[sPath.length - 1], core[sPath.length], maxTurnDeg)) {
      return null;
    }
    // the joins with the tails: the flow only knows one side of each (review M3)
    if (lastTailS >= 0 && !EdgeDijkstra.canTurn(g, lastTailS, core[0], maxTurnDeg)) {
      return null;
    }
    if (firstTailE >= 0
        && !EdgeDijkstra.canTurn(g, core[core.length - 1], firstTailE, maxTurnDeg)) {
      return null;
    }
    return core;
  }

  // ---- fallback -------------------------------------------------------------------------------

  private @Nullable EdgeDijkstra search() {
    if (dijkstra == null) {
      dijkstra = new EdgeDijkstra(g, maxTurnDeg);
    }
    return dijkstra;
  }

  private int @Nullable [] sequential() {
    EdgeDijkstra d = search();
    // E leg: T -> A_E
    IntList src = new IntList();
    int n = g.outCount(turning);
    for (int i = 0; i < n; i++) {
      int s = g.outState(turning, i);
      if (usable(s)) {
        src.add(s);
      }
    }
    EdgeDijkstra.Result e = d.search(request(src, s -> g.head(s) == anchorE && sideEOk(s), banned));
    if (!e.found()) {
      return null;
    }
    BitSet ban = banned == null ? new BitSet() : (BitSet) banned.clone();
    for (int s : e.path()) {
      ban(ban, s >>> 1);
    }
    // S leg: A_S -> T, arriving compatibly with the first E state
    IntList src2 = new IntList();
    int m = g.outCount(anchorS);
    for (int i = 0; i < m; i++) {
      int s = g.outState(anchorS, i);
      if (g.allowed(s)
          && !ban.get(s >>> 1)
          && (lastTailS < 0 || EdgeDijkstra.canTurn(g, lastTailS, s, maxTurnDeg))) {
        src2.add(s);
      }
    }
    int firstE = e.path()[0];
    EdgeDijkstra.Result sRes =
        d.search(
            request(
                src2,
                s -> g.head(s) == turning && EdgeDijkstra.canTurn(g, s, firstE, maxTurnDeg),
                ban));
    if (!sRes.found()) {
      return null;
    }
    int[] a = sRes.path();
    int[] core = new int[a.length + e.path().length];
    System.arraycopy(a, 0, core, 0, a.length);
    System.arraycopy(e.path(), 0, core, a.length, e.path().length);
    return core;
  }

  /** Bans an edge, its corridor neighbours and the virtual pieces of either. */
  private void ban(BitSet ban, int edge) {
    banWithPieces(ban, edge);
    for (int nb : g.corridorNeighbours(edge)) {
      banWithPieces(ban, nb);
    }
  }

  private void banWithPieces(BitSet ban, int edge) {
    ban.set(edge);
    int[] pieces = g.pieces(edge);
    if (pieces != null) {
      for (int p : pieces) {
        ban.set(p);
      }
    }
  }

  private EdgeDijkstra.Request request(
      IntList sources, java.util.function.IntPredicate target, @Nullable BitSet ban) {
    int[] states = sources.toArray();
    double[] costs = new double[states.length];
    double[] metres = new double[states.length];
    for (int i = 0; i < states.length; i++) {
      costs[i] = w[states[i]];
      metres[i] = g.length(states[i] >>> 1);
    }
    return new EdgeDijkstra.Request(
        false, states, costs, metres, target, w, ban, null, Double.POSITIVE_INFINITY, -1, 0);
  }
}
