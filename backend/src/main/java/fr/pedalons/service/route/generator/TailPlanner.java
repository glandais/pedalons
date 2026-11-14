package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.BitSet;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Anchors and tails at the start and the end (design §5.4, plan §2.4).
 *
 * <p>The tail is the stretch ridden twice, out and back, to leave a branch or a village by its one
 * road. It is the only place a route may repeat itself, and it is bounded by {@code tailMaxShare ·
 * D}. A start that lies on a bridge or in a small component <em>must</em> have one (the "forced"
 * case); elsewhere a tail is only a voluntary way to leave a dense place by its best road.
 *
 * <p>Tails are ridden in both directions, so they are searched on edges allowed both ways, with
 * metres as weights; the end tail is the reverse of a search from the end.
 */
final class TailPlanner {
  /** A tail: the states from a node to its anchor. */
  private record Tail(int anchor, int[] states, double lengthM) {}

  private final QueryContext ctx;
  private final QueryGraph g;
  private final BitSet bothWays;

  private TailPlanner(QueryContext ctx) {
    this.ctx = ctx;
    this.g = ctx.g;
    this.bothWays = (BitSet) ctx.banned.clone();
    for (int e = 0; e < g.edgeCount(); e++) {
      if (!g.allowed(2 * e) || !g.allowed(2 * e + 1)) {
        bothWays.set(e);
      }
    }
  }

  /** Anchor pairs in a deterministic order; empty when a forced tail cannot be found. */
  static List<AnchorPair> plan(QueryContext ctx) {
    return new TailPlanner(ctx).pairs();
  }

  private List<AnchorPair> pairs() {
    List<Tail> starts = anchorsFor(ctx.start, false);
    List<AnchorPair> out = new ArrayList<>();
    if (ctx.loop) {
      for (Tail t : starts) {
        pair(out, t, new Tail(t.anchor, QueryContext.reversed(t.states), t.lengthM));
      }
      return out;
    }
    List<Tail> ends = anchorsFor(ctx.end, true);
    for (Tail s : starts) {
      for (Tail e : ends) {
        pair(out, s, e);
      }
    }
    return out;
  }

  /** Is the node in a trivial component (a bridge-only branch, a pendant road)? */
  static boolean trivial(QueryContext ctx, int node) {
    return ctx.g.componentLength(ctx.g.component(node)) <= 0;
  }

  private void pair(List<AnchorPair> out, Tail s, Tail e) {
    double dc = ctx.distanceM - s.lengthM - e.lengthM;
    if (dc < 0.5 * ctx.distanceM) {
      return;
    }
    BitSet ban = QueryContext.withEdges(ctx.banned, s.states, e.states);
    out.add(new AnchorPair(s.anchor, e.anchor, s.states, e.states, s.lengthM + e.lengthM, dc, ban));
  }

  private boolean isHub(int node) {
    int comp = g.component(node);
    double len = g.componentLength(comp);
    if (len <= 0 || g.dangling(node)) {
      return false;
    }
    return !ctx.loop || len >= ctx.p.hubMinLengthFactor() * ctx.distanceM;
  }

  private boolean forced(int node) {
    double len = g.componentLength(g.component(node));
    return len <= 0 || (ctx.loop && len < ctx.p.hubMinLengthFactor() * ctx.distanceM);
  }

  /**
   * Tails of a node, in route order: node to anchor at the start, anchor to node at the end.
   * Loops keep the forced, two-way, bounded tail; for a trip the way from S (or to E) to the
   * component is an approach ridden once (no cap, one-way allowed, design §12.6 M4).
   */
  private List<Tail> anchorsFor(int node, boolean end) {
    double limit = ctx.p.tailMaxShare() * ctx.distanceM;
    List<Tail> out = new ArrayList<>();
    if (forced(node)) {
      if (ctx.loop) {
        out.addAll(forcedTails(node, limit, end));
      } else {
        out.addAll(approaches(node, end));
      }
      return out;
    }
    out.add(new Tail(node, new int[0], 0));
    if (ctx.p.extraTailAnchors() > 0) {
      for (Tail t : voluntary(node, limit)) {
        out.add(end ? new Tail(t.anchor, QueryContext.reversed(t.states), t.lengthM) : t);
      }
    }
    return out;
  }

