package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.BitSet;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * Polygon on the graph (design §5.6, GraphHopper's {@code round_trip} with a blacklist): two or
 * three via points are placed on a geometric shape between the anchors, the size of the shape is
 * deduced from the wished length and corrected by the secant on the previous attempts, and every
 * leg is a shortest path that may not use what the route already used, nor its corridor.
 *
 * <p>Banning the used edges makes a reuse in the core impossible by construction; the corridor ban
 * removes the doubling of a dual carriageway or of a path beside the road; node penalties
 * discourage crossings, which the checker bounds anyway.
 */
final class PolygonFamily {
  /** More rounds are tried, up to this multiple of the budget, while none fits the distance. */
  private static final int EXTRA_FACTOR = 3;

  private PolygonFamily() {}

  /** The via points of one round, as a function of its size {@code r}. */
  static final class Shape {
    final boolean near;
    final double ax;
    final double ay;
    final double bx;
    final double by;
    final double dir;
    final double[] jitterDeg;
    final double[] jitterFraction;
    final boolean leftSide;

    Shape(
        boolean near,
        double[] a,
        double[] b,
        double dir,
        double[] jitterDeg,
        double[] jitterFraction,
        boolean leftSide) {
      this.near = near;
      this.ax = a[0];
      this.ay = a[1];
      this.bx = b[0];
      this.by = b[1];
      this.dir = dir;
      this.jitterDeg = jitterDeg;
      this.jitterFraction = jitterFraction;
      this.leftSide = leftSide;
    }

    int k() {
      return jitterDeg.length;
    }

    double[][] points(double r) {
      int k = k();
      double[][] pts = new double[k][2];
      double mx = (ax + bx) / 2;
      double my = (ay + by) / 2;
      if (near) {
        double cx = mx + r * Math.sin(Math.toRadians(dir));
        double cy = my + r * Math.cos(Math.toRadians(dir));
        for (int j = 1; j <= k; j++) {
          double angle = dir + 180 + j * 360.0 / (k + 1) + jitterDeg[j - 1];
          pts[j - 1][0] = cx + r * Math.sin(Math.toRadians(angle));
          pts[j - 1][1] = cy + r * Math.cos(Math.toRadians(angle));
        }
      } else {
        double chord = Math.hypot(bx - ax, by - ay);
        double c = chord / 2;
        double semiMajor = Math.sqrt(r * r + c * c);
        double ux = (bx - ax) / chord;
        double uy = (by - ay) / chord;
        double nx = leftSide ? -uy : uy;
        double ny = leftSide ? ux : -ux;
        for (int j = 1; j <= k; j++) {
          double t = Math.max(0.05, Math.min(0.95, j / (k + 1.0) + jitterFraction[j - 1]));
          double phi = Math.PI * t;
          double along = -semiMajor * Math.cos(phi);
          double across = r * Math.sin(phi);
          pts[j - 1][0] = mx + along * ux + across * nx;
          pts[j - 1][1] = my + along * uy + across * ny;
        }
      }
      return pts;
    }

    /**
     * The size r whose polyline S, via points, E measures {@code target} (design §12.6, review M1):
     * the perimeter is a sum of norms of affine functions of r, hence convex, starting at the chord
     * |AB|, so the root is unique and a bisection finds it. The former closed form assumed S = E.
     */
    double radiusFor(double target) {
      if (perimeter(0) >= target) {
        return 50;
      }
      double lo = 0;
      double hi = Math.max(100, target / (2 * Math.PI));
      for (int i = 0; i < 40 && perimeter(hi) < target; i++) {
        hi *= 2;
      }
      for (int i = 0; i < 50 && hi - lo >= 0.05; i++) {
        double mid = (lo + hi) / 2;
        if (perimeter(mid) < target) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return hi;
    }

    /** Length of the polyline anchor S, via points, anchor E. */
    double perimeter(double r) {
      double[][] pts = points(r);
      double total = 0;
      double px = ax;
      double py = ay;
      for (double[] pt : pts) {
        total += Math.hypot(pt[0] - px, pt[1] - py);
        px = pt[0];
        py = pt[1];
      }
      return total + Math.hypot(bx - px, by - py);
    }
  }

  static List<Candidate> candidates(QueryContext ctx, AnchorPair pair, int budget) {
    QueryGraph g = ctx.g;
    GeneratorParameters p = ctx.p;
    double[] a = {g.nodeX(pair.anchorS), g.nodeY(pair.anchorS)};
    double[] b = {g.nodeX(pair.anchorE), g.nodeY(pair.anchorE)};
    double chord = Math.hypot(b[0] - a[0], b[1] - a[1]);
    boolean near = pair.loop() || chord < ctx.distanceM / 2;
    double dc = pair.coreTargetM;
    BitSet tailNodes = pair.tailNodes(g);
    List<Candidate> out = new ArrayList<>();
    double rho = p.initialDetour();
    int evaluations = 0;
    boolean fits = false;
    while (evaluations < budget || (!fits && evaluations < EXTRA_FACTOR * budget)) {
      int k = p.polygonViaMin() + ctx.rnd.nextInt(p.polygonViaMax() - p.polygonViaMin() + 1);
      double dir;
      if (ctx.bearingApplies) {
        dir = ctx.bearingDeg;
      } else if (!near) {
        dir = Geo.bearingDeg(a[0], a[1], b[0], b[1]);
      } else {
        dir = ctx.rnd.nextDouble() * 360;
      }
      double[] jitter = new double[k];
      double[] fraction = new double[k];
      for (int j = 0; j < k; j++) {
        jitter[j] = (ctx.rnd.nextDouble() * 2 - 1) * p.polygonJitterDeg();
        fraction[j] = (ctx.rnd.nextDouble() * 2 - 1) * 0.05;
      }
      boolean left = ctx.rnd.nextBoolean();
      Shape shape = new Shape(near, a, b, dir, jitter, fraction, left);

      double r;
      if (near) {
        r = shape.radiusFor(dc / rho);
      } else {
        double semiMajor = dc / (2 * rho);
        double c = chord / 2;
        r = semiMajor > c ? Math.sqrt(semiMajor * semiMajor - c * c) : 0.2 * c;
        r = Math.max(r, 50);
      }
      double previousR = Double.NaN;
      double previousLen = Double.NaN;
      double lastR = Double.NaN;
      double lastLen = Double.NaN;
      for (int i = 0; i < p.secantIterations(); i++) {
        evaluations++;
        Double len = evaluate(ctx, pair, shape, r, tailNodes, out);
        if (len == null) {
          break;
        }
        lastR = r;
        lastLen = len;
        fits |= ctx.withinTolerance(len + pair.tailLengthM);
        if (Math.abs(len - dc) <= 0.05 * dc) {
          break;
        }
        double next;
        if (i == 0 || Double.isNaN(previousR) || len == previousLen || r == previousR) {
          next = r * dc / len;
        } else {
          next = r + (dc - len) * (r - previousR) / (len - previousLen);
        }
        if (!(next > 0)) {
          next = r * dc / len;
        }
        previousR = r;
        previousLen = len;
        r = Math.max(0.5 * r, Math.min(1.5 * r, next));
      }
      if (!Double.isNaN(lastLen)) {
        double geometric = shape.perimeter(lastR);
        if (geometric > 0) {
          rho = 0.7 * rho + 0.3 * (lastLen / geometric);
        }
      }
    }
    ctx.polygonCandidates += out.size();
    return out;
  }

  /** Builds one polygon; returns the core length, or null when a via or a leg is missing. */
  private static @Nullable Double evaluate(
      QueryContext ctx,
      AnchorPair pair,
      Shape shape,
      double r,
      BitSet tailNodes,
      List<Candidate> out) {
    QueryGraph g = ctx.g;
    GeneratorParameters p = ctx.p;
    double[][] pts = shape.points(r);
    List<Integer> targets = new ArrayList<>();
    for (double[] pt : pts) {
      int via = nearestVia(ctx, pair, pt, p.viaMaxSnapFactor() * r, tailNodes);
      if (via < 0) {
        return null;
      }
      if (targets.isEmpty() || targets.get(targets.size() - 1) != via) {
        targets.add(via);
      }
    }
    targets.add(pair.anchorE);

    BitSet ban = (BitSet) pair.banned.clone();
    double[] penalty = ctx.polygonPenalty();
    IntList touchedNodes = ctx.polygonTouched;
    try {
      return evaluateLegs(ctx, pair, targets, ban, penalty, touchedNodes, out);
    } finally {
      for (int i = 0; i < touchedNodes.size(); i++) {
        penalty[touchedNodes.get(i)] = 0;
      }
      touchedNodes.clear();
    }
  }

  private static @Nullable Double evaluateLegs(
      QueryContext ctx,
      AnchorPair pair,
      List<Integer> targets,
      BitSet ban,
      double[] penalty,
      IntList touchedNodes,
      List<Candidate> out) {
    QueryGraph g = ctx.g;
    GeneratorParameters p = ctx.p;
    markPenalty(penalty, touchedNodes, pair.anchorS, p.crossingPenaltyM());
    int[] soFar = pair.tailS;
    boolean first = true;
    List<int[]> legs = new ArrayList<>();
    double aStar = ctx.astarFactor;
    for (int i = 0; i < targets.size(); i++) {
      int x = targets.get(i);
      boolean isEnd = i == targets.size() - 1;
      IntList sources =
          first && soFar.length == 0
              ? ctx.statesLeaving(pair.anchorS, ban)
              : ctx.continuations(soFar, ban);
      int firstTailE = pair.firstTailE();
      EdgeDijkstra.Result leg =
          ctx.dijkstra.search(
              ctx.forward(
                  sources,
                  s ->
                      g.head(s) == x
                          && (!isEnd
                              || firstTailE < 0
                              || EdgeDijkstra.canTurn(g, s, firstTailE, p.maxTurnDeg())),
                  ctx.weights,
                  ban,
                  penalty,
                  3 * pair.coreTargetM,
                  x,
                  aStar));
      if (!leg.found()) {
        return null;
      }
      int[] path = leg.path();
      for (int s : path) {
        banEdge(g, ban, s >>> 1);
        markPenalty(penalty, touchedNodes, g.head(s), p.crossingPenaltyM());
      }
      legs.add(path);
      soFar = QueryContext.concat(soFar, path);
      first = false;
    }
    int[] core = QueryContext.concat(legs.toArray(new int[0][]));
    int[] all = QueryContext.concat(pair.tailS, core, pair.tailE);
    if (SearchTurns.pathOk(g, all, 0, all.length, p.maxTurnDeg())) {
      out.add(new Candidate(all, Candidate.Family.POLYGON));
    }
    return ctx.length(core);
  }

  private static void markPenalty(double[] penalty, IntList touched, int node, double value) {
    if (penalty[node] == 0) {
      touched.add(node);
    }
    penalty[node] = value;
  }

  /** Bans an edge, its corridor neighbours and the virtual pieces of either. */
  private static void banEdge(QueryGraph g, BitSet ban, int edge) {
    banWithPieces(g, ban, edge);
    for (int nb : g.corridorNeighbours(edge)) {
      banWithPieces(g, ban, nb);
    }
  }

  private static void banWithPieces(QueryGraph g, BitSet ban, int edge) {
    ban.set(edge);
    int[] pieces = g.pieces(edge);
    if (pieces != null) {
      for (int piece : pieces) {
        ban.set(piece);
      }
    }
  }

  /**
   * The node nearest to a geometric point that the search can use: degree 2 or more, reached
   * from the start and able to reach the end, not on a tail, not an anchor.
   */
  private static int nearestVia(
      QueryContext ctx, AnchorPair pair, double[] pt, double maxDistance, BitSet tailNodes) {
    QueryGraph g = ctx.g;
    int best = -1;
    double bestDistance = maxDistance;
    for (int n = 0; n < g.nodeCount(); n++) {
      if (g.degree(n) < 2 || g.dangling(n) || tailNodes.get(n)) {
        continue;
      }
      if (n == pair.anchorS || n == pair.anchorE) {
        continue;
      }
      double d = Math.hypot(g.nodeX(n) - pt[0], g.nodeY(n) - pt[1]);
      if (d > bestDistance || (d == bestDistance && best >= 0)) {
        continue;
      }
      if (pair.metresFromS(ctx, n) == Double.POSITIVE_INFINITY
          || pair.metresToE(ctx, n) == Double.POSITIVE_INFINITY) {
        continue;
      }
      best = n;
      bestDistance = d;
    }
    return best;
  }
}
