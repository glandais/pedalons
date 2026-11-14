package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.BitSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import org.jspecify.annotations.Nullable;

/**
 * A {@link NetworkGraph} plus up to a few split points: where the start or the end snaps in the
 * middle of an edge, that edge is replaced by virtual pieces joined by virtual nodes. This is the
 * only graph type the search and {@link RouteGuarantees} consume, so S and E are always nodes.
 *
 * <p>Why a view and not a copy: the base graph is shared across requests by the lot 3 cache and
 * holds tens of thousands of edges; a request only touches a handful of them. The split parent is
 * <em>masked</em>: the adjacency of its two ends lists the virtual pieces instead. Virtual edge ids
 * follow the base ids ({@code baseE + i}), virtual node ids likewise.
 */
public final class QueryGraph {
  private static final double MERGE_CUTS_M = 0.5;

  private final NetworkGraph base;
  private final int baseN;
  private final int baseE;
  private final int vN;
  private final int vE;
  private final int[] snapNode;

  // virtual nodes
  private final double[] vNodeX;
  private final double[] vNodeY;
  private final int[] vNodeComponent;
  private final int[] vNodeAdj; // two states per virtual node

  // virtual edges
  private final int[] vU;
  private final int[] vV;
  private final int[] vParent;
  private final double[] vLength;
  private final double[] vGainUV;
  private final double[] vLossUV;
  private final boolean[] vAllowUV;
  private final boolean[] vAllowVU;
  private final float[] vStartHeading;
  private final float[] vEndHeading;
  private final double[][] vGeomX;
  private final double[][] vGeomY;
  private final double[] vPolyLen;
  private final double[][] vGeomCum;

  // overrides
  private final int[] overrideNode;
  private final int[][] overrideAdj;
  private final BitSet masked;
  private final Map<Integer, int[]> pieces;
  private final int extraComponents;

  /** A query graph without any split: algorithm tests and callers whose S and E are nodes. */
  public static QueryGraph of(NetworkGraph g) {
    return new QueryGraph(g, List.of(), 0);
  }

  /**
   * Splits the edges where the snaps fall. A snap within {@code snapToNodeM} of an end node becomes
   * that node (no split); several snaps on one edge less than 0.5 m apart share one virtual node.
   * {@link #snapNode(int)} gives the query node of each snap, in input order.
   */
  public static QueryGraph create(NetworkGraph g, List<Snap> snaps, double snapToNodeM) {
    return new QueryGraph(g, snaps, snapToNodeM);
  }

