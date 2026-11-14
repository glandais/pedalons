package fr.pedalons.service.route.generator;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Builds the team {@link NetworkGraph} from the street-graph edges of the team's routes (design
 * §12.3, plan docs/plans/2026-11-13-generateur-boucles-equipe.md §3, ledger docs/LEDGER_*.md
 * API-198).
 *
 * <p>Why each step exists. Every input edge is an <em>observation</em> of a complete street edge:
 * the producer reports the ends of the complete edge even when the track only rides part of it
 * (offsets along it). Observations are therefore attached to the complete edge by node pair and
 * offsets, never by padding their geometry (review B2: padding invented chords). Complete ones
 * found the edges; partial ones are attached to them, or stitched together when jointly they cover
 * a whole edge (review M2: the team street cut at the start point); what stays uncovered becomes a
 * dangling stub, a dead end for the checker. Live tracks are always processed before excluded
 * ones, and an excluded track never founds a node merge, a slot or a reference geometry.
 *
 * <p>Invariant, asserted in tests: no segment of a built geometry longer than {@code coverageGapM}
 * is not a slice of a live input geometry (the builder never invents geometry).
 *
 * <p>Deterministic: tracks are processed sorted by track id, no hash iteration order is observable.
 */
public final class NetworkGraphBuilder {
  private NetworkGraphBuilder() {}

  /** The 13 surface details of the contract; the code stored by the graph is the index + 1. */
  static final String[] DETAILS = {
    "asphalt",
    "concrete",
    "paving_stones",
    "sett",
    "cobblestone",
    "compacted",
    "fine_gravel",
    "gravel",
    "dirt",
    "sand",
    "grass",
    "wood",
    "rock"
  };

  /** Weight of the secondary kinds in the per-type familiarity (design §12.7). */
  static final double SECONDARY_WEIGHT = 0.25;

  public static NetworkGraph build(List<TrackInput> tracks, NetworkParameters p) {
    return new Work(tracks, p).run();
  }

  private enum Cls {
    COMPLETE,
    PARTIAL_BOTH,
    PARTIAL_FROM,
    PARTIAL_TO,
    FLOATING
  }

  /** One input edge, classified (design §12.3 step 0). */
  private static final class Obs {
    long trackId;
    boolean excluded;
    Cls cls;
    int a = -1; // node of `from`
    int b = -1; // node of `to`
    double[] xs;
    double[] ys;
    double length = Double.NaN; // complete edge, NaN when unknown
    double traversed;
    double o1;
    double o2;
    double gain;
    double loss;
    Oneway oneway;
    int wayKind = -1;
    int sClass = -1;
    int sDetail;
    int sSource;
    int trackType;
    int bicycle;
    int foot;

    /** The previous observation of the same track, when it was kept (the track's own order). */
    Obs prev;

    /** The edge this observation ended up on, null for an orphan or an excluded track. */
    EdgeRec edge;
  }

  /** An observation placed on a slot, in the slot frame (u to v). */
  private static final class Piece {
    Obs o;
    double[] xs;
    double[] ys;
    double s;
    double t;
    boolean uv;
    double gain;
    double loss;
    boolean complete;
  }

  /** One complete street edge between u and v (or an open one, v = -1, hanging off u). */
  private static final class Slot {
    final int u;
    final int v;
    final double length;
    final List<Piece> pieces = new ArrayList<>();
    Piece ref;

    Slot(int u, int v, double length) {
      this.u = u;
      this.v = v;
      this.length = length;
    }

    boolean open() {
      return v < 0;
    }
  }

  private static final class EdgeRec {
    int u;
    int v;
    double[] xs;
    double[] ys;
    double length;
    double gainUV;
    double lossUV;
    boolean allowUV;
    boolean allowVU;
    long[] tracks;
    byte wayKind;
    byte sClass;
    byte sDetail;
    byte sSource;
    byte tType;
    byte bike;
    byte foot;
    boolean alive = true;

    /** The edge that replaced this one (contraction, twin folding); null while alive. */
    EdgeRec fwd;
  }

  /** A live track that rode from edge {@code from} into edge {@code to} through street node {@code node}. */
  private record RawTransition(
      long track, EdgeRec from, EdgeRec to, int node, int step, boolean breakBefore) {}

  /** A stitched or sliced geometry, in the slot frame. */
  private static final class Stitched {
    double[] xs;
    double[] ys;
    double gain;
    double loss;
  }

  private static final class Work {
    final List<TrackInput> tracks;
    final NetworkParameters p;
    LocalProjection projection;

    double[] nx = new double[64];
    double[] ny = new double[64];
    boolean[] ndang = new boolean[64];
    boolean[] nlive = new boolean[64];
    int[] nstreet = new int[64];
    int n;
    final Map<String, Integer> keyToNode = new LinkedHashMap<>();
    int[] uf;

    final Map<Long, TrackKind> kindOf = new LinkedHashMap<>();
    int dropped;
    int floating;
    int orphans;
    int stitched;
    int selfLoops;
    int unknownDetails;

    final Map<Long, List<Slot>> slotsByKey = new LinkedHashMap<>();
    final Map<Integer, List<Slot>> slotsByNode = new LinkedHashMap<>();
    final List<Slot> allSlots = new ArrayList<>();

    Work(List<TrackInput> tracks, NetworkParameters p) {
      this.tracks = new ArrayList<>(tracks);
      this.tracks.sort(Comparator.comparingLong(TrackInput::trackId));
      this.p = p;
    }

    List<RawTransition> transitions = new ArrayList<>();

    NetworkGraph run() {
      projection = reference();
      List<Obs> observations = collect();
      mergeNodes();
      for (Obs o : observations) {
        if (o.cls == Cls.COMPLETE) {
          placeComplete(o);
        }
      }
      for (Obs o : observations) {
        switch (o.cls) {
          case PARTIAL_BOTH -> placePartialBoth(o);
          case PARTIAL_FROM, PARTIAL_TO -> placePartialOne(o);
          case FLOATING -> placeFloating(o);
          default -> {}
        }
      }
      List<EdgeRec> edges = buildEdges();
      transitions = transitionsOf(observations);
      return contractAndAssemble(edges);
    }

    // ---- projection reference -----------------------------------------------------------------

    LocalProjection reference() {
      double sumLat = 0;
      double sumLon = 0;
      int count = 0;
      for (TrackInput t : tracks) {
        for (TrackEdge e : t.edges()) {
          if (e.from() != null) {
            sumLat += e.from().position().lat();
            sumLon += e.from().position().lon();
            count++;
          }
          if (e.to() != null) {
            sumLat += e.to().position().lat();
            sumLon += e.to().position().lon();
            count++;
          }
        }
      }
      if (count == 0) {
        for (TrackInput t : tracks) {
          for (TrackEdge e : t.edges()) {
            for (LatLon q : e.geometry()) {
              sumLat += q.lat();
              sumLon += q.lon();
              count++;
            }
          }
        }
      }
      return count == 0
          ? new LocalProjection(0, 0)
          : new LocalProjection(sumLat / count, sumLon / count);
    }

    // ---- step 0 and 1: classification, nodes by key -------------------------------------------

    int newNode(double x, double y, boolean dangling, int street) {
      if (n == nx.length) {
        int cap = n * 2;
        nx = Arrays.copyOf(nx, cap);
        ny = Arrays.copyOf(ny, cap);
        ndang = Arrays.copyOf(ndang, cap);
        nlive = Arrays.copyOf(nlive, cap);
        nstreet = Arrays.copyOf(nstreet, cap);
      }
      nx[n] = x;
      ny[n] = y;
      ndang[n] = dangling;
      nstreet[n] = street;
      return n++;
    }

    int nodeForKey(NodeRef ref, boolean live) {
      Integer existing = keyToNode.get(ref.key());
      int id;
      if (existing != null) {
        id = existing;
        nstreet[id] = Math.max(nstreet[id], ref.streetDegree());
      } else {
        LatLon pos = ref.position();
        id =
            newNode(
                projection.toX(pos.lat(), pos.lon()),
                projection.toY(pos.lat(), pos.lon()),
                false,
                ref.streetDegree());
        keyToNode.put(ref.key(), id);
      }
      if (live) {
        nlive[id] = true;
      }
      return id;
    }

    List<Obs> collect() {
      List<Obs> out = new ArrayList<>();
      // live observations first: an excluded track never founds a node a live one could have
      for (int pass = 0; pass < 2; pass++) {
        boolean excludedPass = pass == 1;
        for (TrackInput t : tracks) {
          if (t.excluded() != excludedPass) {
            continue;
          }
          if (!excludedPass) {
            kindOf.put(t.trackId(), t.kind());
          }
          Obs previous = null;
          for (TrackEdge te : t.edges()) {
            Obs o = classify(t, te);
            if (o == null) {
              dropped++;
              previous = null;
            } else {
              o.prev = previous;
              previous = o;
              out.add(o);
            }
          }
        }
      }
      return out;
    }

