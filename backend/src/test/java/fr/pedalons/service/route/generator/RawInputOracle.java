package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Judges a generated route against the raw {@link TrackInput}s only (design §12.9, review M6):
 * no {@link NetworkGraph}, builder, {@link QueryGraph}, {@link Geo} or {@link LocalProjection} is
 * used, so a bug of the builder cannot hide here. It has its own haversine-free local metres.
 *
 * <p>Nine checks, each message starting with its number: 1 index of the live and excluded
 * segments, 2 the route stays on live input, 3 one-way directions, 4 turns at junction nodes, 5
 * folds, 6 reuse bounded to the ends, 7 distances, 8 ends, 9 ride type. Two deliberate
 * relaxations of the written design: the ends (8) are matched to the nearest live input
 * <em>segment</em> (long straight edges have no vertex near a start) within {@code snapToNodeM +
 * 12} m (a snap within 30 m of a node becomes the node), and a reused stretch only
 * counts from 40 m on (two roads crossing at a shallow angle share a few metres).
 */
final class RawInputOracle {
  private RawInputOracle() {}

  private static final double R = 6_371_008.8;
  private static final double CELL = 25;
  private static final double STEP = 5;
  private static final double NEAR = 4;
  private static final double AXIS = 30;

  /** One input segment with its observation. */
  private record Seg(
      double x1,
      double y1,
      double x2,
      double y2,
      TrackInput track,
      TrackEdge edge,
      boolean live,
      double bearing) {
    Seg(
        double x1,
        double y1,
        double x2,
        double y2,
        TrackInput track,
        TrackEdge edge,
        boolean live) {
      this(x1, y1, x2, y2, track, edge, live, RawInputOracle.bearing(x1, y1, x2, y2));
    }

    // identity: the records hold whole geometries, hashing them is slow
    @Override
    public boolean equals(Object o) {
      return this == o;
    }

    @Override
    public int hashCode() {
      return System.identityHashCode(this);
    }
  }

  private static final class Frame {
    final double lat0;
    final double lon0;

    Frame(double lat0, double lon0) {
      this.lat0 = lat0;
      this.lon0 = lon0;
    }

    double x(LatLon p) {
      return R * Math.toRadians(p.lon() - lon0) * Math.cos(Math.toRadians(lat0));
    }

    double y(LatLon p) {
      return R * Math.toRadians(p.lat() - lat0);
    }
  }

  private static double bearing(double x1, double y1, double x2, double y2) {
    double d = Math.toDegrees(Math.atan2(x2 - x1, y2 - y1));
    return d < 0 ? d + 360 : d;
  }

  private static double angle(double a, double b) {
    double d = Math.abs(a - b) % 360;
    return d > 180 ? 360 - d : d;
  }

  /** Angle between two axes (directions without sense), 0..90. */
  private static double axis(double a, double b) {
    double d = angle(a, b);
    return d > 90 ? 180 - d : d;
  }

  private static final class Index {
    final Map<Long, List<Seg>> cells = new HashMap<>();

    static long key(long cx, long cy) {
      return cx * 4_000_037L + cy;
    }

    void add(Seg s) {
      // the cells the segment passes through (sampled at half a cell), not its bounding box
      double len = Math.hypot(s.x2 - s.x1, s.y2 - s.y1);
      int pieces = Math.max(1, (int) Math.ceil(len / (CELL / 2)));
      long last = Long.MIN_VALUE;
      for (int k = 0; k <= pieces; k++) {
        double t = (double) k / pieces;
        long cx = (long) Math.floor((s.x1 + t * (s.x2 - s.x1)) / CELL);
        long cy = (long) Math.floor((s.y1 + t * (s.y2 - s.y1)) / CELL);
        long key = key(cx, cy);
        if (key != last) {
          cells.computeIfAbsent(key, kk -> new ArrayList<>()).add(s);
          last = key;
        }
      }
    }

    /** Segments in the cells around a point (candidates only). */
    List<Seg> around(double x, double y) {
      List<Seg> out = new ArrayList<>();
      long cx = (long) Math.floor(x / CELL);
      long cy = (long) Math.floor(y / CELL);
      for (long dx = -1; dx <= 1; dx++) {
        for (long dy = -1; dy <= 1; dy++) {
          List<Seg> l = cells.get(key(cx + dx, cy + dy));
          if (l != null) {
            for (Seg s : l) {
              out.add(s);
            }
          }
        }
      }
      return out;
    }
  }

