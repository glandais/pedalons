package fr.pedalons.service.route.generator;

import java.util.Arrays;
import java.util.BitSet;
import java.util.EnumMap;
import java.util.Map;
import java.util.Random;
import java.util.function.IntPredicate;
import org.jspecify.annotations.Nullable;

/**
 * Everything one {@code generate} call shares between its stages: the query graph, the weights, the
 * bans, the random source and the search engines (design §2, "QueryContext").
 *
 * <p>One instance per call and per thread: the engines reuse their arrays, and the random source
 * is consumed in a fixed order so that a seed fully determines the output.
 */
final class QueryContext {
  final QueryGraph g;
  final GeneratorParameters p;
  final int start;
  final int end;
  final boolean loop;
  final double distanceM;
  final double familiarity;
  final boolean bearingApplies;
  final double bearingDeg;
  final RideType type;
  double[] weights;
  ZSource zSource;
  boolean familiarityFallback;
  final double[] lengths;
  final BitSet banned;
  final Random rnd;
  final EdgeDijkstra dijkstra;
  final IntList polygonTouched = new IntList();
  private double @Nullable [] polygonPenalty;
  final EdgeDisjointPaths disjoint;
  double astarFactor;

  // counters, read when the diagnostics are built
  int loopCandidates;
  int polygonCandidates;
  int validLoop;
  int validPolygon;
  int disjointJoinRejected;
  int walkedElsewhere;
  final Map<Violation, Integer> rejections = new EnumMap<>(Violation.class);

  QueryContext(QueryGraph g, GeneratorParameters p, GeneratorRequest request, int start, int end) {
    this.g = g;
    this.p = p;
    this.start = start;
    this.end = end;
    this.loop = start == end;
    this.distanceM = request.distanceM();
    this.familiarity = request.familiarity();
    double chord = Math.hypot(g.nodeX(end) - g.nodeX(start), g.nodeY(end) - g.nodeY(start));
    this.bearingApplies = request.bearing() != null && chord < distanceM / 2;
    this.bearingDeg = request.bearing() == null ? 0 : request.bearing().degrees();
    this.type = request.type();
    this.zSource = ZSource.of(request.type());
    this.weights = EdgeWeights.build(g, p, request.familiarity(), type, zSource);
    this.lengths = EdgeWeights.lengths(g);
    this.banned = EdgeWeights.banned(g, type, start, end);
    this.rnd = new Random(request.seed());
    this.dijkstra = new EdgeDijkstra(g, p.maxTurnDeg());
    this.disjoint = new EdgeDisjointPaths(g, p.maxTurnDeg());
    this.astarFactor = g.base().aStarScale() * EdgeDijkstra.minWeightPerMetre(g, weights);
  }

  /**
   * Replaces the familiarity of the requested type by the one of all kinds (too few tracks of the
   * type nearby); the admitted edges never change.
   */
  void useFamiliarityFallback() {
    familiarityFallback = true;
    zSource = ZSource.ALL;
    weights = EdgeWeights.build(g, p, familiarity, type, zSource);
    astarFactor = g.base().aStarScale() * EdgeDijkstra.minWeightPerMetre(g, weights);
  }

  /** One crossing-penalty array per context, reset through {@link #polygonTouched} (review minor). */
  double[] polygonPenalty() {
    if (polygonPenalty == null) {
      polygonPenalty = new double[g.nodeCount()];
    }
    return polygonPenalty;
  }

  /** Straight-line distance between the start and the end, in metres. */
  double chordM() {
    return Math.hypot(g.nodeX(end) - g.nodeX(start), g.nodeY(end) - g.nodeY(start));
  }

  /** Bearing from the start to a node, 0 = north, clockwise. */
  double bearingToNode(int node) {
    return Geo.bearingDeg(g.nodeX(start), g.nodeY(start), g.nodeX(node), g.nodeY(node));
  }