    /** Design §12.3 step 0; null = DROPPED. */
    Obs classify(TrackInput t, TrackEdge te) {
      NodeRef f = te.from();
      NodeRef to = te.to();
      List<LatLon> g = te.geometry();
      if ((f == null && to == null) || g.size() < 2 || te.traversedM() < p.minEdgeLengthM()) {
        return null;
      }
      double[] xs = new double[g.size()];
      double[] ys = new double[g.size()];
      for (int i = 0; i < xs.length; i++) {
        xs[i] = projection.toX(g.get(i).lat(), g.get(i).lon());
        ys[i] = projection.toY(g.get(i).lat(), g.get(i).lon());
      }
      double gap = p.coverageGapM();
      boolean partial = te.partial() || f == null || to == null;
      Obs o = new Obs();
      o.trackId = t.trackId();
      o.excluded = t.excluded();
      o.xs = xs;
      o.ys = ys;
      o.traversed = te.traversedM();
      o.gain = te.gainM();
      o.loss = te.lossM();
      o.oneway = te.oneway();
      if (te.wayKind() != null) {
        o.wayKind = te.wayKind().ordinal();
      }
      EdgeSurface sf = te.surface();
      if (sf != null) {
        o.sClass = sf.surfaceClass().ordinal();
        o.sSource = sf.source().ordinal();
        if (sf.detail() != null) {
          int code = detailCode(sf.detail());
          if (code == 0) {
            unknownDetails++;
          }
          o.sDetail = code;
        }
      }
      o.trackType = te.trackType() == null ? 0 : te.trackType().ordinal() + 1;
      o.bicycle = te.bicycle() == null ? 0 : te.bicycle().ordinal() + 1;
      o.foot = te.foot() == null ? 0 : te.foot().ordinal() + 1;
      Double len = te.lengthM();
      if (!partial) {
        if (len == null || len < p.minEdgeLengthM()) {
          return null;
        }
        o.cls = Cls.COMPLETE;
        o.length = len;
      } else if (f != null && to != null) {
        if (len == null || len < p.minEdgeLengthM()) {
          return null;
        }
        double a1 = te.fromOffsetM() == null ? 0 : te.fromOffsetM();
        double a2 = te.toOffsetM() == null ? a1 + te.traversedM() : te.toOffsetM();
        if (a1 < -gap || a2 > len + gap || a2 < a1 - 1) {
          return null;
        }
        o.cls = Cls.PARTIAL_BOTH;
        o.length = len;
        o.o1 = Math.max(0, Math.min(len, a1));
        o.o2 = Math.max(o.o1, Math.min(len, a2));
      } else if (f != null) {
        double a1 = te.fromOffsetM() == null ? 0 : te.fromOffsetM();
        double a2 = te.toOffsetM() == null ? a1 + te.traversedM() : te.toOffsetM();
        if (a1 < -gap || a2 < a1 - 1) {
          return null;
        }
        o.cls = Cls.PARTIAL_FROM;
        o.o1 = Math.max(0, a1);
        o.o2 = Math.max(o.o1, a2);
      } else {
        LatLon last = g.get(g.size() - 1);
        double d =
            Math.hypot(
                projection.toX(last.lat(), last.lon())
                    - projection.toX(to.position().lat(), to.position().lon()),
                projection.toY(last.lat(), last.lon())
                    - projection.toY(to.position().lat(), to.position().lon()));
        o.cls = d <= gap ? Cls.PARTIAL_TO : Cls.FLOATING;
        o.o1 = 0;
        o.o2 = te.traversedM();
      }
      boolean live = !t.excluded();
      if (f != null) {
        o.a = nodeForKey(f, live);
      }
      if (to != null) {
        o.b = nodeForKey(to, live);
      }
      return o;
    }

    static int detailCode(String detail) {
      for (int i = 0; i < DETAILS.length; i++) {
        if (DETAILS[i].equals(detail)) {
          return i + 1;
        }
      }
      return 0;
    }

    // ---- step 2: nodes by distance ------------------------------------------------------------

    int find(int x) {
      int r = x;
      while (uf[r] != r) {
        r = uf[r];
      }
      while (uf[x] != r) {
        int next = uf[x];
        uf[x] = r;
        x = next;
      }
      return r;
    }

    void union(int x, int y) {
      int rx = find(x);
      int ry = find(y);
      if (rx == ry) {
        return;
      }
      if (rx < ry) {
        uf[ry] = rx;
      } else {
        uf[rx] = ry;
      }
    }

    void mergeNodes() {
      uf = new int[n];
      for (int i = 0; i < n; i++) {
        uf[i] = i;
      }
      double m = p.nodeMergeM();
      SpatialGrid grid = new SpatialGrid(Math.max(m, 0.5));
      for (int i = 0; i < n; i++) {
        // Nodes only excluded tracks created never merge anything: an excluded track must not shape
        // the graph (plan §10.8), and through transitive merging it could join two live nodes.
        if (!nlive[i]) {
          continue;
        }
        final int self = i;
        grid.query(
            nx[i] - m,
            ny[i] - m,
            nx[i] + m,
            ny[i] + m,
            j -> {
              if (j != self && Math.hypot(nx[j] - nx[self], ny[j] - ny[self]) < m) {
                union(self, j);
              }
            });
        grid.add(nx[i], ny[i], i);
      }
      for (int i = 0; i < n; i++) {
        int r = find(i);
        if (r != i) {
          nstreet[r] = Math.max(nstreet[r], nstreet[i]);
        }
      }
    }

    // ---- slots --------------------------------------------------------------------------------

    static long key(int u, int v) {
      return ((long) u << 32) | v;
    }

    Slot newSlot(int u, int v, double length) {
      Slot s = new Slot(u, v, length);
      allSlots.add(s);
      if (v >= 0) {
        slotsByKey.computeIfAbsent(key(u, v), k -> new ArrayList<>()).add(s);
        slotsByNode.computeIfAbsent(u, k -> new ArrayList<>()).add(s);
        slotsByNode.computeIfAbsent(v, k -> new ArrayList<>()).add(s);
      } else {
        slotsByNode.computeIfAbsent(u, k -> new ArrayList<>()).add(s);
      }
      return s;
    }

    boolean lengthClose(double l1, double l2) {
      return Math.abs(l1 - l2)
          <= Math.max(p.dedupLengthAbsM(), p.dedupLengthRatio() * Math.max(l1, l2));
    }

    /** The observation placed on a slot, in its u-to-v frame. */
    Piece piece(Obs o, boolean uv, double s, double t, boolean complete) {
      Piece pc = new Piece();
      pc.o = o;
      pc.uv = uv;
      pc.s = s;
      pc.t = t;
      pc.complete = complete;
      pc.xs = uv ? o.xs : Geo.reversed(o.xs);
      pc.ys = uv ? o.ys : Geo.reversed(o.ys);
      pc.gain = uv ? o.gain : o.loss;
      pc.loss = uv ? o.loss : o.gain;
      return pc;
    }

    /** Point of the slot's known geometry at offset x from u, or null when nothing covers it. */
    double[] pointOnSlot(Slot slot, double x) {
      if (slot.ref != null && !Double.isNaN(slot.length) && slot.length > 0) {
        double len = Geo.polylineLength(slot.ref.xs, slot.ref.ys);
        return Geo.pointAt(
            slot.ref.xs, slot.ref.ys, Math.max(0, Math.min(1, x / slot.length)) * len);
      }
      for (Piece pc : slot.pieces) {
        if (x >= pc.s - 0.5 && x <= pc.t + 0.5 && pc.t > pc.s) {
          double len = Geo.polylineLength(pc.xs, pc.ys);
          return Geo.pointAt(
              pc.xs, pc.ys, Math.max(0, Math.min(1, (x - pc.s) / (pc.t - pc.s))) * len);
        }
      }
      return null;
    }

    /** Mean distance of a piece to the slot's known geometry over the offsets both cover; NaN none. */
    double fit(Slot slot, Piece pc) {
      int samples = p.dedupSamples();
      double len = Geo.polylineLength(pc.xs, pc.ys);
      double sum = 0;
      int count = 0;
      for (int i = 0; i < samples; i++) {
        double f = (double) i / (samples - 1);
        double x = pc.s + f * (pc.t - pc.s);
        double[] ref = pointOnSlot(slot, x);
        if (ref == null) {
          continue;
        }
        double[] q = Geo.pointAt(pc.xs, pc.ys, f * len);
        sum += Math.hypot(q[0] - ref[0], q[1] - ref[1]);
        count++;
      }
      return count == 0 ? Double.NaN : sum / count;
    }