  private static double distance(double px, double py, Seg s) {
    double dx = s.x2 - s.x1;
    double dy = s.y2 - s.y1;
    double len2 = dx * dx + dy * dy;
    double t =
        len2 == 0 ? 0 : Math.max(0, Math.min(1, ((px - s.x1) * dx + (py - s.y1) * dy) / len2));
    return Math.hypot(px - (s.x1 + t * dx), py - (s.y1 + t * dy));
  }

  /** Length of the input geometry of an observation. */
  private static double edgeLength(Frame f, TrackEdge e) {
    double len = 0;
    List<LatLon> g = e.geometry();
    for (int i = 1; i < g.size(); i++) {
      len += Math.hypot(f.x(g.get(i)) - f.x(g.get(i - 1)), f.y(g.get(i)) - f.y(g.get(i - 1)));
    }
    return len;
  }

  private static double[] nearestPoint(double px, double py, Seg s) {
    double dx = s.x2 - s.x1;
    double dy = s.y2 - s.y1;
    double len2 = dx * dx + dy * dy;
    double t =
        len2 == 0 ? 0 : Math.max(0, Math.min(1, ((px - s.x1) * dx + (py - s.y1) * dy) / len2));
    return new double[] {s.x1 + t * dx, s.y1 + t * dy};
  }

  /** The route resampled every STEP metres, with cumulative offsets. */
  private static final class Route {
    final List<double[]> pts = new ArrayList<>(); // x, y, offset
    final double[] cx;
    final double[] cy;
    final double[] cum;
    final double length;

    Route(List<double[]> raw) {
      int n = raw.size();
      cx = new double[n];
      cy = new double[n];
      cum = new double[n];
      for (int i = 0; i < n; i++) {
        cx[i] = raw.get(i)[0];
        cy[i] = raw.get(i)[1];
        if (i > 0) {
          cum[i] = cum[i - 1] + Math.hypot(cx[i] - cx[i - 1], cy[i] - cy[i - 1]);
        }
      }
      length = n == 0 ? 0 : cum[n - 1];
      for (double off = 0; off <= length + 1e-9; off += STEP) {
        double[] p = at(off);
        pts.add(new double[] {p[0], p[1], off});
      }
    }

    double[] at(double off) {
      double o = Math.max(0, Math.min(length, off));
      int lo = 0;
      int hi = cum.length - 1;
      while (hi - lo > 1) {
        int mid = (lo + hi) >>> 1;
        if (cum[mid] <= o) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      if (cum.length == 1) {
        return new double[] {cx[0], cy[0]};
      }
      double seg = cum[hi] - cum[lo];
      double t = seg == 0 ? 0 : (o - cum[lo]) / seg;
      return new double[] {cx[lo] + t * (cx[hi] - cx[lo]), cy[lo] + t * (cy[hi] - cy[lo])};
    }

    double heading(double fromOff, double toOff) {
      double[] a = at(fromOff);
      double[] b = at(toOff);
      return bearing(a[0], a[1], b[0], b[1]);
    }
  }

  /** The indexes of one list of tracks, kept for the next route of the same network. */
  private record Prepared(
      List<TrackInput> tracks,
      Frame frame,
      Index live,
      Index excluded,
      List<double[]> nodes,
      Map<String, Set<TrackKind>> kindsByStreet,
      Map<Long, List<double[][]>> chains) {}

  private static Prepared cached;

  /** Key of a node without the data-version prefix of the realistic networks ("n:", "v2:"). */
  private static String plain(NodeRef ref) {
    String k = ref.key();
    int colon = k.indexOf(':');
    return colon >= 0 ? k.substring(colon + 1) : k;
  }

  /** The street an observation belongs to: its pair of ends, and each known end on its own. */
  private static List<String> streets(TrackEdge e) {
    List<String> out = new ArrayList<>();
    if (e.from() != null && e.to() != null) {
      String a = plain(e.from());
      String b = plain(e.to());
      out.add(a.compareTo(b) < 0 ? a + "|" + b : b + "|" + a);
    } else if (e.from() != null) {
      out.add("end " + plain(e.from()));
    } else if (e.to() != null) {
      out.add("end " + plain(e.to()));
    }
    return out;
  }