  /** Allowed states leaving {@code node} that are not banned, in ascending state order. */
  IntList statesLeaving(int node, BitSet ban) {
    IntList out = new IntList();
    int n = g.outCount(node);
    for (int i = 0; i < n; i++) {
      int s = g.outState(node, i);
      if (g.allowed(s) && !ban.get(s >>> 1)) {
        out.add(s);
      }
    }
    return out;
  }

  /**
   * Allowed continuations of a route so far (the turn rule applies on walked windows, with the
   * route as history) that are not banned.
   */
  IntList continuations(int[] routeSoFar, BitSet ban) {
    IntList out = new IntList();
    int last = routeSoFar[routeSoFar.length - 1];
    int node = g.head(last);
    int n = g.outCount(node);
    int[] probe = Arrays.copyOf(routeSoFar, routeSoFar.length + 1);
    for (int i = 0; i < n; i++) {
      int s = g.outState(node, i);
      if (s == (last ^ 1) || !g.allowed(s) || ban.get(s >>> 1)) {
        continue;
      }
      probe[probe.length - 1] = s;
      if (SearchTurns.pathOk(
          g, probe, Math.max(0, probe.length - 3), probe.length, p.maxTurnDeg())) {
        out.add(s);
      }
    }
    return out;
  }

  /** A forward request from {@code sources}, each source costing its own weight. */
  EdgeDijkstra.Request forward(
      IntList sources,
      IntPredicate target,
      double[] w,
      BitSet ban,
      double @Nullable [] nodePenalty,
      double costLimit,
      int aStarNode,
      double aStarFactor) {
    int[] states = sources.toArray();
    double[] costs = new double[states.length];
    double[] metres = new double[states.length];
    for (int i = 0; i < states.length; i++) {
      costs[i] = w[states[i]];
      metres[i] = g.length(states[i] >>> 1);
    }
    return new EdgeDijkstra.Request(
        false,
        states,
        costs,
        metres,
        target,
        w,
        ban,
        nodePenalty,
        costLimit,
        aStarNode,
        aStarFactor);
  }

  /** Adds the edges of {@code states} to a copy of {@code ban}. */
  static BitSet withEdges(BitSet ban, int[]... paths) {
    BitSet out = (BitSet) ban.clone();
    for (int[] path : paths) {
      for (int s : path) {
        out.set(s >>> 1);
      }
    }
    return out;
  }

  /** Sum of the lengths of the states. */
  double length(int[] states) {
    double total = 0;
    for (int s : states) {
      total += g.length(s >>> 1);
    }
    return total;
  }

  /** Is this route length within the distance tolerance of the request? */
  boolean withinTolerance(double lengthM) {
    return Math.abs(lengthM - distanceM) <= p.distanceTolerance() * distanceM;
  }

  static int[] reversed(int[] states) {
    int[] out = new int[states.length];
    for (int i = 0; i < states.length; i++) {
      out[i] = states[states.length - 1 - i] ^ 1;
    }
    return out;
  }

  static int[] concat(int[]... parts) {
    int n = 0;
    for (int[] part : parts) {
      n += part.length;
    }
    int[] out = new int[n];
    int k = 0;
    for (int[] part : parts) {
      System.arraycopy(part, 0, out, k, part.length);
      k += part.length;
    }
    return out;
  }

  void reject(Iterable<Violation> violations) {
    for (Violation v : violations) {
      rejections.merge(v, 1, Integer::sum);
    }
  }

  GeneratorDiagnostics diagnostics() {
    return new GeneratorDiagnostics(
        loopCandidates,
        polygonCandidates,
        validLoop,
        validPolygon,
        new EnumMap<>(rejections),
        disjoint.infeasible,
        disjoint.fallbacks,
        dijkstra.walkedTurnRefusals + walkedElsewhere,
        disjointJoinRejected + disjoint.joinRejected,
        familiarityFallback);
  }
}