    // ---- step 3: complete observations --------------------------------------------------------

    void placeComplete(Obs o) {
      int a = find(o.a);
      int b = find(o.b);
      if (a == b) {
        selfLoops++;
        return;
      }
      boolean uv = a < b;
      int u = Math.min(a, b);
      int v = Math.max(a, b);
      Piece pc = piece(o, uv, 0, o.length, true);
      List<Slot> list = slotsByKey.computeIfAbsent(key(u, v), k -> new ArrayList<>());
      Slot target = null;
      search:
      for (Slot s : list) {
        int seen = 0;
        for (Piece m : s.pieces) {
          if (!m.complete || m.o.excluded) {
            continue;
          }
          if (seen++ >= p.dedupMaxMembers()) {
            break;
          }
          if (lengthClose(o.length, m.o.length) && sameGeometry(pc, m)) {
            target = s;
            break search;
          }
        }
      }
      if (target == null) {
        target = newSlot(u, v, o.length);
      }
      target.pieces.add(pc);
      if (target.ref == null && !o.excluded) {
        target.ref = pc;
      }
    }

    boolean sameGeometry(Piece x, Piece y) {
      int s = p.dedupSamples();
      double[] r1 = Geo.resample(x.xs, x.ys, s);
      double[] r2 = Geo.resample(y.xs, y.ys, s);
      double sum = 0;
      for (int i = 0; i < s; i++) {
        sum += Math.hypot(r1[2 * i] - r2[2 * i], r1[2 * i + 1] - r2[2 * i + 1]);
      }
      return sum / s < p.dedupMeanDistM();
    }

    // ---- step 4: partial observations ---------------------------------------------------------

    void placePartialBoth(Obs o) {
      int a = find(o.a);
      int b = find(o.b);
      if (a == b) {
        selfLoops++;
        return;
      }
      boolean uv = a < b;
      int u = Math.min(a, b);
      int v = Math.max(a, b);
      double l = o.length;
      double s = uv ? o.o1 : l - o.o2;
      double t = uv ? o.o2 : l - o.o1;
      Piece pc = piece(o, uv, s, t, false);
      List<Slot> list = slotsByKey.computeIfAbsent(key(u, v), k -> new ArrayList<>());
      Slot best = null;
      double bestFit = Double.POSITIVE_INFINITY;
      for (Slot sl : list) {
        if (!lengthClose(l, sl.length)) {
          continue;
        }
        double f = fit(sl, pc);
        if (Double.isNaN(f)) {
          f = abutFit(sl, pc);
        }
        if (f < p.dedupMeanDistM() && f < bestFit) {
          best = sl;
          bestFit = f;
        }
      }
      if (best == null) {
        best = newSlot(u, v, l);
      }
      best.pieces.add(pc);
    }

    /**
     * Fit of a piece that overlaps nothing the slot knows: a slot with no geometry yet takes it at a
     * neutral fit, a slot that has some takes it only when the piece starts where its nearest
     * neighbour stops (or stops where it starts) within the dedup distance, so that two different
     * streets between the same nodes are never joined by an invented segment.
     */
    double abutFit(Slot sl, Piece pc) {
      double neutral = p.dedupMeanDistM() / 2;
      double best = Double.POSITIVE_INFINITY;
      boolean any = false;
      double bestGap = Double.POSITIVE_INFINITY;
      for (Piece q : sl.pieces) {
        if (q.o.excluded || q.t <= q.s) {
          continue;
        }
        any = true;
        double gap;
        double dist;
        if (q.t <= pc.s) {
          gap = pc.s - q.t;
          dist = Math.hypot(pc.xs[0] - q.xs[q.xs.length - 1], pc.ys[0] - q.ys[q.ys.length - 1]);
        } else if (q.s >= pc.t) {
          gap = q.s - pc.t;
          dist = Math.hypot(pc.xs[pc.xs.length - 1] - q.xs[0], pc.ys[pc.ys.length - 1] - q.ys[0]);
        } else {
          continue;
        }
        if (gap < bestGap) {
          bestGap = gap;
          best = dist;
        }
      }
      if (!any) {
        return neutral;
      }
      return best < p.dedupMeanDistM() ? Math.max(best, 0) : Double.NaN;
    }

    /** PARTIAL_FROM and PARTIAL_TO: one known end k, interval measured from k. */
    void placePartialOne(Obs o) {
      boolean from = o.cls == Cls.PARTIAL_FROM;
      int k = find(from ? o.a : o.b);
      List<Slot> candidates = slotsByNode.get(k);
      Slot best = null;
      Piece bestPiece = null;
      double bestFit = Double.POSITIVE_INFINITY;
      if (candidates != null) {
        for (Slot sl : candidates) {
          boolean kIsU = sl.u == k;
          if (!sl.open() && !Double.isNaN(sl.length) && o.o1 > sl.length + p.coverageGapM()) {
            continue;
          }
          double d1 = o.o1;
          double d2 = sl.open() ? o.o2 : Math.min(o.o2, sl.length);
          if (d2 <= d1) {
            continue;
          }
          boolean uv = kIsU == from;
          double s = kIsU ? d1 : sl.length - d2;
          double t = kIsU ? d2 : sl.length - d1;
          Piece pc = piece(o, uv, s, t, false);
          double f = fit(sl, pc);
          if (!Double.isNaN(f) && f < p.dedupMeanDistM() && f < bestFit) {
            best = sl;
            bestPiece = pc;
            bestFit = f;
          }
        }
      }
      if (best == null) {
        best = newSlot(k, -1, Double.NaN);
        bestPiece = piece(o, from, o.o1, o.o2, false);
      }
      best.pieces.add(bestPiece);
    }

    void placeFloating(Obs o) {
      int k = find(o.b);
      List<Slot> candidates = slotsByNode.get(k);
      if (candidates != null) {
        for (Slot sl : candidates) {
          if (sl.ref == null || sl.open()) {
            continue;
          }
          double len = Geo.polylineLength(sl.ref.xs, sl.ref.ys);
          int last = o.xs.length - 1;
          Geo.Projection p1 = Geo.project(o.xs[0], o.ys[0], sl.ref.xs, sl.ref.ys);
          Geo.Projection p2 = Geo.project(o.xs[last], o.ys[last], sl.ref.xs, sl.ref.ys);
          if (p1.distance() >= p.dedupMeanDistM()
              || p2.distance() >= p.dedupMeanDistM()
              || len <= 0) {
            continue;
          }
          double x1 = p1.along() / len * sl.length;
          double x2 = p2.along() / len * sl.length;
          boolean uv = x1 <= x2;
          double s = Math.min(x1, x2);
          double t = Math.max(x1, x2);
          if (t - s < 1) {
            continue;
          }
          Piece pc = piece(o, uv, s, t, false);
          double f = fit(sl, pc);
          if (!Double.isNaN(f) && f < p.dedupMeanDistM()) {
            sl.pieces.add(pc);
            return;
          }
        }
      }
      floating++;
    }

    // ---- step 5 and 6: coverage, stitching, aggregation ---------------------------------------

    void bind(EdgeRec e, List<Piece> pieces) {
      for (Piece pc : pieces) {
        pc.o.edge = e;
      }
    }

    /**
     * What each live track did at each node, from the order of its own observations: the edge it
     * rode before and the one it rode next (design 12.13, continuity of a hairpin).
     */
    List<RawTransition> transitionsOf(List<Obs> observations) {
      List<RawTransition> out = new ArrayList<>();
      // the last kept observation of each track: a step continues the track's pass only when its
      // previous observation is that one (nothing dropped or orphaned in between)
      Map<Long, Obs> last = new java.util.HashMap<>();
      Map<Long, Boolean> pendingBreak = new java.util.HashMap<>();
      for (int step = 0; step < observations.size(); step++) {
        Obs o = observations.get(step);
        if (o.excluded || o.edge == null) {
          continue;
        }
        boolean contiguous = o.prev != null && o.prev == last.get(o.trackId);
        last.put(o.trackId, o);
        if (!contiguous) {
          pendingBreak.put(o.trackId, true);
        }
        if (o.prev == null || o.prev.edge == null) {
          continue;
        }
        EdgeRec a = o.prev.edge;
        EdgeRec b = o.edge;
        if (a == b) {
          continue;
        }
        boolean brk = pendingBreak.getOrDefault(o.trackId, false);
        pendingBreak.put(o.trackId, false);
        boolean first = true;
        for (int node : a.u == a.v ? new int[] {a.u} : new int[] {a.u, a.v}) {
          if (b.u == node || b.v == node) {
            out.add(new RawTransition(o.trackId, a, b, node, step, first && brk));
            first = false;
          }
        }
        if (first) {
          // the two edges share no node: the track jumped (a gap in its own ride), the pass breaks
          pendingBreak.put(o.trackId, true);
        }
      }
      return out;
    }

