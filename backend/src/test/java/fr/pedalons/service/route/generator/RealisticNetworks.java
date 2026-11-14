package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * Random networks that look like what osm-route-details reports (design §12.9, review M6): a truth
 * street graph first (jittered grid with bent streets, roundabouts, dual carriageways with their
 * connectors, a side cycleway, spurs, a pendant branch with a loop, private roads), then tracks
 * walked on it and emitted as api 1.7 would, with partial edges, mid-edge starts, U-turns, unknown
 * ends, excluded tracks and node drift between data versions.
 *
 * <p>Deviations from the written design, all in favour of a smaller generator: the walks end
 * mid-edge or at a node, not specifically at the team location; a degree-2 truth node is merged
 * away like the producer does (no api 1.7 node has degree 2).
 */
final class RealisticNetworks {
  private RealisticNetworks() {}

  static final class TEdge {
    int a;
    int b;
    double[][] pts; // metres, from node a to node b
    double length; // metres on the sphere
    WayKind way = WayKind.MINOR_ROAD;
    SurfaceClass surfaceClass = SurfaceClass.PAVED;
    @Nullable String detail = "asphalt";
    SurfaceSource source = SurfaceSource.TAGGED;
    boolean homogeneous = true;
    boolean oneway; // a to b only
    boolean isPrivate;
    final Set<TrackKind> ridden = EnumSet.noneOf(TrackKind.class);

    double planar() {
      double len = 0;
      for (int i = 1; i < pts.length; i++) {
        len += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
      }
      return len;
    }
  }

  static final class Truth {
    final List<double[]> nodes = new ArrayList<>();
    final List<TEdge> edges = new ArrayList<>();

    int addNode(double x, double y) {
      nodes.add(new double[] {x, y});
      return nodes.size() - 1;
    }

    List<TEdge> incident(int node) {
      List<TEdge> out = new ArrayList<>();
      for (TEdge e : edges) {
        if (e.a == node || e.b == node) {
          out.add(e);
        }
      }
      return out;
    }

    /** Does the truth admit the edge for the ride type, given who rode it? (the §12.7 table) */
    boolean admits(TEdge e, RideType type) {
      WayKind k = e.homogeneous ? e.way : WayKind.UNKNOWN;
      SurfaceClass sc = e.homogeneous ? e.surfaceClass : SurfaceClass.UNKNOWN;
      String d = e.homogeneous ? e.detail : null;
      boolean rough = "dirt".equals(d) || "sand".equals(d) || "grass".equals(d) || "rock".equals(d);
      switch (type) {
        case ROAD:
          if (k == WayKind.PATH
              || k == WayKind.FOOTWAY
              || k == WayKind.STEPS
              || sc == SurfaceClass.UNPAVED) {
            return false;
          }
          if ((k == WayKind.MAJOR_ROAD || k == WayKind.MINOR_ROAD || k == WayKind.CYCLEWAY)
              && sc == SurfaceClass.PAVED) {
            return true;
          }
          return e.ridden.contains(TrackKind.ROAD);
        case GRAVEL:
          if (k == WayKind.STEPS) {
            return false;
          }
          if (k == WayKind.PATH || k == WayKind.FOOTWAY || rough) {
            return e.ridden.contains(TrackKind.GRAVEL) || e.ridden.contains(TrackKind.MIXED);
          }
          return true;
        case MTB:
        default:
          return k != WayKind.STEPS || e.ridden.contains(TrackKind.MTB);
      }
    }
  }

  record Generated(
      List<TrackInput> tracks,
      Truth truth,
      LatLon teamLocation,
      double teamX,
      double teamY,
      LocalProjection projection) {

    /** Length of the admitted, live-ridden truth road whose middle is within the radius. */
    double admittedNear(double x, double y, double radiusM, RideType type) {
      double total = 0;
      for (TEdge e : truth.edges) {
        if (e.isPrivate || e.ridden.isEmpty() || !truth.admits(e, type)) {
          continue;
        }
        double[] mid = e.pts[e.pts.length / 2];
        if (Math.hypot(mid[0] - x, mid[1] - y) <= radiusM) {
          total += e.length;
        }
      }
      return total;
    }
  }

  // ---- truth ------------------------------------------------------------------------------------

  private static double[][] bent(Random r, double[] a, double[] b) {
    int k = 2 + r.nextInt(5);
    double len = Math.hypot(b[0] - a[0], b[1] - a[1]);
    double ux = (b[0] - a[0]) / len;
    double uy = (b[1] - a[1]) / len;
    double[][] pts = new double[k + 2][];
    pts[0] = a;
    pts[k + 1] = b;
    double maxLateral = Math.min(60, 0.07 * len);
    for (int i = 1; i <= k; i++) {
      double f = (i + (r.nextDouble() * 2 - 1) * 0.25) / (k + 1);
      double lateral = (r.nextDouble() * 2 - 1) * maxLateral;
      pts[i] =
          new double[] {
            a[0] + f * (b[0] - a[0]) - uy * lateral, a[1] + f * (b[1] - a[1]) + ux * lateral
          };
    }
    return pts;
  }

