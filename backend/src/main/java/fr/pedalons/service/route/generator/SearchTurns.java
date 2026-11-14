package fr.pedalons.service.route.generator;

/**
 * The turn rule as the search applies it (design §12.4): at every real node (not a virtual S/E
 * node, not a dangling end, not a node of street degree 2) the turn between the heading on the
 * 30-50 m before the node and the heading on the 30-50 m after it must stay below the maximum.
 *
 * <p>The windows are measured along the route, over as many states as it takes, so a junction drawn
 * as two nodes joined by a short connector (a roundabout, the end of a dual carriageway) cannot
 * split a 180 degree turn in two smaller ones. The search only knows the past of the label it is
 * extending, hence the look-back across short states; the checker has the last word. This class
 * deliberately shares no window code with {@link RouteGuarantees}.
 *
 * <p>Label-setting caveat: the history is the label's best path, so a transition refused under that
 * history might have been legal under another one. In towns with chains of short edges the search
 * may miss a route, never return an illegal one.
 */
final class SearchTurns {
  private SearchTurns() {}

  /** Does the turn rule apply at {@code node}? */
  static boolean applies(QueryGraph g, int node) {
    return RouteGuarantees.turnApplies(g, node);
  }

  /** True when the state is too short for its precomputed heading to cover the whole window. */
  static boolean isShort(QueryGraph g, int state) {
    return g.length(state >>> 1) < g.parameters().headingFarM();
  }

  /** Forward transition s to s2, {@code pred} = the label tree of the running search. */
  static boolean ok(QueryGraph g, int[] pred, int s, int s2, double maxTurnDeg) {
    if (s2 == (s ^ 1)) {
      return false;
    }
    NetworkParameters np = g.parameters();
    int h = g.head(s);
    boolean shortS = isShort(g, s);
    if (applies(g, h)) {
      double inH = shortS ? walkedEnd(g, pred, s, np) : g.endHeading(s);
      if (Geo.turnAngleDeg(inH, g.startHeading(s2)) >= maxTurnDeg) {
        return false;
      }
    }
    if (shortS && pred[s] >= 0) {
      int t = g.tail(s);
      if (applies(g, t)) {
        double inH = walkedEnd(g, pred, pred[s], np);
        double outH = windowHeading(g, new int[] {s, s2}, 0, true, np);
        if (Geo.turnAngleDeg(inH, outH) >= maxTurnDeg) {
          return false;
        }
      }
    }
    return true;
  }

  /** Backward transition s0 to s, {@code succ} = the label tree of a backward search. */
  static boolean okBackward(QueryGraph g, int[] succ, int s0, int s, double maxTurnDeg) {
    if (s0 == (s ^ 1)) {
      return false;
    }
    NetworkParameters np = g.parameters();
    int h = g.tail(s);
    boolean shortS = isShort(g, s);
    if (applies(g, h)) {
      double outH = shortS ? walkedStart(g, succ, s, np) : g.startHeading(s);
      if (Geo.turnAngleDeg(g.endHeading(s0), outH) >= maxTurnDeg) {
        return false;
      }
    }
    if (shortS && succ[s] >= 0) {
      int t = g.head(s);
      if (applies(g, t)) {
        double outH = walkedStart(g, succ, succ[s], np);
        double inH = windowHeading(g, new int[] {s0, s}, 1, false, np);
        if (Geo.turnAngleDeg(inH, outH) >= maxTurnDeg) {
          return false;
        }
      }
    }
    return true;
  }

