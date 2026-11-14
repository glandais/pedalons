package fr.pedalons.service.route.generator;

import java.util.EnumSet;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/**
 * Independent checker of the hard guarantees of plan §2 (design §6, ledger docs/LEDGER_*.md
 * API-198).
 *
 * <p>Independent on purpose: it reads only primitive {@link QueryGraph} accessors (endpoints,
 * lengths, one-way flags, degrees, geometry) and recomputes headings from the geometry with its own
 * private method; it shares nothing with the search, the weights or the precomputed heading
 * arrays. It is the formal definition of the guarantees: when it disagrees with the generator, the
 * generator is wrong. The generator runs it on every candidate, so no returned route can fail it.
 *
 * <p>Not a guarantee, only scored: corridor doubling, bearing, familiarity.
 */
public final class RouteGuarantees {
  private RouteGuarantees() {}

  /** Nodes closer than this along the route form one junction for the turn rule. */
  static final double CLUSTER_M = 100;

  /**
   * @param startNode query node of S
   * @param endNode query node of E (equal to {@code startNode} for a loop)
   * @param targetM requested distance D
   * @param states the route as directed states on {@code g}
   */
  public static GuaranteeReport check(
      QueryGraph g,
      int startNode,
      int endNode,
      double targetM,
      int[] states,
      GeneratorParameters p) {
    EnumSet<Violation> v = EnumSet.noneOf(Violation.class);
    int n = states.length;
    if (n == 0) {
      v.add(Violation.EMPTY);
      return new GuaranteeReport(v, 0, 0, 0);
    }
    // 1. only team edges, continuity, one-ways
    boolean structural = false;
    for (int s : states) {
      if (s < 0 || s >= g.stateCount() || g.isMasked(s >>> 1)) {
        v.add(Violation.NOT_ON_NETWORK);
        structural = true;
      }
    }
    if (structural) {
      return new GuaranteeReport(v, 0, 0, 0);
    }
    if (g.tail(states[0]) != startNode) {
      v.add(Violation.WRONG_START);
    }
    if (g.head(states[n - 1]) != endNode) {
      v.add(Violation.WRONG_END);
    }
    for (int i = 0; i < n; i++) {
      if (!g.allowed(states[i])) {
        v.add(Violation.ONE_WAY);
      }
      if (i + 1 < n && g.head(states[i]) != g.tail(states[i + 1])) {
        v.add(Violation.DISCONTINUOUS);
      }
    }
    if (v.contains(Violation.DISCONTINUOUS)) {
      return new GuaranteeReport(v, 0, 0, 0);
    }

    // 2. no U-turn, no sharp turn at a junction; 3. no dead end
    for (int i = 0; i + 1 < n; i++) {
      int in = states[i];
      int out = states[i + 1];
      int node = g.head(in);
      if (out == (in ^ 1)) {
        v.add(Violation.U_TURN);
      } else if (turnApplies(g, node)
          && Geo.turnAngleDeg(
                  routeHeading(g, states, i, false), routeHeading(g, states, i + 1, true))
              >= p.maxTurnDeg()) {
        v.add(Violation.SHARP_TURN);
      }
      if (g.degree(node) < 2 || g.dangling(node)) {
        v.add(Violation.DEAD_END);
      }
    }

    // 2b. a U-turn spread over several nodes closer than 100 m (a short connector between two
    // nodes, a roundabout): the windows of each node alone may all stay under the limit
    double[] cum = new double[n + 1];
    for (int i = 0; i < n; i++) {
      cum[i + 1] = cum[i] + g.length(states[i] >>> 1);
    }
    for (int i = 0; i + 2 < n; i++) {
      if (!clusterApplies(g, g.head(states[i])) || states[i + 1] == (states[i] ^ 1)) {
        continue;
      }
      for (int j = i + 1; j + 1 < n && cum[j + 1] - cum[i + 1] <= CLUSTER_M; j++) {
        if (!clusterApplies(g, g.head(states[j]))) {
          continue;
        }
        if (Geo.turnAngleDeg(
                    routeHeading(g, states, i, false), routeHeading(g, states, j + 1, true))
                >= p.maxTurnDeg()
            && !hairpinTheTeamRides(g, states, i, j)) {
          v.add(Violation.SHARP_TURN);
        }
      }
    }

    // lengths
    double[] len = new double[n];
    double total = 0;
    for (int i = 0; i < n; i++) {
      len[i] = g.length(states[i] >>> 1);
      total += len[i];
    }

    // 4. reuse only in a start or end zone
    Map<Integer, Integer> count = new LinkedHashMap<>();
    for (int s : states) {
      count.merge(s >>> 1, 1, Integer::sum);
    }
    boolean tooMany = false;
    for (int c : count.values()) {
      if (c >= 3) {
        tooMany = true;
      }
    }
    if (tooMany) {
      v.add(Violation.EDGE_USED_MORE_THAN_TWICE);
    }
    boolean[] marked = new boolean[n];
    double shared = 0;
    for (int i = 0; i < n; i++) {
      if (count.get(states[i] >>> 1) >= 2) {
        marked[i] = true;
      }
    }
    for (Map.Entry<Integer, Integer> e : count.entrySet()) {
      if (e.getValue() >= 2) {
        shared += g.length(e.getKey());
      }
    }
    // the core = the longest run of unmarked positions, earliest on a tie
    int coreFrom = -1;
    int coreTo = -1;
    double coreLen = -1;
    int runStart = -1;
    double runLen = 0;
    for (int i = 0; i <= n; i++) {
      if (i < n && !marked[i]) {
        if (runStart < 0) {
          runStart = i;
          runLen = 0;
        }
        runLen += len[i];
      } else if (runStart >= 0) {
        if (runLen > coreLen) {
          coreLen = runLen;
          coreFrom = runStart;
          coreTo = i - 1;
        }
        runStart = -1;
      }
    }
    double limit = p.tailMaxShare() * targetM;
    if (coreFrom < 0) {
      v.add(Violation.REUSE_OUTSIDE_TAIL);
      coreFrom = n;
      coreTo = n - 1;
    }
    double startZone = 0;
    for (int i = 0; i < coreFrom; i++) {
      startZone += len[i];
    }
    double endZone = 0;
    for (int i = coreTo + 1; i < n; i++) {
      endZone += len[i];
    }
    if (startZone > limit || endZone > limit) {
      v.add(Violation.REUSE_OUTSIDE_TAIL);
    }
    if (shared > limit) {
      v.add(Violation.TAIL_TOO_LONG);
    }

    // 5. crossings in the core
    int crossings = 0;
    if (coreFrom <= coreTo) {
      int k = coreFrom; // node index of the core's first node: v_k = tail(e_k)
      int m = coreTo + 1; // node index of the core's last node
      Set<Integer> tailInner = new HashSet<>();
      for (int i = 0; i < k; i++) {
        tailInner.add(nodeAt(g, states, i));
      }
      for (int i = m + 1; i <= n; i++) {
        tailInner.add(nodeAt(g, states, i));
      }
      Set<Integer> seen = new HashSet<>();
      int first = nodeAt(g, states, k);
      seen.add(first);
      for (int i = k + 1; i <= m; i++) {
        int node = nodeAt(g, states, i);
        boolean closure = i == m && node == first;
        if (!closure && (seen.contains(node) || tailInner.contains(node))) {
          crossings++;
        }
        seen.add(node);
      }
    }
    if (crossings > p.maxCrossings()) {
      v.add(Violation.TOO_MANY_CROSSINGS);
    }

    // 5b. a corridor ridden twice (both carriageways of a dual carriageway, a path and its road)
    if (coreFrom <= coreTo
        && corridorShare(g, states, coreFrom, coreTo, p) > p.maxCorridorShare()) {
      v.add(Violation.CORRIDOR_DOUBLED);
    }

    // 6. distance
    if (Math.abs(total - targetM) > p.distanceTolerance() * targetM) {
      v.add(Violation.DISTANCE_OUT_OF_TOLERANCE);
    }
    return new GuaranteeReport(v, total, shared, crossings);
  }