  private static void attributes(Random r, TEdge e) {
    double x = r.nextDouble();
    if (x < 0.15) {
      e.way = WayKind.MAJOR_ROAD;
    } else if (x < 0.70) {
      e.way = WayKind.MINOR_ROAD;
    } else if (x < 0.85) {
      e.way = WayKind.TRACK;
    } else if (x < 0.92) {
      e.way = WayKind.PATH;
    } else if (x < 0.97) {
      e.way = WayKind.CYCLEWAY;
    } else if (x < 0.99) {
      e.way = WayKind.FOOTWAY;
    } else {
      e.way = WayKind.STEPS;
    }
    switch (e.way) {
      case TRACK:
        if (r.nextDouble() < 0.6) {
          e.surfaceClass = SurfaceClass.UNPAVED;
          e.detail = new String[] {"gravel", "compacted", "dirt", "grass"}[r.nextInt(4)];
          e.source = SurfaceSource.TAGGED;
        } else {
          e.surfaceClass = r.nextBoolean() ? SurfaceClass.UNPAVED : SurfaceClass.PAVED;
          e.detail = null;
          e.source = SurfaceSource.INFERRED_TRACKTYPE;
        }
        break;
      case PATH:
        e.surfaceClass = SurfaceClass.UNPAVED;
        e.detail = r.nextBoolean() ? "dirt" : "compacted";
        e.source = SurfaceSource.TAGGED;
        break;
      case FOOTWAY:
      case STEPS:
        e.surfaceClass = SurfaceClass.PAVED;
        e.detail = "paving_stones";
        e.source = SurfaceSource.TAGGED;
        break;
      default:
        e.surfaceClass = SurfaceClass.PAVED;
        e.detail = r.nextDouble() < 0.7 ? "asphalt" : null;
        e.source = e.detail == null ? SurfaceSource.INFERRED_HIGHWAY : SurfaceSource.TAGGED;
    }
    e.homogeneous = r.nextDouble() >= 0.2;
  }

  private static TEdge edge(Random r, Truth t, int a, int b, double[][] pts) {
    TEdge e = new TEdge();
    e.a = a;
    e.b = b;
    e.pts = pts;
    attributes(r, e);
    t.edges.add(e);
    return e;
  }

  private static boolean connected(Truth t, TEdge skip) {
    int n = t.nodes.size();
    int[] seen = new int[n];
    List<Integer>[] adj = adjacency(t, skip);
    int start = -1;
    int used = 0;
    boolean[] has = new boolean[n];
    for (TEdge e : t.edges) {
      if (e != skip) {
        has[e.a] = true;
        has[e.b] = true;
      }
    }
    for (int i = 0; i < n; i++) {
      if (has[i]) {
        used++;
        if (start < 0) {
          start = i;
        }
      }
    }
    if (start < 0) {
      return true;
    }
    java.util.ArrayDeque<Integer> q = new java.util.ArrayDeque<>();
    q.add(start);
    seen[start] = 1;
    int count = 1;
    while (!q.isEmpty()) {
      int u = q.poll();
      for (int v : adj[u]) {
        if (seen[v] == 0) {
          seen[v] = 1;
          count++;
          q.add(v);
        }
      }
    }
    return count == used;
  }

  @SuppressWarnings("unchecked")
  private static List<Integer>[] adjacency(Truth t, TEdge skip) {
    List<Integer>[] adj = new List[t.nodes.size()];
    for (int i = 0; i < adj.length; i++) {
      adj[i] = new ArrayList<>();
    }
    for (TEdge e : t.edges) {
      if (e != skip) {
        adj[e.a].add(e.b);
        adj[e.b].add(e.a);
      }
    }
    return adj;
  }

  private static double[] firstDirection(Truth t, TEdge e, int node) {
    double[] p = node == e.a ? e.pts[1] : e.pts[e.pts.length - 2];
    double[] n = t.nodes.get(node);
    return new double[] {p[0] - n[0], p[1] - n[1]};
  }

  private static void setEnd(Truth t, TEdge e, int oldNode, int newNode) {
    double[] p = t.nodes.get(newNode);
    if (e.a == oldNode) {
      e.a = newNode;
      e.pts[0] = p;
    } else {
      e.b = newNode;
      e.pts[e.pts.length - 1] = p;
    }
  }