  private QueryGraph(NetworkGraph g, List<Snap> snaps, double snapToNodeM) {
    this.base = g;
    this.baseN = g.nodeCount();
    this.baseE = g.edgeCount();
    int[] nodeOfSnap = new int[snaps.size()];
    Arrays.fill(nodeOfSnap, -1);
    TreeMap<Integer, List<double[]>> cutsByEdge = new TreeMap<>();
    for (int i = 0; i < snaps.size(); i++) {
      Snap s = snaps.get(i);
      int e = s.edge();
      double len = g.length(e);
      double off = Math.max(0, Math.min(len, s.offsetM()));
      if (off <= len / 2 && off < snapToNodeM) {
        nodeOfSnap[i] = g.edgeU(e);
      } else if (off > len / 2 && len - off < snapToNodeM) {
        nodeOfSnap[i] = g.edgeV(e);
      } else {
        cutsByEdge.computeIfAbsent(e, k -> new ArrayList<>()).add(new double[] {off, i});
      }
    }

    List<double[]> nodes = new ArrayList<>(); // x, y
    List<Integer> nodeComp = new ArrayList<>();
    List<int[]> nodeAdj = new ArrayList<>();
    List<Object[]> edges = new ArrayList<>();
    Map<Integer, int[]> pieceMap = new LinkedHashMap<>();
    Map<Integer, int[]> overrides = new LinkedHashMap<>();
    BitSet maskedSet = new BitSet();
    int extra = 0;
    NetworkParameters np = g.parameters();

    for (Map.Entry<Integer, List<double[]>> entry : cutsByEdge.entrySet()) {
      int parent = entry.getKey();
      List<double[]> cuts = entry.getValue();
      cuts.sort((a, b) -> a[0] != b[0] ? Double.compare(a[0], b[0]) : Double.compare(a[1], b[1]));
      double len = g.length(parent);
      double[] xs = g.geometryX(parent);
      double[] ys = g.geometryY(parent);
      double projected = Geo.polylineLength(xs, ys);
      double scale = len <= 0 ? 0 : projected / len;
      // cluster the cuts
      List<Double> offsets = new ArrayList<>();
      List<Integer> firstNode = new ArrayList<>();
      int firstNodeId = baseN + nodes.size();
      for (double[] cut : cuts) {
        int snapIndex = (int) cut[1];
        if (offsets.isEmpty() || cut[0] - offsets.get(offsets.size() - 1) >= MERGE_CUTS_M) {
          offsets.add(cut[0]);
          int id = baseN + nodes.size();
          double[] pt = Geo.pointAt(xs, ys, cut[0] * scale);
          nodes.add(pt);
          boolean bridge = g.isBridge(parent);
          nodeComp.add(bridge ? g.componentCount() + extra++ : g.component(g.edgeU(parent)));
          nodeAdj.add(new int[2]);
          firstNode.add(id);
        }
        nodeOfSnap[snapIndex] = firstNode.get(firstNode.size() - 1);
      }
      int k = offsets.size();
      int[] chain = new int[k + 2];
      chain[0] = g.edgeU(parent);
      for (int i = 0; i < k; i++) {
        chain[i + 1] = firstNodeId + i;
      }
      chain[k + 1] = g.edgeV(parent);
      double[] bounds = new double[k + 2];
      for (int i = 0; i < k; i++) {
        bounds[i + 1] = offsets.get(i);
      }
      bounds[k + 1] = len;
      int[] ids = new int[k + 1];
      for (int j = 0; j <= k; j++) {
        int id = baseE + edges.size();
        ids[j] = id;
        double pieceLen = bounds[j + 1] - bounds[j];
        double[][] slice = Geo.slice(xs, ys, bounds[j] * scale, bounds[j + 1] * scale);
        double[] sh;
        if (Geo.polylineLength(slice[0], slice[1]) < 1.0) {
          double bearing = Geo.localBearing(xs, ys, bounds[j] * scale);
          sh = new double[] {bearing, bearing};
        } else {
          sh = Geo.headings(slice[0], slice[1], np.headingNearM(), np.headingFarM());
        }
        double share = len <= 0 ? 0 : pieceLen / len;
        edges.add(
            new Object[] {
              chain[j],
              chain[j + 1],
              parent,
              pieceLen,
              g.gain(2 * parent) * share,
              g.loss(2 * parent) * share,
              g.allowed(2 * parent),
              g.allowed(2 * parent + 1),
              sh,
              slice
            });
      }
      pieceMap.put(parent, ids);
      maskedSet.set(parent);
      for (int i = 0; i < k; i++) {
        nodeAdj.get(firstNodeId - baseN + i)[0] = 2 * ids[i] + 1;
        nodeAdj.get(firstNodeId - baseN + i)[1] = 2 * ids[i + 1];
      }
      overrideState(overrides, g, g.edgeU(parent), 2 * parent, 2 * ids[0]);
      overrideState(overrides, g, g.edgeV(parent), 2 * parent + 1, 2 * ids[k] + 1);
    }

    this.vN = nodes.size();
    this.vE = edges.size();
    this.snapNode = nodeOfSnap;
    this.vNodeX = new double[vN];
    this.vNodeY = new double[vN];
    this.vNodeComponent = new int[vN];
    this.vNodeAdj = new int[2 * vN];
    for (int i = 0; i < vN; i++) {
      vNodeX[i] = nodes.get(i)[0];
      vNodeY[i] = nodes.get(i)[1];
      vNodeComponent[i] = nodeComp.get(i);
      vNodeAdj[2 * i] = nodeAdj.get(i)[0];
      vNodeAdj[2 * i + 1] = nodeAdj.get(i)[1];
    }
    this.vU = new int[vE];
    this.vV = new int[vE];
    this.vParent = new int[vE];
    this.vLength = new double[vE];
    this.vGainUV = new double[vE];
    this.vLossUV = new double[vE];
    this.vAllowUV = new boolean[vE];
    this.vAllowVU = new boolean[vE];
    this.vStartHeading = new float[2 * vE];
    this.vEndHeading = new float[2 * vE];
    this.vGeomX = new double[vE][];
    this.vGeomY = new double[vE][];
    this.vPolyLen = new double[vE];
    this.vGeomCum = new double[vE][];
    for (int i = 0; i < vE; i++) {
      Object[] o = edges.get(i);
      vU[i] = (Integer) o[0];
      vV[i] = (Integer) o[1];
      vParent[i] = (Integer) o[2];
      vLength[i] = (Double) o[3];
      vGainUV[i] = (Double) o[4];
      vLossUV[i] = (Double) o[5];
      vAllowUV[i] = (Boolean) o[6];
      vAllowVU[i] = (Boolean) o[7];
      double[] h = (double[]) o[8];
      vStartHeading[2 * i] = (float) h[0];
      vEndHeading[2 * i] = (float) h[1];
      vStartHeading[2 * i + 1] = (float) Geo.normalizeDeg(h[1] + 180);
      vEndHeading[2 * i + 1] = (float) Geo.normalizeDeg(h[0] + 180);
      double[][] slice = (double[][]) o[9];
      vGeomX[i] = slice[0];
      vGeomY[i] = slice[1];
      vPolyLen[i] = Geo.polylineLength(slice[0], slice[1]);
      vGeomCum[i] = new double[slice[0].length];
      Geo.cumulate(slice[0], slice[1], 0, slice[0].length, vGeomCum[i]);
    }
    this.overrideNode = new int[overrides.size()];
    this.overrideAdj = new int[overrides.size()][];
    int idx = 0;
    for (Map.Entry<Integer, int[]> o : overrides.entrySet()) {
      overrideNode[idx] = o.getKey();
      overrideAdj[idx++] = o.getValue();
    }
    this.masked = maskedSet;
    this.pieces = pieceMap;
    this.extraComponents = extra;
  }