  /** Node {@code i} of the route: {@code v_0 = tail(e_1)}, {@code v_i = head(e_i)}. */
  private static int nodeAt(QueryGraph g, int[] states, int i) {
    return i == 0 ? g.tail(states[0]) : g.head(states[i - 1]);
  }

  /**
   * Does the turn rule apply at a route node (design §12.4)? At every real node: not a virtual S/E
   * node, not a dangling end, not a node whose street degree is 2 (never produced by api 1.7), and
   * not a node the team itself rides through (team degree 2 with one track on both edges): a
   * hairpin ridden by the team stays legal even when a side track makes its apex a node.
   */
  static boolean turnApplies(QueryGraph g, int node) {
    return clusterApplies(g, node) && !g.riddenThrough(node);
  }

  /**
   * The same without the ridden-through exemption, for the cluster rule: two such nodes less than
   * {@link #CLUSTER_M} apart that together turn a route back on itself are a U-turn made of a
   * connector, however often the team rode it, whereas one apex node alone is a hairpin.
   */
  static boolean clusterApplies(QueryGraph g, int node) {
    return !g.isVirtual(node) && !g.dangling(node) && g.streetDegree(node) != 2;
  }

  /** A straight piece at least this long, across the carriageways, is a connector (§12.13). */
  static final double CONNECTOR_MIN_M = 15;