  /**
   * The ride of each live track as polylines: consecutive input edges joined while each starts
   * within 12 m of where the previous one stopped. Each polyline is {x[], y[], cumulative length[]}.
   */
  private static Map<Long, List<double[][]>> chainsOf(List<TrackInput> tracks, Frame f) {
    Map<Long, List<double[][]>> out = new HashMap<>();
    for (TrackInput t : tracks) {
      if (t.excluded()) {
        continue;
      }
      List<double[][]> chains = out.computeIfAbsent(t.trackId(), k -> new ArrayList<>());
      List<double[]> cur = new ArrayList<>();
      for (TrackEdge e : t.edges()) {
        List<LatLon> g = e.geometry();
        if (g.size() < 2) {
          continue;
        }
        double fx = f.x(g.get(0));
        double fy = f.y(g.get(0));
        if (!cur.isEmpty()) {
          double[] last = cur.get(cur.size() - 1);
          if (Math.hypot(last[0] - fx, last[1] - fy) > 12) {
            chains.add(toChain(cur));
            cur = new ArrayList<>();
          }
        }
        for (LatLon q : g) {
          double x = f.x(q);
          double y = f.y(q);
          if (cur.isEmpty()
              || Math.hypot(cur.get(cur.size() - 1)[0] - x, cur.get(cur.size() - 1)[1] - y)
                  >= 0.01) {
            cur.add(new double[] {x, y});
          }
        }
      }
      if (cur.size() >= 2) {
        chains.add(toChain(cur));
      }
    }
    return out;
  }