    List<EdgeRec> buildEdges() {
      List<EdgeRec> out = new ArrayList<>();
      for (Slot sl : allSlots) {
        List<Piece> live = new ArrayList<>();
        for (Piece pc : sl.pieces) {
          if (!pc.o.excluded) {
            live.add(pc);
          }
        }
        if (live.isEmpty()) {
          continue;
        }
        if (sl.ref != null) {
          EdgeRec e = new EdgeRec();
          e.u = sl.u;
          e.v = sl.v;
          e.xs = sl.ref.xs;
          e.ys = sl.ref.ys;
          e.length = sl.length;
          e.gainUV = sl.ref.gain;
          e.lossUV = sl.ref.loss;
          aggregate(e, live, 0, sl.length, false);
          bind(e, live);
          out.add(e);
          continue;
        }
        live.sort(
            Comparator.<Piece>comparingDouble(pc -> pc.s)
                .thenComparing(pc -> -pc.t)
                .thenComparingLong(pc -> pc.o.trackId));
        List<List<Piece>> groups = new ArrayList<>();
        List<Piece> cur = null;
        double curT = 0;
        for (Piece pc : live) {
          if (cur != null && pc.s <= curT + p.coverageGapM()) {
            cur.add(pc);
            curT = Math.max(curT, pc.t);
          } else {
            cur = new ArrayList<>();
            groups.add(cur);
            cur.add(pc);
            curT = pc.t;
          }
        }
        for (List<Piece> group : groups) {
          double gs = group.get(0).s;
          double gt = 0;
          for (Piece pc : group) {
            gt = Math.max(gt, pc.t);
          }
          boolean touchU = gs <= p.coverageGapM();
          boolean touchV = !sl.open() && gt >= sl.length - p.coverageGapM();
          if (touchU && touchV) {
            Stitched st = stitch(group, gs, sl.u, sl.v, true, true);
            if (st == null) {
              orphans++;
              continue;
            }
            EdgeRec e = new EdgeRec();
            e.u = sl.u;
            e.v = sl.v;
            e.xs = st.xs;
            e.ys = st.ys;
            e.length = sl.length;
            e.gainUV = st.gain;
            e.lossUV = st.loss;
            aggregate(e, live, 0, sl.length, false);
            bind(e, group);
            stitched++;
            out.add(e);
          } else if (touchU || touchV) {
            Stitched st = stitch(group, gs, sl.u, sl.v, touchU, touchV);
            double len = gt - gs;
            if (st == null || len < p.minEdgeLengthM()) {
              orphans++;
              continue;
            }
            EdgeRec e = new EdgeRec();
            if (touchU) {
              e.u = sl.u;
              e.xs = st.xs;
              e.ys = st.ys;
              e.gainUV = st.gain;
              e.lossUV = st.loss;
            } else {
              e.u = sl.v;
              e.xs = Geo.reversed(st.xs);
              e.ys = Geo.reversed(st.ys);
              e.gainUV = st.loss;
              e.lossUV = st.gain;
            }
            e.length = len;
            e.v = newNode(e.xs[e.xs.length - 1], e.ys[e.ys.length - 1], true, 0);
            aggregate(e, live, gs, gt, !touchU);
            bind(e, group);
            out.add(e);
          } else {
            orphans++;
          }
        }
      }
      snapEnds(out);
      return out;
    }

    /**
     * Moves the first and last point of an edge onto the node it ends at when they differ by no
     * more than the node merge distance (the node kept the position of the first key): the route
     * steps then join exactly, and no segment longer than that is added.
     */
    void snapEnds(List<EdgeRec> edges) {
      double m = p.nodeMergeM() + 0.5;
      for (EdgeRec e : edges) {
        int last = e.xs.length - 1;
        if (!ndang[e.u] && Math.hypot(e.xs[0] - nx[e.u], e.ys[0] - ny[e.u]) <= m) {
          e.xs = e.xs.clone();
          e.ys = e.ys.clone();
          e.xs[0] = nx[e.u];
          e.ys[0] = ny[e.u];
        }
        if (!ndang[e.v] && Math.hypot(e.xs[last] - nx[e.v], e.ys[last] - ny[e.v]) <= m) {
          e.xs = e.xs.clone();
          e.ys = e.ys.clone();
          e.xs[last] = nx[e.v];
          e.ys[last] = ny[e.v];
        }
      }
    }

    /**
     * Joins the pieces of a coverage group into one geometry in the slot frame, never inventing a
     * segment: each piece contributes the slice that starts where the previous one stopped.
     */
    Stitched stitch(List<Piece> group, double start, int u, int v, boolean atU, boolean atV) {
      List<double[]> pts = new ArrayList<>();
      double cursor = start;
      double gain = 0;
      double loss = 0;
      for (Piece pc : group) {
        if (pc.t <= cursor + 0.5 || pc.t <= pc.s) {
          continue;
        }
        double plen = Geo.polylineLength(pc.xs, pc.ys);
        double from = Math.max(pc.s, cursor);
        double arcFrom = (from - pc.s) / (pc.t - pc.s) * plen;
        double[][] sl = Geo.slice(pc.xs, pc.ys, arcFrom, plen);
        double sliceLen = Geo.polylineLength(sl[0], sl[1]);
        for (int i = 0; i < sl[0].length; i++) {
          if (i == 0 && !pts.isEmpty()) {
            double[] last = pts.get(pts.size() - 1);
            if (Math.hypot(sl[0][0] - last[0], sl[1][0] - last[1]) > p.dedupMeanDistM()) {
              return null; // two slices that do not meet: never invent the segment between them
            }
            if (Math.hypot(sl[0][0] - last[0], sl[1][0] - last[1]) < 0.5) {
              continue;
            }
          }
          pts.add(new double[] {sl[0][i], sl[1][i]});
        }
        if (plen > 0) {
          gain += pc.gain * sliceLen / plen;
          loss += pc.loss * sliceLen / plen;
        }
        cursor = pc.t;
      }
      if (pts.size() < 2) {
        return null;
      }
      double gap = p.coverageGapM();
      if (atU) {
        double d = Math.hypot(pts.get(0)[0] - nx[u], pts.get(0)[1] - ny[u]);
        if (d >= 0.5 && d <= 2 * gap) {
          pts.add(0, new double[] {nx[u], ny[u]});
        }
      }
      if (atV) {
        double[] last = pts.get(pts.size() - 1);
        double d = Math.hypot(last[0] - nx[v], last[1] - ny[v]);
        if (d >= 0.5 && d <= 2 * gap) {
          pts.add(new double[] {nx[v], ny[v]});
        }
      }
      Stitched st = new Stitched();
      st.xs = new double[pts.size()];
      st.ys = new double[pts.size()];
      for (int i = 0; i < st.xs.length; i++) {
        st.xs[i] = pts.get(i)[0];
        st.ys[i] = pts.get(i)[1];
      }
      st.gain = gain;
      st.loss = loss;
      return st;
    }

    static final int[] WAY_RANK = {
      0, 1, 4, 5, 2, 6, 7, 3
    }; // by WayKind ordinal, higher = more restrictive

    static final int[] CLASS_RANK = {0, 2, 1}; // PAVED, UNPAVED, UNKNOWN

    /** Codes are 0 = absent then ordinal + 1; a higher code is more restrictive. */
    static final int[] TRACK_TYPE_RANK = {0, 1, 2, 3, 4, 5};

    static final int[] ACCESS_RANK = {0, 1, 2, 3};