  private static void overrideState(
      Map<Integer, int[]> overrides, NetworkGraph g, int node, int oldState, int newState) {
    int[] adj = overrides.get(node);
    if (adj == null) {
      adj = Arrays.copyOfRange(g.adjStates(), g.outFrom(node), g.outTo(node));
      overrides.put(node, adj);
    }
    for (int i = 0; i < adj.length; i++) {
      if (adj[i] == oldState) {
        adj[i] = newState;
        return;
      }
    }
    throw new IllegalStateException("state " + oldState + " not leaving node " + node);
  }

  // ---- sizes ----------------------------------------------------------------------------------

  public NetworkGraph base() {
    return base;
  }

  public int nodeCount() {
    return baseN + vN;
  }

  public int edgeCount() {
    return baseE + vE;
  }

  public int stateCount() {
    return 2 * (baseE + vE);
  }

  /** Query node of the {@code i}-th snap given to {@link #create}. */
  public int snapNode(int i) {
    return snapNode[i];
  }

  public NetworkParameters parameters() {
    return base.parameters();
  }

  LocalProjection projection() {
    return base.projection();
  }

  // ---- nodes ----------------------------------------------------------------------------------

  public double nodeX(int node) {
    return node < baseN ? base.nodeX(node) : vNodeX[node - baseN];
  }

  public double nodeY(int node) {
    return node < baseN ? base.nodeY(node) : vNodeY[node - baseN];
  }

  public LatLon nodeLatLon(int node) {
    return projection().toLatLon(nodeX(node), nodeY(node));
  }

  public int degree(int node) {
    return node < baseN ? base.degree(node) : 2;
  }

  public boolean dangling(int node) {
    return node < baseN && base.dangling(node);
  }

  public int component(int node) {
    return node < baseN ? base.component(node) : vNodeComponent[node - baseN];
  }

  public int componentCount() {
    return base.componentCount() + extraComponents;
  }

  public double componentLength(int component) {
    return component < base.componentCount() ? base.componentLength(component) : 0;
  }

  public int outCount(int node) {
    if (node >= baseN) {
      return 2;
    }
    for (int i = 0; i < overrideNode.length; i++) {
      if (overrideNode[i] == node) {
        return overrideAdj[i].length;
      }
    }
    return base.outTo(node) - base.outFrom(node);
  }

  /** The {@code i}-th state leaving {@code node}, ascending state order for base nodes. */
  public int outState(int node, int i) {
    if (node >= baseN) {
      return vNodeAdj[2 * (node - baseN) + i];
    }
    for (int k = 0; k < overrideNode.length; k++) {
      if (overrideNode[k] == node) {
        return overrideAdj[k][i];
      }
    }
    return base.adjState(base.outFrom(node) + i);
  }

  // ---- edges and states -----------------------------------------------------------------------

  /** True for a base edge replaced by virtual pieces: it appears in no adjacency. */
  public boolean isMasked(int edge) {
    return edge < baseE && masked.get(edge);
  }

  /** The virtual pieces of a split base edge, in u→v order, or null. */
  public int @Nullable [] pieces(int baseEdge) {
    int[] p = pieces.get(baseEdge);
    return p == null ? null : p.clone();
  }

  /** The base edge a (possibly virtual) edge comes from. */
  public int parentEdge(int edge) {
    return edge < baseE ? edge : vParent[edge - baseE];
  }

  public int edgeU(int edge) {
    return edge < baseE ? base.edgeU(edge) : vU[edge - baseE];
  }

  public int edgeV(int edge) {
    return edge < baseE ? base.edgeV(edge) : vV[edge - baseE];
  }

  public int tail(int state) {
    return (state & 1) == 0 ? edgeU(state >>> 1) : edgeV(state >>> 1);
  }

  public int head(int state) {
    return (state & 1) == 0 ? edgeV(state >>> 1) : edgeU(state >>> 1);
  }

  public double length(int edge) {
    return edge < baseE ? base.length(edge) : vLength[edge - baseE];
  }