  /**
   * A hairpin ridden by the team is narrower than this across its carriageways; a span that moves
   * the route this far sideways, whatever its shape (slanted, curved, dotted), crosses a median.
   */
  static final double CROSSING_MIN_M = 30;

  /** Pieces bending by no more than this from where a straight run began belong to that run. */
  static final double RUN_BEND_DEG = 20;

  /** "About 90 degrees": within this many degrees of perpendicular. */
  static final double CONNECTOR_PERPENDICULAR_TOL_DEG = 25;

  /** A piece shorter than this has no reliable bearing: it never breaks a connector run. */
  static final double RUN_MIN_PIECE_M = 1.0;

  /**
   * The cluster of nodes {@code head(states[i])..head(states[j])} (all within {@link #CLUSTER_M})
   * is a hairpin the team rides, not a U-turn made of a connector (design 12.13), when
   *
   * <ol>
   *   <li>one single live track rode the whole span in one pass: the same track went from {@code
   *       states[i]} into {@code states[i + 1]}, on into {@code states[i + 2]} and so on up to
   *       {@code states[j + 1]}, at every node of the cluster, in the route's direction or all in
   *       the reverse one (a track that rode both carriageways at other times and crossed the
   *       connector later made no such pass), and
   *   <li>the span does not cross from one carriageway to the other: the first and the last node of
   *       the cluster are less than {@link #CROSSING_MIN_M} apart measured across the heading
   *       before and after the cluster, and no straight piece of {@link #CONNECTOR_MIN_M} or more
   *       meets those headings at about 90 degrees. A connector drawn with many vertices, slanted
   *       or curved still moves the route across, which the chord sees.
   * </ol>
   */
  static boolean hairpinTheTeamRides(QueryGraph g, int[] states, int i, int j) {
    long[] common = g.trackIds(states[i] >>> 1);
    for (int k = i + 1; k <= j + 1 && common.length > 0; k++) {
      common = intersect(common, g.trackIds(states[k] >>> 1));
    }
    if (common.length == 0 || !ridesInOnePass(g, states, i, j, common)) {
      return false;
    }
    double hin = routeHeading(g, states, i, false);
    double hout = routeHeading(g, states, j + 1, true);
    int first = g.head(states[i]);
    int last = g.head(states[j]);
    double dx = g.nodeX(last) - g.nodeX(first);
    double dy = g.nodeY(last) - g.nodeY(first);
    if (acrossM(dx, dy, hin) >= CROSSING_MIN_M || acrossM(dx, dy, hout) >= CROSSING_MIN_M) {
      return false;
    }
    // the polyline between the two nodes, as one list of points
    java.util.ArrayList<double[]> pts = new java.util.ArrayList<>();
    for (int k = i + 1; k <= j; k++) {
      double[][] xy = oriented(g, states[k]);
      for (int q = pts.isEmpty() ? 0 : 1; q < xy[0].length; q++) {
        pts.add(new double[] {xy[0][q], xy[1][q]});
      }
    }
    return !hasConnectorRun(pts, hin, hout);
  }