    /** Step 6: support, directions and categorical attributes over the live pieces of the slot. */
    void aggregate(EdgeRec e, List<Piece> live, double es, double et, boolean flipped) {
      double len = et - es;
      Map<Long, Double> cover = new TreeMap<>();
      boolean oneway = false;
      Map<Long, Double> coverUV = new TreeMap<>();
      Map<Long, Double> coverVU = new TreeMap<>();
      double[] way = new double[WayKind.values().length];
      double[] cls = new double[3];
      double[][] detail = new double[3][DETAILS.length + 1];
      double[][] source = new double[3][SurfaceSource.values().length];
      double[] trackTypeW = new double[TRACK_TYPE_RANK.length];
      double[] bikeW = new double[ACCESS_RANK.length];
      double[] footW = new double[ACCESS_RANK.length];
      Piece largest = null;
      double largestOverlap = 0;
      for (Piece pc : live) {
        double ov = Math.min(pc.t, et) - Math.max(pc.s, es);
        if (ov <= 0) {
          continue;
        }
        cover.merge(pc.o.trackId, ov, Math::max);
        if (ov > largestOverlap) {
          largestOverlap = ov;
          largest = pc;
        }
        if (ov >= 1) {
          if (pc.o.oneway != Oneway.BOTH) {
            oneway = true;
          }
          (pc.uv ? coverUV : coverVU).merge(pc.o.trackId, ov, Math::max);
        }
        Obs o = pc.o;
        if (o.wayKind >= 0) {
          way[o.wayKind] += ov;
        }
        if (o.sClass >= 0) {
          cls[o.sClass] += ov;
          detail[o.sClass][o.sDetail] += ov;
          source[o.sClass][o.sSource] += ov;
        }
        // code 0 = absent weighs like any other value: a long stretch without the tag outvotes a
        // short restrictive observation
        trackTypeW[o.trackType] += ov;
        bikeW[o.bicycle] += ov;
        footW[o.foot] += ov;
      }
      double need = Math.min(p.supportMinCoverM(), p.supportMinCoverShare() * len);
      // a direction is observed only when one track covers it as much as support requires: a few
      // metres of wrong-way entry or a U-turn must not open a whole one-way edge in contraflow
      boolean obsUV = coverUV.values().stream().anyMatch(v -> v >= need);
      boolean obsVU = coverVU.values().stream().anyMatch(v -> v >= need);
      if (!obsUV && !obsVU && largest != null) {
        obsUV = largest.uv;
        obsVU = !largest.uv;
      }
      List<Long> ids = new ArrayList<>();
      for (Map.Entry<Long, Double> c : cover.entrySet()) {
        if (c.getValue() >= need) {
          ids.add(c.getKey());
        }
      }
      if (ids.isEmpty() && largest != null) {
        ids.add(largest.o.trackId);
      }
      e.tracks = ids.stream().mapToLong(Long::longValue).sorted().toArray();
      if (!oneway || (!obsUV && !obsVU)) {
        e.allowUV = true;
        e.allowVU = true;
      } else {
        e.allowUV = flipped ? obsVU : obsUV;
        e.allowVU = flipped ? obsUV : obsVU;
      }
      e.wayKind = (byte) pick(way, WAY_RANK, WayKind.UNKNOWN.ordinal());
      int c = pick(cls, CLASS_RANK, SurfaceClass.UNKNOWN.ordinal());
      boolean anyClass = cls[0] + cls[1] + cls[2] > 0;
      e.sClass = (byte) c;
      e.sDetail = (byte) (anyClass ? pick(detail[c], null, 0) : 0);
      e.sSource =
          (byte)
              (anyClass
                  ? pick(source[c], null, SurfaceSource.NONE.ordinal())
                  : SurfaceSource.NONE.ordinal());
      e.tType = (byte) pick(trackTypeW, TRACK_TYPE_RANK, 0);
      e.bike = (byte) pick(bikeW, ACCESS_RANK, 0);
      e.foot = (byte) pick(footW, ACCESS_RANK, 0);
    }

    /** Majority by weight; a tie goes to the higher rank (the most restrictive) or the lower code. */
    static int pick(double[] weight, int[] rank, int none) {
      int best = -1;
      for (int i = 0; i < weight.length; i++) {
        if (weight[i] <= 0) {
          continue;
        }
        if (best < 0 || weight[i] > weight[best] + 1e-9) {
          best = i;
        } else if (Math.abs(weight[i] - weight[best]) <= 1e-9
            && rank != null
            && rank[i] > rank[best]) {
          best = i;
        }
      }
      return best < 0 ? none : best;
    }

    // ---- step 7 and 8: contraction ------------------------------------------------------------

    NetworkGraph contractAndAssemble(List<EdgeRec> edges) {
      IntList[] adj = new IntList[n];
      for (int i = 0; i < n; i++) {
        adj[i] = new IntList(2);
      }
      for (int i = 0; i < edges.size(); i++) {
        adj[edges.get(i).u].add(i);
        adj[edges.get(i).v].add(i);
      }
      boolean[] nodeAlive = new boolean[n];
      Arrays.fill(nodeAlive, true);
      boolean[] queued = new boolean[n];
      ArrayDeque<Integer> work = new ArrayDeque<>();
      for (int i = 0; i < n; i++) {
        work.add(i);
        queued[i] = true;
      }
      while (!work.isEmpty()) {
        int node = work.poll();
        queued[node] = false;
        int[] ends = tryContract(node, edges, adj, nodeAlive);
        if (ends != null) {
          for (int end : ends) {
            if (!queued[end]) {
              queued[end] = true;
              work.add(end);
            }
          }
        }
      }
      return assemble(edges, adj, nodeAlive);
    }

    static boolean sameAttributes(EdgeRec x, EdgeRec y) {
      return x.wayKind == y.wayKind
          && x.sClass == y.sClass
          && x.sDetail == y.sDetail
          && x.sSource == y.sSource
          && x.tType == y.tType
          && x.bike == y.bike
          && x.foot == y.foot;
    }

    /** Contracts a degree-2 node when both sides agree; returns its two neighbours, or null. */
    int[] tryContract(int node, List<EdgeRec> edges, IntList[] adj, boolean[] nodeAlive) {
      if (!nodeAlive[node] || ndang[node] || adj[node].size() != 2) {
        return null;
      }
      int ia = adj[node].get(0);
      int ib = adj[node].get(1);
      if (ia == ib) {
        return null;
      }
      EdgeRec ea = edges.get(ia);
      EdgeRec eb = edges.get(ib);
      int a = ea.u == node ? ea.v : ea.u;
      int b = eb.u == node ? eb.v : eb.u;
      if (a == b || a == node || b == node) {
        return null;
      }
      if (!Arrays.equals(ea.tracks, eb.tracks) || !sameAttributes(ea, eb)) {
        return null;
      }
      boolean allowAN = ea.v == node ? ea.allowUV : ea.allowVU;
      boolean allowNA = ea.v == node ? ea.allowVU : ea.allowUV;
      boolean allowNB = eb.u == node ? eb.allowUV : eb.allowVU;
      boolean allowBN = eb.u == node ? eb.allowVU : eb.allowUV;
      boolean allowAB = allowAN && allowNB;
      boolean allowBA = allowBN && allowNA;
      if (!allowAB && !allowBA) {
        return null;
      }
      double[] ax = ea.u == a ? ea.xs : Geo.reversed(ea.xs);
      double[] ay = ea.u == a ? ea.ys : Geo.reversed(ea.ys);
      double gainA = ea.u == a ? ea.gainUV : ea.lossUV;
      double lossA = ea.u == a ? ea.lossUV : ea.gainUV;
      double[] bx = eb.u == node ? eb.xs : Geo.reversed(eb.xs);
      double[] by = eb.u == node ? eb.ys : Geo.reversed(eb.ys);
      double gainB = eb.u == node ? eb.gainUV : eb.lossUV;
      double lossB = eb.u == node ? eb.lossUV : eb.gainUV;
      // a turn the route could not make must not hide inside one edge (review B1)
      double[] ha = Geo.headings(ax, ay, p.headingNearM(), p.headingFarM());
      double[] hb = Geo.headings(bx, by, p.headingNearM(), p.headingFarM());
      if (Geo.turnAngleDeg(ha[1], hb[0]) >= p.contractionMaxTurnDeg()) {
        return null;
      }
      if (hidesClusterTurn(node, ia, ib, edges, adj, nodeAlive)) {
        return null;
      }
      EdgeRec merged = new EdgeRec();
      merged.u = a;
      merged.v = b;
      merged.tracks = ea.tracks;
      merged.xs = new double[ax.length + bx.length - 1];
      merged.ys = new double[ax.length + bx.length - 1];
      System.arraycopy(ax, 0, merged.xs, 0, ax.length);
      System.arraycopy(ay, 0, merged.ys, 0, ay.length);
      System.arraycopy(bx, 1, merged.xs, ax.length, bx.length - 1);
      System.arraycopy(by, 1, merged.ys, ay.length, by.length - 1);
      merged.length = ea.length + eb.length;
      merged.gainUV = gainA + gainB;
      merged.lossUV = lossA + lossB;
      merged.allowUV = allowAB;
      merged.allowVU = allowBA;
      merged.wayKind = ea.wayKind;
      merged.sClass = ea.sClass;
      merged.sDetail = ea.sDetail;
      merged.sSource = ea.sSource;
      merged.tType = ea.tType;
      merged.bike = ea.bike;
      merged.foot = ea.foot;
      int twin = findTwin(merged, edges, adj[a], ia, ib);
      if (twin >= 0) {
        // The contraction produced a second copy of an edge a-b: fold it into the first one, or
        // the checker (which keys reuse on edge id) would let a route ride one copy out and the
        // other back.
        absorb(edges.get(twin), merged);
        ea.fwd = edges.get(twin);
        eb.fwd = edges.get(twin);
        ea.alive = false;
        eb.alive = false;
        adj[a].remove(ia);
        adj[b].remove(ib);
        adj[node].clear();
        nodeAlive[node] = false;
        return new int[] {a, b};
      }
      int id = edges.size();
      edges.add(merged);
      ea.fwd = merged;
      eb.fwd = merged;
      ea.alive = false;
      eb.alive = false;
      adj[a].replace(ia, id);
      adj[b].replace(ib, id);
      adj[node].clear();
      nodeAlive[node] = false;
      return new int[] {a, b};
    }