  public boolean allowed(int state) {
    int e = state >>> 1;
    if (e < baseE) {
      return !masked.get(e) && base.allowed(state);
    }
    return (state & 1) == 0 ? vAllowUV[e - baseE] : vAllowVU[e - baseE];
  }

  public double gain(int state) {
    int e = state >>> 1;
    if (e < baseE) {
      return base.gain(state);
    }
    return (state & 1) == 0 ? vGainUV[e - baseE] : vLossUV[e - baseE];
  }

  public double loss(int state) {
    int e = state >>> 1;
    if (e < baseE) {
      return base.loss(state);
    }
    return (state & 1) == 0 ? vLossUV[e - baseE] : vGainUV[e - baseE];
  }

  public double startHeading(int state) {
    int e = state >>> 1;
    return e < baseE ? base.startHeading(state) : vStartHeading[state - 2 * baseE];
  }

  public double endHeading(int state) {
    int e = state >>> 1;
    return e < baseE ? base.endHeading(state) : vEndHeading[state - 2 * baseE];
  }

  public boolean isBridge(int edge) {
    return base.isBridge(parentEdge(edge));
  }

  public int support(int edge) {
    return base.support(parentEdge(edge));
  }

  public long[] trackIds(int edge) {
    return base.trackIds(parentEdge(edge));
  }

  /** See {@link NetworkGraph#transitionPasses}; split pieces read their parent edge. */
  NetworkGraph.Passes transitionPasses(int node, int fromEdge, int toEdge) {
    return base.transitionPasses(node, parentEdge(fromEdge), parentEdge(toEdge));
  }

  public double z(int edge, ZSource source) {
    return base.z(parentEdge(edge), source);
  }

  public byte surface(int edge) {
    return base.surface(parentEdge(edge));
  }

  public SurfaceClass surfaceClass(int edge) {
    return base.surfaceClass(parentEdge(edge));
  }

  public @Nullable String surfaceDetail(int edge) {
    return base.surfaceDetail(parentEdge(edge));
  }

  public WayKind wayKind(int edge) {
    return base.wayKind(parentEdge(edge));
  }

  public @Nullable OsmTrackType trackType(int edge) {
    return base.trackType(parentEdge(edge));
  }

  public @Nullable Access bicycle(int edge) {
    return base.bicycle(parentEdge(edge));
  }

  public int supportByKind(int edge, TrackKind kind) {
    return base.supportByKind(parentEdge(edge), kind);
  }

  /** True for a node created by a split at S or E. */
  public boolean isVirtual(int node) {
    return node >= baseN;
  }

  /** See {@link NetworkGraph#riddenThrough}; virtual nodes are never turn nodes anyway. */
  public boolean riddenThrough(int node) {
    return node < baseN && base.riddenThrough(node);
  }

  /** Street-graph degree of the node as reported by the producer; virtual nodes report 2. */
  public int streetDegree(int node) {
    return node < baseN ? base.streetDegree(node) : 2;
  }

  /** Corridor neighbours, as base edge ids (a split neighbour is reachable through {@link #pieces}). */
  public int[] corridorNeighbours(int edge) {
    return base.corridorNeighbours(parentEdge(edge));
  }

  // ---- geometry -------------------------------------------------------------------------------

  /** Projected x coordinates of an edge in u→v order (copy). */
  public double[] geometryX(int edge) {
    return edge < baseE ? base.geometryX(edge) : vGeomX[edge - baseE].clone();
  }

  /** Length of the edge geometry as a polyline (no copy). */
  public double polylineLength(int edge) {
    return edge < baseE ? base.polylineLength(edge) : vPolyLen[edge - baseE];
  }

  /** Point {@code offset} metres along the state in travel direction, into {@code out} (no copy). */
  public void pointOnState(int state, double offset, double[] out) {
    int e = state >>> 1;
    if (e < baseE) {
      base.pointOnState(state, offset, out);
    } else {
      double[] xs = vGeomX[e - baseE];
      Geo.pointAlongCum(
          xs, vGeomY[e - baseE], vGeomCum[e - baseE], 0, xs.length, (state & 1) == 1, offset, out);
    }
  }

  public double[] geometryY(int edge) {
    return edge < baseE ? base.geometryY(edge) : vGeomY[edge - baseE].clone();
  }

  public List<LatLon> geometryLatLon(int state) {
    double[] xs = geometryX(state >>> 1);
    double[] ys = geometryY(state >>> 1);
    List<LatLon> out = new ArrayList<>(xs.length);
    LocalProjection proj = projection();
    if ((state & 1) == 0) {
      for (int i = 0; i < xs.length; i++) {
        out.add(proj.toLatLon(xs[i], ys[i]));
      }
    } else {
      for (int i = xs.length - 1; i >= 0; i--) {
        out.add(proj.toLatLon(xs[i], ys[i]));
      }
    }
    return out;
  }
}