  /**
   * Is there a straight run of {@link #CONNECTOR_MIN_M} or more across the carriageways in the
   * polyline? Consecutive pieces that bend by no more than {@link #RUN_BEND_DEG} from where the run
   * started count as one run, so a connector drawn with a vertex every 10 m is as visible as one
   * drawn with two points.
   */
  private static boolean hasConnectorRun(java.util.List<double[]> rawPts, double hin, double hout) {
    // a point within a metre of the last kept one has an arbitrary bearing (duplicate vertex,
    // jitter, a back-zig): it joins the run it sits in instead of breaking it
    java.util.List<double[]> pts = new java.util.ArrayList<>();
    for (double[] q : rawPts) {
      if (pts.isEmpty()
          || Math.hypot(q[0] - pts.get(pts.size() - 1)[0], q[1] - pts.get(pts.size() - 1)[1])
              >= RUN_MIN_PIECE_M) {
        pts.add(q);
      }
    }
    int a = 0;
    while (a + 1 < pts.size()) {
      double[] from = pts.get(a);
      double[] first = pts.get(a + 1);
      double runBearing = Math.toDegrees(Math.atan2(first[0] - from[0], first[1] - from[1]));
      int b = a + 1;
      while (b + 1 < pts.size()) {
        double[] p0 = pts.get(b);
        double[] p1 = pts.get(b + 1);
        double next = Math.toDegrees(Math.atan2(p1[0] - p0[0], p1[1] - p0[1]));
        double bend = Math.abs(((next - runBearing) % 360 + 540) % 360 - 180);
        if (bend > RUN_BEND_DEG) {
          break;
        }
        b++;
      }
      double[] to = pts.get(b);
      double dx = to[0] - from[0];
      double dy = to[1] - from[1];
      if (Math.hypot(dx, dy) >= CONNECTOR_MIN_M - 0.5) { // half a metre of projection slack
        double seg = Math.toDegrees(Math.atan2(dx, dy));
        if (acrossDeg(seg, hin) || acrossDeg(seg, hout)) {
          return true;
        }
      }
      a = b;
    }
    return false;
  }

  private static long[] intersect(long[] a, long[] b) {
    long[] out = new long[Math.min(a.length, b.length)];
    int w = 0;
    for (long t : a) {
      if (java.util.Arrays.binarySearch(b, t) >= 0) {
        out[w++] = t;
      }
    }
    return java.util.Arrays.copyOf(out, w);
  }

  /** Length of the vector across a heading (its component perpendicular to it). */
  private static double acrossM(double dx, double dy, double headingDeg) {
    double h = Math.toRadians(headingDeg);
    return Math.abs(dx * Math.cos(h) - dy * Math.sin(h));
  }