    /**
     * The checker also refuses a turn spread over junctions less than {@link
     * RouteGuarantees#CLUSTER_M} apart (the two ends of a dual carriageway closing on a node other
     * than where it opened). Contracting one node of such a cluster would hide it, whichever node
     * is looked at first, so refuse when the heading before any point within that distance upstream
     * and the heading after any point within it downstream differ by the contraction maximum. The
     * chain is walked through degree-2 nodes, so earlier contractions are seen as merged geometry.
     */
    boolean hidesClusterTurn(
        int node, int ia, int ib, List<EdgeRec> edges, IntList[] adj, boolean[] nodeAlive) {
      double reach = RouteGuarantees.CLUSTER_M + p.headingFarM();
      List<double[][]> ups = new ArrayList<>();
      List<double[][]> downs = new ArrayList<>();
      walkAll(node, node, ia, 0, null, reach, edges, adj, nodeAlive, ups);
      walkAll(node, node, ib, 0, null, reach, edges, adj, nodeAlive, downs);
      if (ups.size() >= MAX_WALKS || downs.size() >= MAX_WALKS) {
        return true; // the enumeration was cut short: it may have missed the turn (design 12.13)
      }
      for (double[][] up : ups) {
        for (double[][] down : downs) {
          if (turnsBack(up, down)) {
            return true;
          }
        }
      }
      return false;
    }

    /** Would the route through {@code up} (read backwards) then {@code down} turn back on itself? */
    boolean turnsBack(double[][] up, double[][] down) {
      double[] ux = Geo.reversed(up[0]);
      double[] uy = Geo.reversed(up[1]);
      double[] xs = new double[ux.length + down[0].length - 1];
      double[] ys = new double[xs.length];
      System.arraycopy(ux, 0, xs, 0, ux.length);
      System.arraycopy(uy, 0, ys, 0, uy.length);
      System.arraycopy(down[0], 1, xs, ux.length, down[0].length - 1);
      System.arraycopy(down[1], 1, ys, uy.length, down[1].length - 1);
      double c = Geo.polylineLength(up[0], up[1]);
      double total = Geo.polylineLength(xs, ys);
      double step = 10;
      int steps = (int) (RouteGuarantees.CLUSTER_M / step);
      for (int i = 0; i <= steps; i++) {
        double before = c - i * step;
        if (before < 1) {
          break;
        }
        double hIn = windowBefore(xs, ys, before);
        for (int j = 0; j <= steps - i; j++) {
          double after = c + j * step;
          if (after > total - 1) {
            break;
          }
          if (Geo.turnAngleDeg(hIn, windowAfter(xs, ys, total, after))
              >= p.contractionMaxTurnDeg()) {
            return true;
          }
        }
      }
      return false;
    }

    double windowBefore(double[] xs, double[] ys, double pos) {
      double far = Math.min(p.headingFarM(), pos);
      double near = Math.min(p.headingNearM(), far / 2);
      double[] a = Geo.pointAt(xs, ys, pos - far);
      double[] b = Geo.pointAt(xs, ys, pos - near);
      return Geo.bearingDeg(a[0], a[1], b[0], b[1]);
    }

    double windowAfter(double[] xs, double[] ys, double total, double pos) {
      double far = Math.min(p.headingFarM(), total - pos);
      double near = Math.min(p.headingNearM(), far / 2);
      double[] a = Geo.pointAt(xs, ys, pos + near);
      double[] b = Geo.pointAt(xs, ys, pos + far);
      return Geo.bearingDeg(a[0], a[1], b[0], b[1]);
    }

    /** Cap on the continuations followed past junctions, per side of a contraction candidate. */
    static final int MAX_WALKS = 16;

    /**
     * Polylines leaving {@code origin} along edge {@code edgeId}, continued until {@code reach}
     * metres: straight through degree-2 nodes and, at a junction within reach, along every other
     * edge there (a turn is hidden whatever way the route continues past a nearby junction; the
     * polyline that stops at the junction is kept too). At most {@link #MAX_WALKS} are returned.
     */
    void walkAll(
        int origin,
        int from,
        int edgeId,
        double accIn,
        double[][] prefix,
        double reach,
        List<EdgeRec> edges,
        IntList[] adj,
        boolean[] nodeAlive,
        List<double[][]> out) {
      if (out.size() >= MAX_WALKS) {
        return;
      }
      EdgeRec e = edges.get(edgeId);
      boolean fwd = e.u == from;
      double[] ex = fwd ? e.xs : Geo.reversed(e.xs);
      double[] ey = fwd ? e.ys : Geo.reversed(e.ys);
      int skip = prefix == null ? 0 : 1;
      int pn = prefix == null ? 0 : prefix[0].length;
      double[] xs = new double[pn + ex.length - skip];
      double[] ys = new double[xs.length];
      if (prefix != null) {
        System.arraycopy(prefix[0], 0, xs, 0, pn);
        System.arraycopy(prefix[1], 0, ys, 0, pn);
      }
      System.arraycopy(ex, skip, xs, pn, ex.length - skip);
      System.arraycopy(ey, skip, ys, pn, ey.length - skip);
      double[][] pts = {xs, ys};
      double acc = accIn + e.length;
      int next = fwd ? e.v : e.u;
      if (acc >= reach || xs.length > 2000 || next == origin || !nodeAlive[next] || ndang[next]) {
        out.add(pts);
        return;
      }
      if (adj[next].size() == 2) {
        int other = adj[next].get(0) == edgeId ? adj[next].get(1) : adj[next].get(0);
        if (other == edgeId) {
          out.add(pts);
          return;
        }
        walkAll(origin, next, other, acc, pts, reach, edges, adj, nodeAlive, out);
        return;
      }
      out.add(pts);
      for (int k = 0; k < adj[next].size(); k++) {
        int other = adj[next].get(k);
        if (other != edgeId) {
          walkAll(origin, next, other, acc, pts, reach, edges, adj, nodeAlive, out);
        }
      }
    }

    /** Finds an alive edge between the same two nodes as {@code merged} with the same geometry. */
    int findTwin(EdgeRec merged, List<EdgeRec> edges, IntList atA, int skipA, int skipB) {
      for (int i = 0; i < atA.size(); i++) {
        int id = atA.get(i);
        if (id == skipA || id == skipB) {
          continue;
        }
        EdgeRec c = edges.get(id);
        if (!c.alive
            || !((c.u == merged.u && c.v == merged.v) || (c.u == merged.v && c.v == merged.u))) {
          continue;
        }
        boolean same = c.u == merged.u;
        double[] cx = same ? c.xs : Geo.reversed(c.xs);
        double[] cy = same ? c.ys : Geo.reversed(c.ys);
        if (lengthClose(merged.length, c.length) && sameGeometry(merged.xs, merged.ys, cx, cy)) {
          return id;
        }
      }
      return -1;
    }

    boolean sameGeometry(double[] xs1, double[] ys1, double[] xs2, double[] ys2) {
      int s = p.dedupSamples();
      double[] r1 = Geo.resample(xs1, ys1, s);
      double[] r2 = Geo.resample(xs2, ys2, s);
      double sum = 0;
      for (int i = 0; i < s; i++) {
        sum += Math.hypot(r1[2 * i] - r2[2 * i], r1[2 * i + 1] - r2[2 * i + 1]);
      }
      return sum / s < p.dedupMeanDistM();
    }