  /** Every turn of {@code states[from..to)} on walked windows (joins of legs, tails, flow output). */
  static boolean pathOk(QueryGraph g, int[] states, int from, int to, double maxTurnDeg) {
    NetworkParameters np = g.parameters();
    for (int i = Math.max(0, from); i + 1 < Math.min(to, states.length); i++) {
      if (states[i + 1] == (states[i] ^ 1)) {
        return false;
      }
      if (applies(g, g.head(states[i]))
          && Geo.turnAngleDeg(
                  windowHeading(g, states, i, false, np), windowHeading(g, states, i + 1, true, np))
              >= maxTurnDeg) {
        return false;
      }
    }
    // a U-turn spread over nodes closer than 100 m (the checker's cluster rule)
    double[] cum = new double[states.length + 1];
    for (int i = 0; i < states.length; i++) {
      cum[i + 1] = cum[i] + g.length(states[i] >>> 1);
    }
    for (int i = Math.max(0, from); i + 2 < Math.min(to, states.length); i++) {
      if (!RouteGuarantees.clusterApplies(g, g.head(states[i]))) {
        continue;
      }
      for (int j = i + 1;
          j + 1 < Math.min(to, states.length)
              && cum[j + 1] - cum[i + 1] <= RouteGuarantees.CLUSTER_M;
          j++) {
        if (RouteGuarantees.clusterApplies(g, g.head(states[j]))
            && Geo.turnAngleDeg(
                    windowHeading(g, states, i, false, np),
                    windowHeading(g, states, j + 1, true, np))
                >= maxTurnDeg
            && !RouteGuarantees.hairpinTheTeamRides(g, states, i, j)) {
          return false;
        }
      }
    }
    return true;
  }

  private static double walkedEnd(QueryGraph g, int[] pred, int s, NetworkParameters np) {
    int count = 0;
    double acc = 0;
    for (int c = s; c >= 0 && acc < 2 * np.headingFarM(); c = pred[c]) {
      acc += g.length(c >>> 1);
      count++;
    }
    int[] chain = new int[count];
    int c = s;
    for (int i = count - 1; i >= 0; i--) {
      chain[i] = c;
      c = pred[c];
    }
    return windowHeading(g, chain, count - 1, false, np);
  }

  private static double walkedStart(QueryGraph g, int[] succ, int s, NetworkParameters np) {
    int count = 0;
    double acc = 0;
    for (int c = s; c >= 0 && acc < 2 * np.headingFarM(); c = succ[c]) {
      acc += g.length(c >>> 1);
      count++;
    }
    int[] chain = new int[count];
    int c = s;
    for (int i = 0; i < count; i++) {
      chain[i] = c;
      c = succ[c];
    }
    return windowHeading(g, chain, 0, true, np);
  }

  /**
   * Heading of the route on the 30-50 m window after the start of {@code states[index]} (atStart)
   * or before its end, walking over as many states as needed. Reads the shared coordinate arrays in
   * place: no copy, no reversal, nothing allocated but two small points (the search calls this for
   * every relaxation out of a short state, so a town of short edges lives here).
   */
  static double windowHeading(
      QueryGraph g, int[] states, int index, boolean atStart, NetworkParameters np) {
    double need = np.headingFarM();
    double total = 0;
    int count = 0;
    int i = index;
    while (i >= 0 && i < states.length && total < need) {
      total += g.polylineLength(states[i] >>> 1);
      count++;
      i += atStart ? 1 : -1;
    }
    int first = atStart ? index : index - count + 1;
    double far = Math.min(np.headingFarM(), total);
    double near = Math.min(np.headingNearM(), far / 2);
    double from = atStart ? near : total - far;
    double to = atStart ? far : total - near;
    double[] a = new double[2];
    double[] b = new double[2];
    chainPoint(g, states, first, count, from, a);
    chainPoint(g, states, first, count, to, b);
    if (Math.hypot(b[0] - a[0], b[1] - a[1]) < 0.5) {
      chainPoint(g, states, first, count, 0, a);
      chainPoint(g, states, first, count, total, b);
      return Geo.bearingDeg(a[0], a[1], b[0], b[1]);
    }
    return Geo.bearingDeg(a[0], a[1], b[0], b[1]);
  }

  /** The point {@code arc} metres along {@code count} consecutive states from {@code states[first]}. */
  private static void chainPoint(
      QueryGraph g, int[] states, int first, int count, double arc, double[] out) {
    double acc = 0;
    for (int k = 0; k < count; k++) {
      int s = states[first + k];
      double len = g.polylineLength(s >>> 1);
      if (k == count - 1 || acc + len >= arc) {
        g.pointOnState(s, arc - acc, out);
        return;
      }
      acc += len;
    }
  }
}