  /**
   * Did one of {@code candidates} ride the cluster in one single pass: from {@code states[k]} into
   * {@code states[k + 1]} at every node of the cluster, all in the route's direction or all in the
   * reverse one, on steps that follow each other in the track's own ride (ranks +1 per node going
   * forward, -1 going backward)? A track that went in at one node on a first pass and out at
   * another on a second one made no such pass. A node that is the split point of one edge
   * (virtual), or between two states of one parent edge, is a continuation by construction.
   */
  private static boolean ridesInOnePass(
      QueryGraph g, int[] states, int i, int j, long[] candidates) {
    for (int dir = 0; dir < 2; dir++) {
      for (long track : candidates) {
        java.util.Set<Integer> ranks = null; // ranks reachable at the last checked node
        for (int k = i; k <= j; k++) {
          int node = g.head(states[k]);
          int a = states[k] >>> 1;
          int b = states[k + 1] >>> 1;
          if (g.isVirtual(node) || g.parentEdge(a) == g.parentEdge(b)) {
            continue;
          }
          NetworkGraph.Passes ps =
              dir == 0 ? g.transitionPasses(node, a, b) : g.transitionPasses(node, b, a);
          java.util.Set<Integer> here = new java.util.HashSet<>();
          for (int n = 0; n < ps.tracks().length; n++) {
            if (ps.tracks()[n] == track
                && (ranks == null || ranks.contains(ps.ranks()[n] - (dir == 0 ? 1 : -1)))) {
              here.add(ps.ranks()[n]);
            }
          }
          ranks = here;
          if (ranks.isEmpty()) {
            break;
          }
        }
        if (ranks == null || !ranks.isEmpty()) {
          return true;
        }
      }
    }
    return false;
  }

  /** Is the direction of a segment within the tolerance of perpendicular to a heading? */
  private static boolean acrossDeg(double segmentDeg, double headingDeg) {
    double d = Math.abs(((segmentDeg - headingDeg) % 180 + 180) % 180);
    return Math.abs(d - 90) <= CONNECTOR_PERPENDICULAR_TOL_DEG;
  }

  /**
   * Heading of the route on the 30-50 m window before (end of {@code states[index]}) or after
   * (start of {@code states[index]}) a node. The window is measured along the route, over as many
   * states as it takes: a junction drawn as two nodes joined by a short connector must not split a
   * 180 degree turn into two turns of 90 (plan §2.2).
   */
  private static double routeHeading(QueryGraph g, int[] states, int index, boolean atStart) {
    NetworkParameters np = g.parameters();
    double need = np.headingFarM();
    java.util.ArrayList<double[][]> parts = new java.util.ArrayList<>();
    double total = 0;
    int i = index;
    while (i >= 0 && i < states.length && total < need) {
      double[][] xy = oriented(g, states[i]);
      parts.add(xy);
      total += polyLength(xy[0], xy[1]);
      i += atStart ? 1 : -1;
    }
    int points = 0;
    for (double[][] xy : parts) {
      points += xy[0].length;
    }
    double[] xs = new double[points];
    double[] ys = new double[points];
    int k = 0;
    // parts are in route order when walking forward, in reverse route order when walking back
    for (int j = 0; j < parts.size(); j++) {
      double[][] xy = parts.get(atStart ? j : parts.size() - 1 - j);
      System.arraycopy(xy[0], 0, xs, k, xy[0].length);
      System.arraycopy(xy[1], 0, ys, k, xy[1].length);
      k += xy[0].length;
    }
    return pathHeading(xs, ys, atStart, np);
  }

  private static double[][] oriented(QueryGraph g, int state) {
    double[] xs = g.geometryX(state >>> 1);
    double[] ys = g.geometryY(state >>> 1);
    if ((state & 1) == 1) {
      for (int i = 0, j = xs.length - 1; i < j; i++, j--) {
        double tx = xs[i];
        xs[i] = xs[j];
        xs[j] = tx;
        double ty = ys[i];
        ys[i] = ys[j];
        ys[j] = ty;
      }
    }
    return new double[][] {xs, ys};
  }