    /** Folds {@code other} (same endpoints, same geometry) into {@code keep}. */
    void absorb(EdgeRec keep, EdgeRec other) {
      boolean same = keep.u == other.u;
      boolean otherUV = same ? other.allowUV : other.allowVU;
      boolean otherVU = same ? other.allowVU : other.allowUV;
      keep.allowUV |= otherUV;
      keep.allowVU |= otherVU;
      java.util.TreeSet<Long> union = new java.util.TreeSet<>();
      for (long t : keep.tracks) {
        union.add(t);
      }
      for (long t : other.tracks) {
        union.add(t);
      }
      keep.tracks = union.stream().mapToLong(Long::longValue).toArray();
    }

    private static EdgeRec resolve(EdgeRec e) {
      while (e.fwd != null) {
        e = e.fwd;
      }
      return e;
    }

    /**
     * The recorded transitions on the final edges and nodes, each with the passes (track, rank)
     * that made it. The rank numbers a track's steps between two different final edges in the
     * order of its own ride, a drop or an orphan in its chain jumping it by 3, so that two
     * transitions belong to one pass exactly when their ranks are consecutive (design 12.13.2).
     */
    java.util.Map<NetworkGraph.Transition, NetworkGraph.Passes> transitionTable(
        List<EdgeRec> edges, int[] nodeMap) {
      java.util.Map<EdgeRec, Integer> index = new java.util.IdentityHashMap<>();
      for (int i = 0; i < edges.size(); i++) {
        index.put(edges.get(i), i);
      }
      java.util.Map<NetworkGraph.Transition, java.util.TreeSet<long[]>> table =
          new java.util.HashMap<>();
      java.util.Map<Long, Integer> rankOf = new java.util.HashMap<>();
      int lastStep = -1;
      int stepRank = 0;
      for (RawTransition t : transitions) {
        if (t.step() != lastStep) {
          lastStep = t.step();
          EdgeRec ra = resolve(t.from());
          EdgeRec rb = resolve(t.to());
          int rank = rankOf.getOrDefault(t.track(), 0);
          if (t.breakBefore()) {
            rank += 2;
          }
          if (ra != rb) {
            rank++;
          }
          rankOf.put(t.track(), rank);
          stepRank = rank;
        }
        EdgeRec a = resolve(t.from());
        EdgeRec b = resolve(t.to());
        Integer ia = index.get(a);
        Integer ib = index.get(b);
        if (a == b || ia == null || ib == null || nodeMap[t.node()] < 0) {
          continue;
        }
        if (a.u != t.node() && a.v != t.node() || b.u != t.node() && b.v != t.node()) {
          continue; // the node was contracted away
        }
        table
            .computeIfAbsent(
                new NetworkGraph.Transition(nodeMap[t.node()], ia, ib),
                k ->
                    new java.util.TreeSet<>((x, y) ->
                        x[0] != y[0] ? Long.compare(x[0], y[0]) : Long.compare(x[1], y[1])))
            .add(new long[] {t.track(), stepRank});
      }
      java.util.Map<NetworkGraph.Transition, NetworkGraph.Passes> out = new java.util.HashMap<>();
      table.forEach((k, v) -> {
        long[] tracks = new long[v.size()];
        int[] ranks = new int[v.size()];
        int w = 0;
        for (long[] pr : v) {
          tracks[w] = pr[0];
          ranks[w++] = (int) pr[1];
        }
        out.put(k, new NetworkGraph.Passes(tracks, ranks));
      });
      return out;
    }

    NetworkGraph assemble(List<EdgeRec> allEdges, IntList[] adj, boolean[] nodeAlive) {
      List<EdgeRec> edges = new ArrayList<>();
      for (EdgeRec e : allEdges) {
        if (e.alive) {
          edges.add(e);
        }
      }
      int[] nodeMap = new int[n];
      Arrays.fill(nodeMap, -1);
      int nodeCount = 0;
      for (int i = 0; i < n; i++) {
        if (nodeAlive[i] && !adj[i].isEmpty()) {
          nodeMap[i] = nodeCount++;
        }
      }
      int edgeCount = edges.size();
      NetworkGraph.Assembly a = new NetworkGraph.Assembly();
      a.nodeX = new double[nodeCount];
      a.nodeY = new double[nodeCount];
      a.nodeStreetDegree = new int[nodeCount];
      a.nodeDangling = new boolean[nodeCount];
      a.nodeRiddenThrough = new boolean[nodeCount];
      int[] firstEdge = new int[nodeCount];
      int[] incident = new int[nodeCount];
      Arrays.fill(firstEdge, -1);
      for (int i = 0; i < edgeCount; i++) {
        EdgeRec e = edges.get(i);
        for (int end : new int[] {nodeMap[e.u], nodeMap[e.v]}) {
          incident[end]++;
          if (incident[end] == 1) {
            firstEdge[end] = i;
          } else if (incident[end] == 2 && e.u != e.v) {
            // a team node of degree 2 is ridden through when one live track rides both its edges
            long[] other = edges.get(firstEdge[end]).tracks;
            for (long t : e.tracks) {
              if (Arrays.binarySearch(other, t) >= 0) {
                a.nodeRiddenThrough[end] = true;
                break;
              }
            }
          }
        }
      }
      for (int i = 0; i < nodeCount; i++) {
        a.nodeRiddenThrough[i] &= incident[i] == 2;
      }
      for (int i = 0; i < n; i++) {
        int m = nodeMap[i];
        if (m >= 0) {
          a.nodeX[m] = nx[i];
          a.nodeY[m] = ny[i];
          a.nodeStreetDegree[m] = nstreet[i];
          a.nodeDangling[m] = ndang[i];
        }
      }
      a.edgeU = new int[edgeCount];
      a.edgeV = new int[edgeCount];
      a.edgeLength = new double[edgeCount];
      a.gainUV = new float[edgeCount];
      a.lossUV = new float[edgeCount];
      a.allowUV = new boolean[edgeCount];
      a.allowVU = new boolean[edgeCount];
      a.support = new int[edgeCount];
      a.trackOffset = new int[edgeCount + 1];
      a.supportByKind = new int[4 * edgeCount];
      a.z = new float[edgeCount];
      a.zByType = new float[3][edgeCount];
      a.surface = new byte[edgeCount];
      a.surfaceDetail = new byte[edgeCount];
      a.surfaceSource = new byte[edgeCount];
      a.wayKind = new byte[edgeCount];
      a.trackType = new byte[edgeCount];
      a.bicycle = new byte[edgeCount];
      a.foot = new byte[edgeCount];
      a.geomOffset = new int[edgeCount + 1];
      a.startHeading = new float[2 * edgeCount];
      a.endHeading = new float[2 * edgeCount];
      int maxSupport = 0;
      double total = 0;
      int points = 0;
      double scale = 1;
      for (EdgeRec e : edges) {
        maxSupport = Math.max(maxSupport, e.tracks.length);
        points += e.xs.length;
        double proj = Geo.polylineLength(e.xs, e.ys);
        if (proj > 0) {
          scale = Math.min(scale, e.length / proj);
        }
      }
      a.aStarScale = 0.999 * Math.max(0, Math.min(1, scale));
      a.geomX = new double[points];
      a.geomY = new double[points];
      int[] degree = new int[nodeCount];
      double[][] s = new double[3][edgeCount];
      double[] maxS = new double[3];
      int pos = 0;
      for (int i = 0; i < edgeCount; i++) {
        EdgeRec e = edges.get(i);
        a.edgeU[i] = nodeMap[e.u];
        a.edgeV[i] = nodeMap[e.v];
        degree[a.edgeU[i]]++;
        degree[a.edgeV[i]]++;
        a.edgeLength[i] = e.length;
        total += e.length;
        a.gainUV[i] = (float) e.gainUV;
        a.lossUV[i] = (float) e.lossUV;
        a.allowUV[i] = e.allowUV;
        a.allowVU[i] = e.allowVU;
        a.support[i] = e.tracks.length;
        a.trackOffset[i + 1] = a.trackOffset[i] + e.tracks.length;
        for (long t : e.tracks) {
          TrackKind k = kindOf.get(t);
          if (k != null) {
            a.supportByKind[4 * i + k.ordinal()]++;
          }
        }
        int road = a.supportByKind[4 * i];
        int gravel = a.supportByKind[4 * i + 1];
        int mtb = a.supportByKind[4 * i + 2];
        int mixed = a.supportByKind[4 * i + 3];
        s[0][i] = road + mixed + SECONDARY_WEIGHT * 0;
        s[1][i] = gravel + mixed + SECONDARY_WEIGHT * road;
        s[2][i] = mtb + SECONDARY_WEIGHT * (gravel + mixed);
        for (int k = 0; k < 3; k++) {
          maxS[k] = Math.max(maxS[k], s[k][i]);
        }
        a.surface[i] = e.sClass;
        a.surfaceDetail[i] = e.sDetail;
        a.surfaceSource[i] = e.sSource;
        a.wayKind[i] = e.wayKind;
        a.trackType[i] = e.tType;
        a.bicycle[i] = e.bike;
        a.foot[i] = e.foot;
        a.geomOffset[i] = pos;
        System.arraycopy(e.xs, 0, a.geomX, pos, e.xs.length);
        System.arraycopy(e.ys, 0, a.geomY, pos, e.xs.length);
        pos += e.xs.length;
        double[] h = Geo.headings(e.xs, e.ys, p.headingNearM(), p.headingFarM());
        a.startHeading[2 * i] = (float) h[0];
        a.endHeading[2 * i] = (float) h[1];
        a.startHeading[2 * i + 1] = (float) Geo.normalizeDeg(h[1] + 180);
        a.endHeading[2 * i + 1] = (float) Geo.normalizeDeg(h[0] + 180);
      }
      for (int i = 0; i < edgeCount; i++) {
        a.z[i] = maxSupport <= 0 ? 0f : (float) (Math.log1p(a.support[i]) / Math.log1p(maxSupport));
        for (int k = 0; k < 3; k++) {
          a.zByType[k][i] = maxS[k] <= 0 ? 0f : (float) (Math.log1p(s[k][i]) / Math.log1p(maxS[k]));
        }
      }
      a.geomOffset[edgeCount] = pos;
      a.transitions = transitionTable(edges, nodeMap);
      a.trackIds = new long[a.trackOffset[edgeCount]];
      for (int i = 0; i < edgeCount; i++) {
        long[] t = edges.get(i).tracks;
        System.arraycopy(t, 0, a.trackIds, a.trackOffset[i], t.length);
      }
      a.nodeDegree = degree;

      // CSR adjacency: states leaving each node, ascending state id.
      a.adjOffset = new int[nodeCount + 1];
      for (int i = 0; i < edgeCount; i++) {
        a.adjOffset[a.edgeU[i] + 1]++;
        a.adjOffset[a.edgeV[i] + 1]++;
      }
      for (int i = 0; i < nodeCount; i++) {
        a.adjOffset[i + 1] += a.adjOffset[i];
      }
      int[] fill = Arrays.copyOf(a.adjOffset, nodeCount);
      a.adjState = new int[2 * edgeCount];
      for (int i = 0; i < edgeCount; i++) {
        a.adjState[fill[a.edgeU[i]]++] = 2 * i;
        a.adjState[fill[a.edgeV[i]]++] = 2 * i + 1;
      }

      BridgeFinder.Result bridges = BridgeFinder.find(nodeCount, a.edgeU, a.edgeV, a.edgeLength);
      a.bridge = bridges.bridge();
      a.nodeComponent = bridges.component();
      a.componentCount = bridges.componentCount();
      a.componentLength = bridges.componentLength();

      a.projection = projection;
      a.parameters = p;
      a.nodeGrid = new SpatialGrid(100);
      for (int i = 0; i < nodeCount; i++) {
        a.nodeGrid.add(a.nodeX[i], a.nodeY[i], i);
      }
      a.segmentGrid = new SpatialGrid(SEGMENT_CELL_M);
      for (int i = 0; i < edgeCount; i++) {
        insertEdge(a.segmentGrid, i, a.geomX, a.geomY, a.geomOffset[i], a.geomOffset[i + 1]);
      }
      buildCorridors(a, edgeCount);

      int dangling = 0;
      for (boolean d : a.nodeDangling) {
        if (d) {
          dangling++;
        }
      }
      int excluded = 0;
      int inputEdges = 0;
      Map<TrackKind, Integer> byKind = new EnumMap<>(TrackKind.class);
      for (TrackInput t : tracks) {
        if (t.excluded()) {
          excluded++;
        } else {
          byKind.merge(t.kind(), 1, Integer::sum);
        }
        inputEdges += t.edges().size();
      }
      a.stats =
          new NetworkStats(
              tracks.size(),
              excluded,
              inputEdges,
              edgeCount,
              nodeCount,
              total,
              dangling,
              maxSupport,
              dropped,
              floating,
              orphans,
              stitched,
              selfLoops,
              unknownDetails,
              java.util.Collections.unmodifiableMap(byKind));
      return new NetworkGraph(a);
    }