  private static Truth truth(Random r) {
    Truth t = new Truth();
    int rows = 6 + r.nextInt(5);
    int cols = 6 + r.nextInt(5);
    double spacing = 600 + r.nextInt(601);
    int[][] id = new int[rows][cols];
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        id[i][j] =
            t.addNode(
                (j - (cols - 1) / 2.0) * spacing + (r.nextDouble() * 2 - 1) * 0.2 * spacing,
                (i - (rows - 1) / 2.0) * spacing + (r.nextDouble() * 2 - 1) * 0.2 * spacing);
      }
    }
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (j + 1 < cols) {
          edge(
              r,
              t,
              id[i][j],
              id[i][j + 1],
              bent(r, t.nodes.get(id[i][j]), t.nodes.get(id[i][j + 1])));
        }
        if (i + 1 < rows) {
          edge(
              r,
              t,
              id[i][j],
              id[i + 1][j],
              bent(r, t.nodes.get(id[i][j]), t.nodes.get(id[i + 1][j])));
        }
      }
    }
    // remove a fifth of the edges, keeping the network connected
    List<TEdge> order = new ArrayList<>(t.edges);
    java.util.Collections.shuffle(order, r);
    int toRemove = (int) (0.2 * order.size());
    for (TEdge e : order) {
      if (toRemove == 0) {
        break;
      }
      if (connected(t, e)) {
        t.edges.remove(e);
        toRemove--;
      }
    }
    // one-ways: 6 % of the edges
    for (TEdge e : t.edges) {
      e.oneway = r.nextDouble() < 0.06;
    }
    // roundabouts: 15 % of the nodes with three or four edges
    List<Integer> candidates = new ArrayList<>();
    for (int n = 0; n < t.nodes.size(); n++) {
      int d = t.incident(n).size();
      if (d >= 3) {
        candidates.add(n);
      }
    }
    java.util.Collections.shuffle(candidates, r);
    boolean[] ringed = new boolean[t.nodes.size() + 4 * candidates.size() + 8];
    for (int c = 0; c < candidates.size() * 15 / 100; c++) {
      roundabout(r, t, candidates.get(c), ringed);
    }
    // dual carriageways, a side cycleway, spurs, a pendant branch, private roads
    for (int k = 0; k < 1 + r.nextInt(2); k++) {
      dualCarriageway(r, t, ringed);
    }
    cycleway(r, t);
    spurs(r, t);
    pendant(r, t);
    privateRoads(r, t);
    mergeDegreeTwo(t);
    for (TEdge e : t.edges) {
      e.length = 0;
    }
    return t;
  }

  private static void roundabout(Random r, Truth t, int node, boolean[] ringed) {
    List<TEdge> inc = t.incident(node);
    if (inc.size() < 3 || ringed[node]) {
      return;
    }
    final double[] c = t.nodes.get(node);
    inc.sort(
        Comparator.comparingDouble(e -> {
          double[] d = firstDirection(t, e, node);
          return Geo.bearingDeg(0, 0, d[0], d[1]);
        }));
    double rho = 12 + r.nextDouble() * 13;
    int k = inc.size();
    int[] ring = new int[k];
    double[] bearings = new double[k];
    for (int i = 0; i < k; i++) {
      double[] d = firstDirection(t, inc.get(i), node);
      bearings[i] = Math.atan2(d[0], d[1]);
      ring[i] = t.addNode(c[0] + rho * Math.sin(bearings[i]), c[1] + rho * Math.cos(bearings[i]));
      setEnd(t, inc.get(i), node, ring[i]);
    }
    for (int i = 0; i < k; i++) {
      // counter-clockwise: from the arm i to the arm i - 1
      int from = ring[i];
      int to = ring[(i + k - 1) % k];
      double mid = (bearings[i] + bearings[(i + k - 1) % k]) / 2;
      if (Math.abs(bearings[i] - bearings[(i + k - 1) % k]) > Math.PI) {
        mid += Math.PI;
      }
      double[][] pts = {
        t.nodes.get(from), {c[0] + rho * Math.sin(mid), c[1] + rho * Math.cos(mid)}, t.nodes.get(to)
      };
      TEdge arc = edge(r, t, from, to, pts);
      arc.oneway = true;
      arc.way = WayKind.MINOR_ROAD;
      arc.surfaceClass = SurfaceClass.PAVED;
      arc.detail = "asphalt";
      arc.homogeneous = true;
    }
    ringed[node] = true;
  }

  private static void dualCarriageway(Random r, Truth t, boolean[] ringed) {
    // a chain of 2 to 4 two-way edges that go straight on
    List<TEdge> candidates = new ArrayList<>();
    for (TEdge e : t.edges) {
      if (!e.oneway && !e.isPrivate && e.length >= 0) {
        candidates.add(e);
      }
    }
    if (candidates.isEmpty()) {
      return;
    }
    TEdge first = candidates.get(r.nextInt(candidates.size()));
    List<TEdge> chain = new ArrayList<>();
    List<Integer> nodes = new ArrayList<>();
    chain.add(first);
    nodes.add(first.a);
    nodes.add(first.b);
    int want = 2 + r.nextInt(3);
    while (chain.size() < want) {
      int end = nodes.get(nodes.size() - 1);
      TEdge last = chain.get(chain.size() - 1);
      double[] in = firstDirection(t, last, end);
      TEdge best = null;
      double bestTurn = 40;
      for (TEdge e : t.incident(end)) {
        if (e == last || e.oneway || chain.contains(e) || e.a == e.b) {
          continue;
        }
        double[] out = firstDirection(t, e, end);
        double turn =
            Geo.turnAngleDeg(
                Geo.bearingDeg(0, 0, -in[0], -in[1]), Geo.bearingDeg(0, 0, out[0], out[1]));
        if (turn < bestTurn) {
          bestTurn = turn;
          best = e;
        }
      }
      if (best == null) {
        break;
      }
      int next = best.a == end ? best.b : best.a;
      if (nodes.contains(next)) {
        break;
      }
      chain.add(best);
      nodes.add(next);
    }
    if (chain.size() < 2) {
      return;
    }
    for (int n : nodes) {
      if (n < ringed.length && ringed[n]) {
        return;
      }
    }
    double gap = 8 + r.nextDouble() * 32;
    int k = nodes.size();
    double[] p0 = t.nodes.get(nodes.get(0));
    double[] pk = t.nodes.get(nodes.get(k - 1));
    double len = Math.hypot(pk[0] - p0[0], pk[1] - p0[1]);
    double nx = -(pk[1] - p0[1]) / len;
    double ny = (pk[0] - p0[0]) / len;
    int[] left = new int[k];
    for (int i = 0; i < k; i++) {
      double[] p = t.nodes.get(nodes.get(i));
      left[i] = t.addNode(p[0] + nx * gap / 2, p[1] + ny * gap / 2);
    }
    int rightStart = t.addNode(pk[0] - nx * gap / 2, pk[1] - ny * gap / 2);
    int rightEnd = t.addNode(p0[0] - nx * gap / 2, p0[1] - ny * gap / 2);
    // forward carriageway edge by edge on the left, one single backward carriageway on the right
    List<double[]> back = new ArrayList<>();
    List<double[][]> backParts = new ArrayList<>();
    for (int i = 0; i < chain.size(); i++) {
      TEdge old = chain.get(i);
      boolean forward = old.a == nodes.get(i);
      double[][] pts = forward ? old.pts : reversed(old.pts);
      double[][] shifted = new double[pts.length][];
      for (int q = 0; q < pts.length; q++) {
        shifted[q] = new double[] {pts[q][0] + nx * gap / 2, pts[q][1] + ny * gap / 2};
      }
      shifted[0] = t.nodes.get(left[i]);
      shifted[shifted.length - 1] = t.nodes.get(left[i + 1]);
      TEdge fwd = edge(r, t, left[i], left[i + 1], shifted);
      fwd.oneway = true;
      fwd.way = old.way;
      fwd.surfaceClass = SurfaceClass.PAVED;
      fwd.detail = "asphalt";
      fwd.homogeneous = old.homogeneous;
      double[][] rs = new double[pts.length][];
      for (int q = 0; q < pts.length; q++) {
        rs[q] = new double[] {pts[q][0] - nx * gap / 2, pts[q][1] - ny * gap / 2};
      }
      backParts.add(reversed(rs));
    }
    // the backward carriageway runs from the last chain node to the first: last part first
    for (int i = backParts.size() - 1; i >= 0; i--) {
      double[][] part = backParts.get(i);
      for (int q = i == backParts.size() - 1 ? 0 : 1; q < part.length; q++) {
        back.add(part[q]);
      }
    }
    back.set(0, t.nodes.get(rightStart));
    back.set(back.size() - 1, t.nodes.get(rightEnd));
    TEdge bwd = edge(r, t, rightStart, rightEnd, back.toArray(new double[0][]));
    bwd.oneway = true;
    bwd.way = WayKind.MINOR_ROAD;
    bwd.surfaceClass = SurfaceClass.PAVED;
    bwd.detail = "asphalt";
    bwd.homogeneous = true;
    // connectors at both ends, and a cross street at the right end of each (the B1 trap)
    for (int[] pair : new int[][] {{left[0], rightEnd}, {left[k - 1], rightStart}}) {
      double[][] pts = {t.nodes.get(pair[0]), t.nodes.get(pair[1])};
      TEdge c = edge(r, t, pair[0], pair[1], pts);
      c.oneway = false;
      c.way = WayKind.MINOR_ROAD;
      c.surfaceClass = SurfaceClass.PAVED;
      c.detail = "asphalt";
      c.homogeneous = true;
    }
    for (int[] pair : new int[][] {{rightEnd, 0}, {rightStart, 1}}) {
      double[] p = t.nodes.get(pair[0]);
      double ang = r.nextDouble() * Math.PI * 2;
      double sl = 80 + r.nextDouble() * 70;
      int leaf = t.addNode(p[0] + sl * Math.sin(ang), p[1] + sl * Math.cos(ang));
      TEdge s = edge(r, t, pair[0], leaf, new double[][] {p, t.nodes.get(leaf)});
      s.way = WayKind.MINOR_ROAD;
      s.surfaceClass = SurfaceClass.PAVED;
      s.detail = "asphalt";
      s.homogeneous = true;
    }
    // other streets leave the chain nodes from the left node; the old edges are replaced
    for (int i = 0; i < k; i++) {
      for (TEdge e : new ArrayList<>(t.incident(nodes.get(i)))) {
        if (chain.contains(e)) {
          continue;
        }
        setEnd(t, e, nodes.get(i), left[i]);
      }
    }
    t.edges.removeAll(chain);
  }

  private static double[][] reversed(double[][] pts) {
    double[][] out = new double[pts.length][];
    for (int i = 0; i < pts.length; i++) {
      out[i] = pts[pts.length - 1 - i];
    }
    return out;
  }

  private static void cycleway(Random r, Truth t) {
    List<TEdge> long2 = new ArrayList<>();
    for (TEdge e : t.edges) {
      if (e.planar() > 800 && !e.oneway) {
        long2.add(e);
      }
    }
    if (long2.isEmpty()) {
      return;
    }
    TEdge road = long2.get(r.nextInt(long2.size()));
    double side = (r.nextBoolean() ? 1 : -1) * (8 + r.nextDouble() * 7);
    double[][] pts = new double[road.pts.length][];
    for (int i = 0; i < pts.length; i++) {
      double[] p = road.pts[i];
      double[] q = road.pts[Math.min(i + 1, pts.length - 1)];
      double[] o = road.pts[Math.max(i - 1, 0)];
      double dx = q[0] - o[0];
      double dy = q[1] - o[1];
      double len = Math.hypot(dx, dy);
      double ramp = i == 0 || i == pts.length - 1 ? 0 : 1;
      pts[i] = new double[] {p[0] - dy / len * side * ramp, p[1] + dx / len * side * ramp};
    }
    TEdge c = edge(r, t, road.a, road.b, pts);
    c.way = WayKind.CYCLEWAY;
    c.surfaceClass = SurfaceClass.PAVED;
    c.detail = "asphalt";
    c.homogeneous = true;
  }

  private static void spurs(Random r, Truth t) {
    int count = 2 + r.nextInt(3);
    int nodes = t.nodes.size();
    for (int k = 0; k < count; k++) {
      int from = r.nextInt(nodes);
      if (t.incident(from).size() < 2) {
        continue;
      }
      double[] p = t.nodes.get(from);
      double ang = r.nextDouble() * Math.PI * 2;
      double len = 300 + r.nextDouble() * 500;
      int leaf = t.addNode(p[0] + len * Math.sin(ang), p[1] + len * Math.cos(ang));
      TEdge e = edge(r, t, from, leaf, bent(r, p, t.nodes.get(leaf)));
      e.way = WayKind.MINOR_ROAD;
      e.surfaceClass = SurfaceClass.PAVED;
      e.detail = "asphalt";
    }
  }

  private static void pendant(Random r, Truth t) {
    int from = r.nextInt(t.nodes.size());
    if (t.incident(from).size() < 2) {
      return;
    }
    double[] p = t.nodes.get(from);
    double ang = r.nextDouble() * Math.PI * 2;
    double len = 1000 + r.nextDouble() * 2000;
    double[] q = {p[0] + len * Math.sin(ang), p[1] + len * Math.cos(ang)};
    int j = t.addNode(q[0], q[1]);
    TEdge stem = edge(r, t, from, j, bent(r, p, q));
    stem.way = WayKind.MINOR_ROAD;
    stem.surfaceClass = SurfaceClass.PAVED;
    stem.detail = "asphalt";
    // a small loop at the far end
    double side = 350;
    double[] a = {q[0] + side * Math.sin(ang + 1.0), q[1] + side * Math.cos(ang + 1.0)};
    double[] b = {q[0] + side * Math.sin(ang - 1.0), q[1] + side * Math.cos(ang - 1.0)};
    int na = t.addNode(a[0], a[1]);
    int nb = t.addNode(b[0], b[1]);
    for (int[] e : new int[][] {{j, na}, {na, nb}, {nb, j}}) {
      TEdge x = edge(r, t, e[0], e[1], new double[][] {t.nodes.get(e[0]), t.nodes.get(e[1])});
      x.way = WayKind.MINOR_ROAD;
      x.surfaceClass = SurfaceClass.PAVED;
      x.detail = "asphalt";
    }
  }

  private static void privateRoads(Random r, Truth t) {
    int nodes = Math.min(t.nodes.size(), 40);
    for (int k = 0; k < 2; k++) {
      int a = r.nextInt(nodes);
      int b = r.nextInt(nodes);
      double[] pa = t.nodes.get(a);
      double[] pb = t.nodes.get(b);
      double d = Math.hypot(pa[0] - pb[0], pa[1] - pb[1]);
      if (a == b || d < 800 || d > 2500 || t.incident(a).isEmpty() || t.incident(b).isEmpty()) {
        continue;
      }
      TEdge e = edge(r, t, a, b, bent(r, pa, pb));
      e.isPrivate = true;
      e.way = WayKind.MINOR_ROAD;
      e.surfaceClass = SurfaceClass.PAVED;
      e.detail = "asphalt";
      e.homogeneous = true;
    }
  }

  /** Nodes with two edges are not nodes in api 1.7: join the two edges when they are alike. */
  private static void mergeDegreeTwo(Truth t) {
    boolean changed = true;
    while (changed) {
      changed = false;
      for (int n = 0; n < t.nodes.size() && !changed; n++) {
        List<TEdge> inc = t.incident(n);
        if (inc.size() != 2) {
          continue;
        }
        TEdge e1 = inc.get(0);
        TEdge e2 = inc.get(1);
        if (e1 == e2 || e1.a == e1.b || e2.a == e2.b || e1.isPrivate != e2.isPrivate) {
          continue;
        }
        // orient e1 to end at n and e2 to start at n
        boolean r1 = e1.b != n;
        boolean r2 = e2.a != n;
        boolean ow1 = e1.oneway;
        boolean ow2 = e2.oneway;
        if (ow1 != ow2) {
          continue;
        }
        int a = r1 ? e1.b : e1.a;
        int b = r2 ? e2.a : e2.b;
        if (a == b || a == n || b == n) {
          continue;
        }
        // a one-way pair must run the same way through n
        if (ow1 && (r1 != r2)) {
          continue;
        }
        double[][] p1 = r1 ? reversed(e1.pts) : e1.pts;
        double[][] p2 = r2 ? reversed(e2.pts) : e2.pts;
        double[][] pts = new double[p1.length + p2.length - 1][];
        System.arraycopy(p1, 0, pts, 0, p1.length);
        System.arraycopy(p2, 1, pts, p1.length, p2.length - 1);
        TEdge m = new TEdge();
        m.a = a;
        m.b = b;
        m.pts = pts;
        m.way = e1.way;
        m.surfaceClass = e1.surfaceClass;
        m.detail = e1.detail;
        m.source = e1.source;
        m.homogeneous = e1.homogeneous && e2.homogeneous;
        m.oneway = ow1;
        m.isPrivate = e1.isPrivate;
        boolean reversedPair = ow1 && r1;
        if (reversedPair) {
          m.a = b;
          m.b = a;
          m.pts = reversed(pts);
        }
        t.edges.remove(e1);
        t.edges.remove(e2);
        t.edges.add(m);
        changed = true;
      }
    }
  }

  // ---- tracks -----------------------------------------------------------------------------------

  private static double elevation(double x, double y) {
    return 50 * Math.sin(x / 3000) + 40 * Math.cos(y / 2500);
  }

  private static final class Walker {
    final Random r;
    final Truth t;
    final LocalProjection proj;
    final TrackKind kind;
    final boolean excluded;
    final boolean drift;
    final double driftDx;
    final double driftDy;
    final List<TrackEdge> out = new ArrayList<>();
    final int[] degree;

    Walker(
        Random r, Truth t, LocalProjection proj, TrackKind kind, boolean excluded, int[] degree) {
      this.r = r;
      this.t = t;
      this.proj = proj;
      this.kind = kind;
      this.excluded = excluded;
      this.degree = degree;
      this.drift = r.nextDouble() < 0.10;
      double ang = r.nextDouble() * Math.PI * 2;
      double d = 1 + r.nextDouble();
      this.driftDx = d * Math.sin(ang);
      this.driftDy = d * Math.cos(ang);
    }

    NodeRef ref(int node) {
      double[] p = t.nodes.get(node);
      double x = p[0] + (drift ? driftDx : 0);
      double y = p[1] + (drift ? driftDy : 0);
      return new NodeRef((drift ? "v2:" : "n:") + node, proj.toLatLon(x, y), degree[node]);
    }

    /** Emits the part [o1, o2] (metres from the start of travel) of an edge ridden in a direction. */
    void emit(TEdge e, boolean forward, double o1, double o2, boolean unknownAllowed) {
      double len = e.length;
      double scale = e.planar() / len;
      double[][] pts = forward ? e.pts : reversed(e.pts);
      double[] xs = new double[pts.length];
      double[] ys = new double[pts.length];
      for (int i = 0; i < pts.length; i++) {
        xs[i] = pts[i][0];
        ys[i] = pts[i][1];
      }
      double[][] sl = Geo.slice(xs, ys, o1 * scale, o2 * scale);
      List<LatLon> geometry = new ArrayList<>();
      double gain = 0;
      double loss = 0;
      for (int i = 0; i < sl[0].length; i++) {
        double nx = (r.nextDouble() * 2 - 1) * 0.28;
        double ny = (r.nextDouble() * 2 - 1) * 0.28;
        geometry.add(proj.toLatLon(sl[0][i] + nx, sl[1][i] + ny));
        if (i > 0) {
          double dz = elevation(sl[0][i], sl[1][i]) - elevation(sl[0][i - 1], sl[1][i - 1]);
          if (dz > 0) {
            gain += dz;
          } else {
            loss -= dz;
          }
        }
      }
      int fromNode = forward ? e.a : e.b;
      int toNode = forward ? e.b : e.a;
      boolean partial = !(o1 <= 0.5 && o2 >= len - 0.5);
      NodeRef from = ref(fromNode);
      NodeRef to = ref(toNode);
      Double lengthM = len;
      Double fromOffset = o1;
      Double toOffset = o2;
      if (partial && unknownAllowed && len > 400 && r.nextDouble() < 0.05) {
        if (o1 > 0.5) {
          from = null;
          lengthM = null;
          fromOffset = null;
          toOffset = null;
        } else if (o2 < len - 0.5) {
          to = null;
          lengthM = null;
        }
      }
      Oneway ow = Oneway.BOTH;
      if (e.oneway) {
        ow = forward ? Oneway.FORWARD : Oneway.AGAINST;
      }
      EdgeSurface surface =
          e.homogeneous ? new EdgeSurface(e.surfaceClass, e.detail, e.source) : null;
      WayKind way = e.homogeneous ? e.way : null;
      out.add(
          new TrackEdge(
              from,
              to,
              partial,
              lengthM,
              o2 - o1,
              fromOffset,
              toOffset,
              ow,
              geometry,
              gain,
              loss,
              surface,
              way,
              null,
              null,
              null));
      if (!excluded) {
        e.ridden.add(kind);
      }
    }
  }

  private static boolean roadLike(TEdge e) {
    return e.way != WayKind.PATH
        && e.way != WayKind.FOOTWAY
        && e.way != WayKind.STEPS
        && e.surfaceClass != SurfaceClass.UNPAVED;
  }

  private static void walk(
      Random r,
      Truth t,
      Walker w,
      TEdge startEdge,
      double startOffset,
      boolean startForward,
      double targetM) {
    TEdge e = startEdge;
    boolean forward = startForward;
    double o1 = startOffset;
    double total = 0;
    int guard = 0;
    boolean first = true;
    while (guard++ < 400) {
      double len = e.length;
      double remaining = len - o1;
      boolean last = total + remaining >= targetM;
      if (last && r.nextDouble() < 0.7 && remaining > 20) {
        double stop = Math.max(o1 + 5, Math.min(len - 5, o1 + (targetM - total)));
        w.emit(e, forward, o1, stop, true);
        return;
      }
      // a U-turn in the middle of the edge
      if (!last && !e.oneway && r.nextDouble() < 0.03 && remaining > 60 && o1 < 1) {
        double stop = 10 + r.nextDouble() * (len - 20);
        w.emit(e, forward, o1, stop, false);
        w.emit(e, !forward, len - stop, len, false);
        total += 2 * stop;
        forward = !forward; // back at the start node, ready to take another edge
        int node = forward ? e.b : e.a;
        TEdge next = chooseNext(r, t, w, node, e);
        if (next == null) {
          return;
        }
        e = next;
        forward = e.a == node;
        o1 = 0;
        continue;
      }
      w.emit(e, forward, o1, len, first);
      first = false;
      total += remaining;
      if (last) {
        return;
      }
      int node = forward ? e.b : e.a;
      TEdge next = chooseNext(r, t, w, node, e);
      if (next == null) {
        return;
      }
      if (next == e) { // dead end: ride back
        forward = !forward;
      } else {
        forward = next.a == node;
        if (next.a == next.b) {
          return;
        }
      }
      e = next;
      o1 = 0;
    }
  }

  private static @Nullable TEdge chooseNext(Random r, Truth t, Walker w, int node, TEdge from) {
    List<TEdge> options = new ArrayList<>();
    List<TEdge> inc = t.incident(node);
    for (TEdge e : inc) {
      if (e == from && inc.size() > 1) {
        continue;
      }
      boolean fwd = e.a == node;
      if (e.oneway && !fwd && r.nextDouble() >= 0.03) {
        continue;
      }
      if (e.isPrivate && !w.excluded) {
        continue;
      }
      options.add(e);
    }
    if (options.isEmpty()) {
      return inc.size() == 1 && !from.oneway ? from : null; // a dead end
    }
    if (w.kind == TrackKind.ROAD && r.nextDouble() < 0.9) {
      List<TEdge> roads = new ArrayList<>();
      for (TEdge e : options) {
        if (roadLike(e)) {
          roads.add(e);
        }
      }
      if (!roads.isEmpty()) {
        options = roads;
      }
    }
    return options.get(r.nextInt(options.size()));
  }

  static Generated generate(Random r) {
    LocalProjection proj = new LocalProjection(45, 5);
    Truth t = truth(r);
    for (TEdge e : t.edges) {
      double len = 0;
      for (int i = 1; i < e.pts.length; i++) {
        len +=
            TestNetwork.haversine(
                proj.toLatLon(e.pts[i - 1][0], e.pts[i - 1][1]),
                proj.toLatLon(e.pts[i][0], e.pts[i][1]));
      }
      e.length = len;
    }
    // drop edges nobody can ride and nodes they leave isolated
    int[] degree = new int[t.nodes.size()];
    for (int n = 0; n < degree.length; n++) {
      List<Integer> neighbours = new ArrayList<>();
      for (TEdge e : t.incident(n)) {
        int o = e.a == n ? e.b : e.a;
        if (!neighbours.contains(o)) {
          neighbours.add(o);
        }
      }
      degree[n] = neighbours.size() == 2 ? 3 : neighbours.size();
    }
    // the team location: 20 to 80 % along a random public edge
    List<TEdge> publicEdges = new ArrayList<>();
    for (TEdge e : t.edges) {
      if (!e.isPrivate && e.length > 300 && !e.oneway && roadLike(e)) {
        publicEdges.add(e);
      }
    }
    TEdge teamEdge = publicEdges.get(r.nextInt(publicEdges.size()));
    double teamOffset = teamEdge.length * (0.2 + 0.6 * r.nextDouble());
    double[][] tp = teamEdge.pts;
    double[] txy =
        Geo.pointAt(col(tp, 0), col(tp, 1), teamOffset * teamEdge.planar() / teamEdge.length);

    int count = 40 + r.nextInt(81);
    List<TrackInput> tracks = new ArrayList<>();
    List<TEdge> privateEdges = new ArrayList<>();
    for (TEdge e : t.edges) {
      if (e.isPrivate) {
        privateEdges.add(e);
      }
    }
    for (int i = 0; i < count; i++) {
      double kx = r.nextDouble();
      TrackKind kind =
          kx < 0.70
              ? TrackKind.ROAD
              : kx < 0.90 ? TrackKind.GRAVEL : kx < 0.97 ? TrackKind.MIXED : TrackKind.MTB;
      boolean excluded = !privateEdges.isEmpty() && r.nextDouble() < 0.05;
      Walker w = new Walker(r, t, proj, kind, excluded, degree);
      double target = 5000 + r.nextDouble() * 35000;
      if (excluded) {
        TEdge p = privateEdges.get(r.nextInt(privateEdges.size()));
        walk(r, t, w, p, 0, true, target / 4);
      } else if (r.nextDouble() < 0.7) {
        boolean fwd = r.nextBoolean();
        walk(r, t, w, teamEdge, fwd ? teamOffset : teamEdge.length - teamOffset, fwd, target);
      } else {
        TEdge e = t.edges.get(r.nextInt(t.edges.size()));
        if (e.isPrivate || e.length < 40) {
          continue;
        }
        walk(
            r,
            t,
            w,
            e,
            e.length * (0.1 + 0.8 * r.nextDouble()),
            !e.oneway ? r.nextBoolean() : true,
            target);
      }
      if (!w.out.isEmpty()) {
        tracks.add(new TrackInput(1000 + i, excluded, kind, w.out));
      }
    }
    return new Generated(tracks, t, proj.toLatLon(txy[0], txy[1]), txy[0], txy[1], proj);
  }

  private static double[] col(double[][] pts, int c) {
    double[] out = new double[pts.length];
    for (int i = 0; i < pts.length; i++) {
      out[i] = pts[i][c];
    }
    return out;
  }
}