  private List<Tail> forcedTails(int node, double limit, boolean end) {
    Map<Integer, Tail> byAnchor = new LinkedHashMap<>();
    IntList firsts = ctx.statesLeaving(node, bothWays);
    for (int i = 0; i < firsts.size(); i++) {
      IntList one = new IntList();
      one.add(firsts.get(i));
      EdgeDijkstra.Result r =
          ctx.dijkstra.search(
              ctx.forward(one, s -> isHub(g.head(s)), ctx.lengths, bothWays, null, limit, -1, 0));
      if (r.found()) {
        int[] path = end ? QueryContext.reversed(r.path()) : r.path();
        byAnchor.putIfAbsent(
            g.head(r.targetState()), new Tail(g.head(r.targetState()), path, r.targetMetres()));
      }
    }
    return new ArrayList<>(byAnchor.values());
  }

  /** Approaches of a trip: shortest ways to a hub that respect one-ways, ridden once. */
  private List<Tail> approaches(int node, boolean end) {
    double limit = 0.5 * ctx.distanceM;
    Map<Integer, Tail> byAnchor = new LinkedHashMap<>();
    if (!end) {
      IntList firsts = ctx.statesLeaving(node, ctx.banned);
      for (int i = 0; i < firsts.size(); i++) {
        IntList one = new IntList();
        one.add(firsts.get(i));
        EdgeDijkstra.Result r =
            ctx.dijkstra.search(
                ctx.forward(
                    one, s -> isHub(g.head(s)), ctx.lengths, ctx.banned, null, limit, -1, 0));
        if (r.found()) {
          byAnchor.putIfAbsent(
              g.head(r.targetState()),
              new Tail(g.head(r.targetState()), r.path(), r.targetMetres()));
        }
      }
    } else {
      int n = g.outCount(node);
      for (int i = 0; i < n; i++) {
        int arriving = g.outState(node, i) ^ 1;
        if (!g.allowed(arriving) || ctx.banned.get(arriving >>> 1)) {
          continue;
        }
        EdgeDijkstra.Request req =
            new EdgeDijkstra.Request(
                true,
                new int[] {arriving},
                new double[] {g.length(arriving >>> 1)},
                new double[] {g.length(arriving >>> 1)},
                s -> isHub(g.tail(s)),
                ctx.lengths,
                ctx.banned,
                null,
                limit,
                -1,
                0);
        EdgeDijkstra.Result r = ctx.dijkstra.search(req);
        if (r.found()) {
          // a backward search returns its path in travel order: anchor first, E last
          int anchor = g.tail(r.path()[0]);
          byAnchor.putIfAbsent(anchor, new Tail(anchor, r.path(), r.targetMetres()));
        }
      }
    }
    return new ArrayList<>(byAnchor.values());
  }

  /** The hub junctions within reach whose direction best fits the bearing. */
  private List<Tail> voluntary(int node, double limit) {
    EdgeDijkstra.Result r =
        ctx.dijkstra.search(
            ctx.forward(
                ctx.statesLeaving(node, bothWays),
                null,
                ctx.lengths,
                bothWays,
                null,
                limit,
                -1,
                0));
    EdgeDijkstra.Tree tree = r.tree();
    double min = 0.03 * ctx.distanceM;
    Map<Integer, Integer> bestState = new LinkedHashMap<>();
    for (int s = 0; s < g.stateCount(); s++) {
      if (!tree.reached(s)) {
        continue;
      }
      int h = g.head(s);
      double m = tree.metres[s];
      if (h == node || m < min || m > limit || g.degree(h) < 3 || !isHub(h)) {
        continue;
      }
      Integer previous = bestState.get(h);
      if (previous == null || m < tree.metres[previous]) {
        bestState.put(h, s);
      }
    }
    List<Integer> nodes = new ArrayList<>(bestState.keySet());
    nodes.sort(
        Comparator.<Integer>comparingDouble(
                n -> {
                  if (!ctx.bearingApplies) {
                    return 0;
                  }
                  double b = Geo.bearingDeg(g.nodeX(node), g.nodeY(node), g.nodeX(n), g.nodeY(n));
                  return Geo.turnAngleDeg(b, ctx.bearingDeg);
                })
            .thenComparingInt(n -> n));
    List<Tail> out = new ArrayList<>();
    for (int i = 0; i < Math.min(ctx.p.extraTailAnchors(), nodes.size()); i++) {
      int state = bestState.get(nodes.get(i));
      out.add(new Tail(nodes.get(i), tree.path(state), tree.metres[state]));
    }
    return out;
  }
}