    void buildCorridors(NetworkGraph.Assembly a, int edgeCount) {
      double step = p.corridorSampleStepM();
      double endIgnore = p.corridorEndIgnoreM();
      double dist = p.corridorDistM();
      double pad = dist + SEGMENT_CELL_M / 4;
      int[] stamp = new int[edgeCount];
      int cur = 0;
      double[] acc = new double[edgeCount];
      IntList touched = new IntList();
      long[] pairs = new long[64];
      int[] pairCount = {0};
      for (int e = 0; e < edgeCount; e++) {
        int from = a.geomOffset[e];
        int to = a.geomOffset[e + 1];
        double[] xs = Arrays.copyOfRange(a.geomX, from, to);
        double[] ys = Arrays.copyOfRange(a.geomY, from, to);
        double len = Geo.polylineLength(xs, ys);
        double sampled = len - 2 * endIgnore;
        if (sampled <= 0) {
          continue;
        }
        touched.clear();
        for (double off = endIgnore; off <= len - endIgnore + 1e-9; off += step) {
          double[] pt = Geo.pointAt(xs, ys, off);
          cur++;
          final int self = e;
          final int stampValue = cur;
          a.segmentGrid.query(
              pt[0] - pad,
              pt[1] - pad,
              pt[0] + pad,
              pt[1] + pad,
              b -> {
                if (b == self || stamp[b] == stampValue) {
                  return;
                }
                stamp[b] = stampValue;
                if (distanceToRange(
                        pt[0], pt[1], a.geomX, a.geomY, a.geomOffset[b], a.geomOffset[b + 1])
                    <= dist) {
                  if (acc[b] == 0) {
                    touched.add(b);
                  }
                  acc[b] += step;
                }
              });
        }
        double threshold = Math.min(p.corridorMinOverlapM(), 0.8 * sampled);
        for (int i = 0; i < touched.size(); i++) {
          int b = touched.get(i);
          if (acc[b] >= threshold) {
            if (pairCount[0] + 2 > pairs.length) {
              pairs = Arrays.copyOf(pairs, pairs.length * 2);
            }
            pairs[pairCount[0]++] = (long) e * edgeCount + b;
            pairs[pairCount[0]++] = (long) b * edgeCount + e;
          }
          acc[b] = 0;
        }
      }
      long[] sorted = Arrays.copyOf(pairs, pairCount[0]);
      Arrays.sort(sorted);
      int[] offset = new int[edgeCount + 1];
      int[] list = new int[sorted.length];
      int count = 0;
      long previous = -1;
      for (long pair : sorted) {
        if (pair == previous) {
          continue;
        }
        previous = pair;
        int from = (int) (pair / edgeCount);
        list[count++] = (int) (pair % edgeCount);
        offset[from + 1]++;
      }
      for (int i = 0; i < edgeCount; i++) {
        offset[i + 1] += offset[i];
      }
      a.corridorOffset = offset;
      a.corridorEdge = Arrays.copyOf(list, count);
    }
  }

  static final double SEGMENT_CELL_M = 50;

  /** Inserts the samples of an edge geometry, at most half a cell apart, into a segment grid. */
  static void insertEdge(SpatialGrid grid, int edge, double[] xs, double[] ys, int from, int to) {
    double spacing = grid.cellSize() / 2;
    grid.add(xs[from], ys[from], edge);
    for (int i = from + 1; i < to; i++) {
      double ax = xs[i - 1];
      double ay = ys[i - 1];
      double len = Math.hypot(xs[i] - ax, ys[i] - ay);
      int pieces = Math.max(1, (int) Math.ceil(len / spacing));
      for (int k = 1; k <= pieces; k++) {
        double t = (double) k / pieces;
        grid.add(ax + t * (xs[i] - ax), ay + t * (ys[i] - ay), edge);
      }
    }
  }

  static double distanceToRange(double px, double py, double[] xs, double[] ys, int from, int to) {
    double best = Double.POSITIVE_INFINITY;
    for (int i = from + 1; i < to; i++) {
      best = Math.min(best, Geo.pointSegmentDistance(px, py, xs[i - 1], ys[i - 1], xs[i], ys[i]));
    }
    return best;
  }
}