  private static double[][] toChain(List<double[]> pts) {
    int n = pts.size();
    double[] xs = new double[n];
    double[] ys = new double[n];
    double[] cum = new double[n];
    for (int i = 0; i < n; i++) {
      xs[i] = pts.get(i)[0];
      ys[i] = pts.get(i)[1];
      if (i > 0) {
        cum[i] = cum[i - 1] + Math.hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]);
      }
    }
    return new double[][] {xs, ys, cum};
  }

  /**
   * Did the track ride the route from offset {@code from} to {@code to} in one pass: its own
   * polyline passes under every sample (within NEAR), the position along the polyline always
   * advancing with the route (or always going back, the track ridden the other way), by about the
   * step between two samples? A track that rode the same places at other moments of its ride has
   * far-apart positions there and fails.
   */
  private static boolean ridesInOnePass(List<double[][]> chains, Route rt, double from, double to) {
    List<double[]> samples = new ArrayList<>();
    for (double off = from; ; off += STEP) {
      double o = Math.min(off, to);
      samples.add(rt.at(o));
      if (o >= to) {
        break;
      }
    }
    for (double[][] chain : chains) {
      List<double[]> cand = new ArrayList<>();
      for (double[] pt : samples) {
        cand.add(positions(chain, pt[0], pt[1]));
      }
      for (int dir = 0; dir < 2; dir++) {
        double[] reach = cand.get(0);
        for (int k = 1; k < cand.size() && reach.length > 0; k++) {
          List<Double> next = new ArrayList<>();
          for (double c : cand.get(k)) {
            for (double r : reach) {
              double d = dir == 0 ? c - r : r - c;
              if (d >= -0.5 && d <= 3 * STEP) {
                next.add(c);
                break;
              }
            }
          }
          reach = next.stream().mapToDouble(Double::doubleValue).toArray();
        }
        if (reach.length > 0) {
          return true;
        }
      }
    }
    return false;
  }

  /** Positions along a polyline of the points within NEAR of (x, y), one per segment. */
  private static double[] positions(double[][] chain, double x, double y) {
    double[] xs = chain[0];
    double[] ys = chain[1];
    double[] cum = chain[2];
    List<Double> out = new ArrayList<>();
    for (int i = 1; i < xs.length; i++) {
      double dx = xs[i] - xs[i - 1];
      double dy = ys[i] - ys[i - 1];
      double len2 = dx * dx + dy * dy;
      double t =
          len2 == 0
              ? 0
              : Math.max(0, Math.min(1, ((x - xs[i - 1]) * dx + (y - ys[i - 1]) * dy) / len2));
      double px = xs[i - 1] + t * dx;
      double py = ys[i - 1] + t * dy;
      if (Math.hypot(px - x, py - y) <= NEAR) {
        out.add(cum[i - 1] + t * Math.sqrt(len2));
      }
    }
    return out.stream().mapToDouble(Double::doubleValue).toArray();
  }

  private static synchronized Prepared prepare(List<TrackInput> tracks, GeneratorRequest r) {
    if (cached != null && cached.tracks == tracks) {
      return cached;
    }
    Frame f = new Frame(r.start().lat(), r.start().lon());
    Index live = new Index();
    Index excluded = new Index();
    List<double[]> nodes = new ArrayList<>(); // x, y of live junction nodes (streetDegree != 2)
    Set<String> seenNodes = new HashSet<>();
    Map<String, Set<TrackKind>> kindsByStreet = new HashMap<>();
    for (TrackInput t : tracks) {
      for (TrackEdge e : t.edges()) {
        if (!t.excluded()) {
          for (String street : streets(e)) {
            kindsByStreet.computeIfAbsent(street, k -> new HashSet<>()).add(t.kind());
          }
        }
        List<LatLon> g = e.geometry();
        for (int i = 1; i < g.size(); i++) {
          Seg s =
              new Seg(
                  f.x(g.get(i - 1)),
                  f.y(g.get(i - 1)),
                  f.x(g.get(i)),
                  f.y(g.get(i)),
                  t,
                  e,
                  !t.excluded());
          (t.excluded() ? excluded : live).add(s);
        }
        if (!t.excluded()) {
          for (NodeRef ref : new NodeRef[] {e.from(), e.to()}) {
            if (ref != null && ref.streetDegree() != 2 && seenNodes.add(ref.key())) {
              nodes.add(new double[] {f.x(ref.position()), f.y(ref.position())});
            }
          }
        }
      }
    }
    cached = new Prepared(tracks, f, live, excluded, nodes, kindsByStreet, chainsOf(tracks, f));
    return cached;
  }

  static List<String> violations(
      List<TrackInput> tracks, GeneratorRequest r, GeneratedRoute route, GeneratorParameters p) {
    List<String> out = new ArrayList<>();
    Prepared prep = prepare(tracks, r);
    Frame f = prep.frame;
    Index live = prep.live;
    Index excluded = prep.excluded;
    List<double[]> nodes = prep.nodes;
    List<double[]> raw = new ArrayList<>();
    for (LatLon q : route.points()) {
      raw.add(new double[] {f.x(q), f.y(q)});
    }
    if (raw.size() < 2) {
      out.add("2 route has fewer than two points");
      return out;
    }
    Route rt = new Route(raw);
    double d = r.distanceM();

    // edges of the start and the end: the piece toward the nearer end node stays allowed when
    // no admitted edge was in reach (see Snapper and EdgeWeights.banned)
    Set<TrackEdge> endEdges =
        java.util.Collections.newSetFromMap(new java.util.IdentityHashMap<>());
    for (double[] pt : new double[][] {rt.at(0), rt.at(rt.length)}) {
      for (Seg s : live.around(pt[0], pt[1])) {
        if (distance(pt[0], pt[1], s) <= NEAR) {
          endEdges.add(s.edge);
        }
      }
    }

    Index2 grid = new Index2(rt);

    // 2, 3, 9: per sample
    int reportedOff = 0;
    int reportedWay = 0;
    int reportedType = 0;
    for (double[] sp : rt.pts) {
      double x = sp[0];
      double y = sp[1];
      double off = sp[2];
      List<Seg> near = new ArrayList<>();
      double nearestLive = Double.POSITIVE_INFINITY;
      for (Seg s : live.around(x, y)) {
        double dist = distance(x, y, s);
        nearestLive = Math.min(nearestLive, dist);
        if (dist <= NEAR) {
          near.add(s);
        }
      }
      if (near.isEmpty()) {
        if (reportedOff++ < 3) {
          double nearestExcluded = Double.POSITIVE_INFINITY;
          for (Seg s : excluded.around(x, y)) {
            nearestExcluded = Math.min(nearestExcluded, distance(x, y, s));
          }
          out.add(
              String.format(
                  "2 on input: sample at %.0f m is %.1f m from live input (%.1f m from excluded)",
                  off, nearestLive, nearestExcluded));
        }
        continue;
      }
      double beta = rt.heading(off - 10, off + 10);
      List<Seg> compatible = new ArrayList<>();
      for (Seg s : near) {
        if (axis(s.bearing, beta) <= AXIS) {
          compatible.add(s);
        }
      }
      // 3. direction: judged on the heading just before and just after the sample, so that a
      // corner (where the 20 m window straddles two streets) is not mistaken for a wrong way
      boolean wayOk = false;
      StringBuilder seen = new StringBuilder();
      for (double hb : new double[] {rt.heading(off - 8, off), rt.heading(off, off + 8)}) {
        boolean anyOneway = false;
        boolean travelled = false;
        for (Seg s : near) {
          if (axis(s.bearing, hb) <= AXIS) {
            if (s.edge.oneway() != Oneway.BOTH) {
              anyOneway = true;
            }
            if (angle(s.bearing, hb) <= AXIS) {
              travelled = true;
            }
          }
        }
        if (!anyOneway || travelled) {
          wayOk = true;
        }
      }
      if (!wayOk && reportedWay++ < 3) {
        for (Seg sg : compatible) {
          seen.append(
              String.format(
                  " [%s %.0f deg track %d]", sg.edge.oneway(), sg.bearing, sg.track.trackId()));
        }
        out.add(
            String.format(
                "3 direction: sample at %.0f m (heading %.0f) rides a one-way against any"
                    + " observation:%s",
                off, beta, seen));
      }
      // 9. type: same two headings, an observation of a street that admits the type is enough
      boolean typeOk = false;
      boolean anyCompatible = false;
      for (double hb : new double[] {rt.heading(off - 8, off), rt.heading(off, off + 8)}) {
        List<Seg> comp = new ArrayList<>();
        for (Seg s : near) {
          if (axis(s.bearing, hb) <= AXIS) {
            comp.add(s);
          }
        }
        if (comp.isEmpty()) {
          continue;
        }
        anyCompatible = true;
        Set<TrackKind> kinds = new HashSet<>();
        for (Seg s : comp) {
          kinds.add(s.track.kind());
          for (String street : streets(s.edge)) {
            Set<TrackKind> known = prep.kindsByStreet.get(street);
            if (known != null) {
              kinds.addAll(known);
            }
          }
          if (endEdges.contains(s.edge)
              && Math.min(off, rt.length - off) <= edgeLength(f, s.edge) + NEAR) {
            typeOk = true; // the piece of S or E toward the end of a forbidden edge that leads on
          }
        }
        for (Seg s : comp) {
          if (admits(r.type(), s.edge, kinds)) {
            typeOk = true;
          }
        }
      }
      if (anyCompatible && !typeOk && reportedType++ < 3) {
        out.add(
            String.format(
                "9 type %s: sample at %.0f m is on no observation that admits it", r.type(), off));
      }
    }

    // 4. turns at junction nodes, alone and over clusters of junctions closer than 100 m
    double maxTurn = p.maxTurnDeg();
    List<double[]> passes = new ArrayList<>(); // offset, node x, node y
    for (double[] node : nodes) {
      List<Double> offsets = grid.within(node[0], node[1], 3);
      // one pass per cluster of samples, at the sample closest to the node
      int k = 0;
      while (k < offsets.size()) {
        int end = k;
        while (end + 1 < offsets.size() && offsets.get(end + 1) - offsets.get(end) < 20) {
          end++;
        }
        double bestX = offsets.get(k);
        double bestD = Double.POSITIVE_INFINITY;
        for (int q = k; q <= end; q++) {
          double[] pt = rt.at(offsets.get(q));
          double dist = Math.hypot(pt[0] - node[0], pt[1] - node[1]);
          if (dist < bestD) {
            bestD = dist;
            bestX = offsets.get(q);
          }
        }
        if (bestX > 60 && bestX < rt.length - 60) {
          passes.add(new double[] {bestX, node[0], node[1]});
        }
        k = end + 1;
      }
    }
    passes.sort(java.util.Comparator.comparingDouble(q -> q[0]));
    int reportedTurn = 0;
    for (int a = 0; a < passes.size(); a++) {
      for (int b = a; b < passes.size() && passes.get(b)[0] - passes.get(a)[0] <= 100; b++) {
        double xa = passes.get(a)[0];
        double xb = passes.get(b)[0];
        double turn = angle(rt.heading(xa - 50, xa - 30), rt.heading(xb + 30, xb + 50));
        double[] chord = {passes.get(b)[1] - passes.get(a)[1], passes.get(b)[2] - passes.get(a)[2]};
        if (turn >= maxTurn
            && !hairpinTheTeamRides(prep, live, rt, grid, xa, xb, chord)
            && reportedTurn++ < 3) {
          out.add(
              String.format(
                  "4 turn of %.0f degrees over the junction(s) between %.0f m and %.0f m",
                  turn, xa, xb));
        }
      }
    }

    // 5. folds
    for (double[] sp : rt.pts) {
      double x = sp[2];
      if (x < 40 || x > rt.length - 40) {
        continue;
      }
      double[] a = rt.at(x - 40);
      double[] b = rt.at(x + 40);
      if (Math.hypot(a[0] - b[0], a[1] - b[1]) <= 8
          && angle(rt.heading(x - 40, x), rt.heading(x, x + 40)) >= maxTurn) {
        out.add(String.format("5 fold at %.0f m", x));
        break;
      }
    }

    // 6. reuse
    double zone = p.tailMaxShare() * d + 30;
    boolean[] reused = new boolean[rt.pts.size()];
    double[] headings = new double[reused.length];
    for (int i = 0; i < reused.length; i++) {
      headings[i] = rt.heading(rt.pts.get(i)[2] - 10, rt.pts.get(i)[2] + 10);
    }
    for (int i = 0; i < reused.length; i++) {
      double[] sp = rt.pts.get(i);
      double beta = headings[i];
      for (double[] sq : grid.samplesAround(sp[0], sp[1])) {
        if (Math.abs(sq[2] - sp[2]) < 100) {
          continue;
        }
        if (Math.hypot(sp[0] - sq[0], sp[1] - sq[1]) <= NEAR
            && axis(beta, headings[(int) Math.round(sq[2] / STEP)]) <= AXIS) {
          reused[i] = true;
          break;
        }
      }
    }
    int runLen = 0;
    double reusedLen = 0;
    boolean outside = false;
    for (int i = 0; i <= reused.length; i++) {
      if (i < reused.length && reused[i]) {
        runLen++;
      } else {
        if (runLen >= 8) {
          for (int k = i - runLen; k < i; k++) {
            reusedLen += STEP;
            double off = rt.pts.get(k)[2];
            if (off > zone && off < rt.length - zone) {
              outside = true;
            }
          }
        }
        runLen = 0;
      }
    }
    if (outside) {
      out.add("6 reuse outside the first and last " + Math.round(zone) + " m");
    }
    if (reusedLen / 2 > zone) {
      out.add(String.format("6 reused length %.0f m exceeds 2 x %.0f m", reusedLen, zone));
    }

    // 7. distance
    if (Math.abs(rt.length - d) > (p.distanceTolerance() + 0.01) * d) {
      out.add(String.format("7 polyline length %.0f m for a request of %.0f m", rt.length, d));
    }
    if (Math.abs(rt.length - route.distanceM()) > 0.01 * route.distanceM() + 10) {
      out.add(
          String.format(
              "7 polyline length %.0f m but distanceM %.0f m", rt.length, route.distanceM()));
    }

    // 8. ends
    LatLon end = r.end() == null ? r.start() : r.end();
    for (int k = 0; k < 2; k++) {
      LatLon want = k == 0 ? r.start() : end;
      double[] got = k == 0 ? rt.at(0) : rt.at(rt.length);
      double wx = f.x(want);
      double wy = f.y(want);
      double best = Double.POSITIVE_INFINITY;
      double[] bestPoint = null;
      double bestAdmitted = Double.POSITIVE_INFINITY;
      double[] bestAdmittedPoint = null;
      // grow the box until the best admitted hit lies inside its inscribed circle: nothing closer
      // is missed (the nearest hit of any type is then inside it too)
      for (double reach = CELL; reach <= 4200; reach *= 2) {
        for (Seg s : nearSegments(live, wx, wy, reach)) {
          double dist = distance(wx, wy, s);
          if (dist < best) {
            best = dist;
            bestPoint = nearestPoint(wx, wy, s);
          }
          if (dist < bestAdmitted) {
            Set<TrackKind> kinds = new HashSet<>();
            kinds.add(s.track.kind());
            for (String street : streets(s.edge)) {
              Set<TrackKind> known = prep.kindsByStreet.get(street);
              if (known != null) {
                kinds.addAll(known);
              }
            }
            if (admits(r.type(), s.edge, kinds)) {
              bestAdmitted = dist;
              bestAdmittedPoint = nearestPoint(wx, wy, s);
            }
          }
        }
        if (bestAdmitted <= reach) {
          break;
        }
      }
      // plan 2, 5.5: the route starts at the nearest point of the network the ride type allows
      // within snapMaxM (a footway beside the start is no place to begin a road ride); only when
      // there is none does the nearest point of any type stand
      if (bestAdmittedPoint != null && bestAdmitted <= p.snapMaxM()) {
        bestPoint = bestAdmittedPoint;
      }
      if (bestPoint != null
          && Math.hypot(got[0] - bestPoint[0], got[1] - bestPoint[1]) > p.snapToNodeM() + 12) {
        out.add(
            String.format(
                "8 %s of the route is %.1f m from the nearest live input point",
                k == 0 ? "start" : "end",
                Math.hypot(got[0] - bestPoint[0], got[1] - bestPoint[1])));
      }
    }
    return out;
  }

  /**
   * Design 12.13, from the raw inputs: the junctions between offsets {@code xa} and {@code xb} are
   * a hairpin the team rides when one single live track lies under every sample of the route from
   * 10 m before {@code xa} to 10 m after {@code xb}, and no straight piece of that track of 15 m or
   * more (half a metre of slack) lying inside the span meets the carriageways (the route heading
   * before {@code xa} or after {@code xb}) at 90 degrees give or take 25: that piece is the
   * connector of a dual carriageway.
   */
  private static boolean hairpinTheTeamRides(
      Prepared prep, Index live, Route rt, Index2 grid, double xa, double xb, double[] chord) {
    double from = Math.max(0, xa - 10);
    double to = Math.min(rt.length, xb + 10);
    Set<Long> common = null;
    for (double off = from; ; off += STEP) {
      double o = Math.min(off, to);
      double[] pt = rt.at(o);
      Set<Long> here = new HashSet<>();
      for (Seg s : live.around(pt[0], pt[1])) {
        if (distance(pt[0], pt[1], s) <= NEAR) {
          here.add(s.track.trackId());
        }
      }
      if (common == null) {
        common = here;
      } else {
        common.retainAll(here);
      }
      if (common.isEmpty()) {
        return false;
      }
      if (o >= to) {
        break;
      }
    }
    // one pass: the track's own ride goes under the whole span without a jump, not a crossing of
    // the connector at another moment of a ride that took both carriageways
    Set<Long> onePass = new HashSet<>();
    for (long t : common) {
      if (ridesInOnePass(prep.chains.getOrDefault(t, List.of()), rt, from, to)) {
        onePass.add(t);
      }
    }
    if (onePass.isEmpty()) {
      return false;
    }
    common = onePass;
    double hin = rt.heading(xa - 50, xa - 30);
    double hout = rt.heading(xb + 30, xb + 50);
    if (acrossChord(chord, hin) >= 30 || acrossChord(chord, hout) >= 30) {
      return false; // the span moves the route from one carriageway to the other
    }
    // the route between the two junctions (its own vertices): a straight run of 15 m or more,
    // across the carriageways, is the connector of a dual carriageway however many vertices draw it
    List<double[]> pts = new ArrayList<>();
    pts.add(rt.at(xa));
    for (int i = 0; i < rt.cum.length; i++) {
      if (rt.cum[i] > xa + 0.5 && rt.cum[i] < xb - 0.5) {
        pts.add(new double[] {rt.cx[i], rt.cy[i]});
      }
    }
    pts.add(rt.at(xb));
    return !hasConnectorRun(pts, hin, hout);
  }

  private static boolean hasConnectorRun(List<double[]> rawPts, double hin, double hout) {
    // a point within a metre of the last kept one has an arbitrary bearing: it joins its run
    List<double[]> pts = new ArrayList<>();
    for (double[] q : rawPts) {
      if (pts.isEmpty()
          || Math.hypot(q[0] - pts.get(pts.size() - 1)[0], q[1] - pts.get(pts.size() - 1)[1])
              >= 1.0) {
        pts.add(q);
      }
    }
    int a = 0;
    while (a + 1 < pts.size()) {
      double[] from = pts.get(a);
      double runBearing = bearing(from[0], from[1], pts.get(a + 1)[0], pts.get(a + 1)[1]);
      int b = a + 1;
      while (b + 1 < pts.size()
          && angle(
                  runBearing,
                  bearing(pts.get(b)[0], pts.get(b)[1], pts.get(b + 1)[0], pts.get(b + 1)[1]))
              <= 20) {
        b++;
      }
      double[] to = pts.get(b);
      if (Math.hypot(to[0] - from[0], to[1] - from[1]) >= 15 - 0.5) {
        double bearing = bearing(from[0], from[1], to[0], to[1]);
        if (across(bearing, hin) || across(bearing, hout)) {
          return true;
        }
      }
      a = b;
    }
    return false;
  }

  private static double acrossChord(double[] chord, double heading) {
    double h = Math.toRadians(heading);
    return Math.abs(chord[0] * Math.cos(h) - chord[1] * Math.sin(h));
  }

  private static boolean across(double segmentBearing, double heading) {
    double d = ((segmentBearing - heading) % 180 + 180) % 180;
    return Math.abs(d - 90) <= 25;
  }

  /** Route offset of the sample nearest to a point, within 6 m of it; NaN when there is none. */
  private static double offsetOf(Index2 grid, double x, double y) {
    double best = 6;
    double off = Double.NaN;
    for (double[] sp : grid.samplesAround(x, y)) {
      double d = Math.hypot(sp[0] - x, sp[1] - y);
      if (d <= best) {
        best = d;
        off = sp[2];
      }
    }
    return off;
  }

  /** Segments of the cells within {@code reach} metres (a square) of a point. */
  private static List<Seg> nearSegments(Index idx, double x, double y, double reach) {
    List<Seg> best = new ArrayList<>();
    long cx = (long) Math.floor(x / CELL);
    long cy = (long) Math.floor(y / CELL);
    long n = (long) Math.ceil(reach / CELL) + 1;
    for (long dx = -n; dx <= n; dx++) {
      for (long dy = -n; dy <= n; dy++) {
        List<Seg> l = idx.cells.get(Index.key(cx + dx, cy + dy));
        if (l != null) {
          best.addAll(l);
        }
      }
    }
    return best;
  }

  /** Spatial lookup of route samples. */
  private static final class Index2 {
    final Map<Long, List<double[]>> cells = new HashMap<>();

    Index2(Route rt) {
      for (double[] sp : rt.pts) {
        cells
            .computeIfAbsent(
                Index.key((long) Math.floor(sp[0] / 10), (long) Math.floor(sp[1] / 10)),
                k -> new ArrayList<>())
            .add(sp);
      }
    }

    List<double[]> samplesAround(double x, double y) {
      List<double[]> out = new ArrayList<>();
      long cx = (long) Math.floor(x / 10);
      long cy = (long) Math.floor(y / 10);
      for (long dx = -1; dx <= 1; dx++) {
        for (long dy = -1; dy <= 1; dy++) {
          List<double[]> l = cells.get(Index.key(cx + dx, cy + dy));
          if (l != null) {
            out.addAll(l);
          }
        }
      }
      return out;
    }

    List<Double> within(double x, double y, double radius) {
      List<Double> out = new ArrayList<>();
      long cx = (long) Math.floor(x / 10);
      long cy = (long) Math.floor(y / 10);
      for (long dx = -1; dx <= 1; dx++) {
        for (long dy = -1; dy <= 1; dy++) {
          List<double[]> l = cells.get(Index.key(cx + dx, cy + dy));
          if (l != null) {
            for (double[] sp : l) {
              if (Math.hypot(sp[0] - x, sp[1] - y) <= radius) {
                out.add(sp[2]);
              }
            }
          }
        }
      }
      java.util.Collections.sort(out);
      return out;
    }
  }

  // ---- the admission table of §12.7, on raw fields -------------------------------------------

  private static boolean by(Set<TrackKind> kinds, TrackKind... wanted) {
    for (TrackKind k : wanted) {
      if (kinds.contains(k)) {
        return true;
      }
    }
    return false;
  }

  private static boolean admits(RideType type, TrackEdge e, Set<TrackKind> kinds) {
    WayKind raw = e.wayKind() == null ? WayKind.UNKNOWN : e.wayKind();
    WayKind k =
        (raw == WayKind.PATH || raw == WayKind.FOOTWAY) && e.bicycle() == Access.YES
            ? WayKind.CYCLEWAY
            : raw;
    SurfaceClass sc = e.surface() == null ? SurfaceClass.UNKNOWN : e.surface().surfaceClass();
    String detail = e.surface() == null ? null : e.surface().detail();
    boolean forbidden = e.bicycle() == Access.NO;
    boolean rough =
        "dirt".equals(detail)
            || "sand".equals(detail)
            || "grass".equals(detail)
            || "rock".equals(detail)
            || "wood".equals(detail)
            || e.trackType() == OsmTrackType.GRADE4
            || e.trackType() == OsmTrackType.GRADE5;
    switch (type) {
      case ROAD:
        if (k == WayKind.PATH
            || k == WayKind.FOOTWAY
            || k == WayKind.STEPS
            || sc == SurfaceClass.UNPAVED
            || forbidden) {
          return false;
        }
        if ((k == WayKind.MAJOR_ROAD || k == WayKind.MINOR_ROAD || k == WayKind.CYCLEWAY)
            && sc == SurfaceClass.PAVED) {
          return true;
        }
        return by(kinds, TrackKind.ROAD);
      case GRAVEL:
        if (k == WayKind.STEPS) {
          return false;
        }
        if (k == WayKind.PATH || k == WayKind.FOOTWAY || rough || forbidden) {
          return by(kinds, TrackKind.GRAVEL, TrackKind.MIXED);
        }
        return true;
      case MTB:
      default:
        if (k == WayKind.STEPS || forbidden) {
          return by(kinds, TrackKind.MTB);
        }
        return true;
    }
  }
}