  private static double polyLength(double[] xs, double[] ys) {
    double total = 0;
    for (int i = 1; i < xs.length; i++) {
      total += Math.hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]);
    }
    return total;
  }

  /**
   * Heading of a path at its start or end, recomputed from the geometry with the same 30-50 m
   * window as the plan (§2.2). Deliberately not shared with {@link Geo#headings}.
   */
  private static double pathHeading(
      double[] xs, double[] ys, boolean atStart, NetworkParameters np) {
    double total = polyLength(xs, ys);
    double far = Math.min(np.headingFarM(), total);
    double near = Math.min(np.headingNearM(), far / 2);
    double fromOffset = atStart ? near : total - far;
    double toOffset = atStart ? far : total - near;
    double[] a = along(xs, ys, fromOffset);
    double[] b = along(xs, ys, toOffset);
    if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 0.5) {
      a = new double[] {xs[0], ys[0]};
      b = new double[] {xs[xs.length - 1], ys[ys.length - 1]};
    }
    double deg = Math.toDegrees(Math.atan2(b[0] - a[0], b[1] - a[1]));
    return deg < 0 ? deg + 360 : deg;
  }

  private static double[] along(double[] xs, double[] ys, double offset) {
    double acc = 0;
    for (int i = 1; i < xs.length; i++) {
      double seg = Math.hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]);
      if (acc + seg >= offset && seg > 0) {
        double t = (offset - acc) / seg;
        return new double[] {
          xs[i - 1] + t * (xs[i] - xs[i - 1]), ys[i - 1] + t * (ys[i] - ys[i - 1])
        };
      }
      acc += seg;
    }
    return new double[] {xs[xs.length - 1], ys[ys.length - 1]};
  }

  /**
   * Share of the core that runs within {@code corridorDistM} of another stretch of the same core
   * at least 800 m further along the route, measured from the route's own geometry (design §12.5):
   * a doubled stretch counts on both passes.
   */
  static double corridorShare(
      QueryGraph g, int[] states, int coreFrom, int coreTo, GeneratorParameters p) {
    NetworkParameters np = g.parameters();
    double step = np.corridorSampleStepM();
    double dist = np.corridorDistM();
    double minGap = 2 * np.corridorMinOverlapM();
    double ignore = np.corridorEndIgnoreM();
    // sample the core every `step` metres
    java.util.ArrayList<double[]> samples = new java.util.ArrayList<>(); // x, y, route offset
    double offset = 0;
    double next = 0;
    for (int i = coreFrom; i <= coreTo; i++) {
      double[] xs = g.geometryX(states[i] >>> 1);
      double[] ys = g.geometryY(states[i] >>> 1);
      if ((states[i] & 1) == 1) {
        xs = Geo.reversed(xs);
        ys = Geo.reversed(ys);
      }
      double len = polyLength(xs, ys);
      while (next <= offset + len) {
        double[] pt = along(xs, ys, next - offset);
        samples.add(new double[] {pt[0], pt[1], next});
        next += step;
      }
      offset += len;
    }
    double coreLen = offset;
    if (samples.isEmpty() || coreLen <= 2 * ignore) {
      return 0;
    }
    java.util.HashMap<Long, java.util.ArrayList<Integer>> grid = new java.util.HashMap<>();
    for (int i = 0; i < samples.size(); i++) {
      double[] sp = samples.get(i);
      if (sp[2] < ignore || sp[2] > coreLen - ignore) {
        continue;
      }
      long key = cell(sp[0], dist) * 4_000_003L + cell(sp[1], dist);
      grid.computeIfAbsent(key, k -> new java.util.ArrayList<>()).add(i);
    }
    int doubled = 0;
    for (int i = 0; i < samples.size(); i++) {
      double[] sp = samples.get(i);
      if (sp[2] < ignore || sp[2] > coreLen - ignore) {
        continue;
      }
      boolean hit = false;
      long cx = cell(sp[0], dist);
      long cy = cell(sp[1], dist);
      for (long dx = -1; dx <= 1 && !hit; dx++) {
        for (long dy = -1; dy <= 1 && !hit; dy++) {
          java.util.ArrayList<Integer> list = grid.get((cx + dx) * 4_000_003L + (cy + dy));
          if (list == null) {
            continue;
          }
          for (int j : list) {
            double[] sq = samples.get(j);
            if (Math.abs(sq[2] - sp[2]) >= minGap
                && Math.hypot(sq[0] - sp[0], sq[1] - sp[1]) <= dist) {
              hit = true;
              break;
            }
          }
        }
      }
      if (hit) {
        doubled++;
      }
    }
    return step * doubled / (2 * coreLen);
  }

  private static long cell(double v, double size) {
    return (long) Math.floor(v / size);
  }
}
