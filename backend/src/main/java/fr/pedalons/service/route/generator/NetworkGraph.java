package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The team network: immutable, thread-safe, everything computed eagerly by {@link
 * NetworkGraphBuilder} so the lot 3 cache can share one instance across requests.
 *
 * <p>Integers index everything: {@code N} nodes, {@code E} edges, {@code 2E} directed states (see
 * {@link States}). Arrays are never exposed.
 */
public final class NetworkGraph {

  /** Mutable bag of arrays filled by the builder; copied into the final fields. */
  static final class Assembly {
    double[] nodeX;
    double[] nodeY;
    int[] nodeDegree;
    int[] nodeStreetDegree;
    boolean[] nodeDangling;
    boolean[] nodeRiddenThrough;
    int[] nodeComponent;
    int[] edgeU;
    int[] edgeV;
    double[] edgeLength;
    float[] gainUV;
    float[] lossUV;
    boolean[] allowUV;
    boolean[] allowVU;
    int[] support;
    int[] trackOffset;
    long[] trackIds;
    java.util.Map<Transition, Passes> transitions;
    float[] z;
    float[][] zByType;
    int[] supportByKind;
    byte[] surface;
    byte[] surfaceDetail;
    byte[] surfaceSource;
    byte[] wayKind;
    byte[] trackType;
    byte[] bicycle;
    byte[] foot;
    double aStarScale = 1;
    boolean[] bridge;
    int[] geomOffset;
    double[] geomX;
    double[] geomY;
    float[] startHeading;
    float[] endHeading;
    int[] adjOffset;
    int[] adjState;
    int[] corridorOffset;
    int[] corridorEdge;
    int componentCount;
    double[] componentLength;
    SpatialGrid nodeGrid;
    SpatialGrid segmentGrid;
    LocalProjection projection;
    NetworkParameters parameters;
    NetworkStats stats;
  }

  /** Surface codes. */
  public static final byte PAVED = 0;

  public static final byte UNPAVED = 1;
  public static final byte UNKNOWN = 2;

  private final double[] nodeX;
  private final double[] nodeY;
  private final int[] nodeDegree;
  private final int[] nodeStreetDegree;
  private final boolean[] nodeDangling;
  private final boolean[] nodeRiddenThrough;
  private final int[] nodeComponent;
  private final int[] edgeU;
  private final int[] edgeV;
  private final double[] edgeLength;
  private final float[] gainUV;
  private final float[] lossUV;
  private final boolean[] allowUV;
  private final boolean[] allowVU;
  private final int[] support;
  private final int[] trackOffset;
  private final long[] trackIds;
  private final java.util.Map<Transition, Passes> transitions;
  private final float[] z;
  private final float[][] zByType;
  private final int[] supportByKind;
  private final byte[] surface;
  private final byte[] surfaceDetail;
  private final byte[] surfaceSource;
  private final byte[] wayKind;
  private final byte[] trackType;
  private final byte[] bicycle;
  private final byte[] foot;
  private final double aStarScale;
  private final boolean[] bridge;
  private final int[] geomOffset;
  private final double[] geomX;
  private final double[] geomY;
  private final double[] polyLen;
  private final double[] geomCum;
  private final float[] startHeading;
  private final float[] endHeading;
  private final int[] adjOffset;
  private final int[] adjState;
  private final int[] corridorOffset;
  private final int[] corridorEdge;
  private final int componentCount;
  private final double[] componentLength;
  private final SpatialGrid nodeGrid;
  private final SpatialGrid segmentGrid;
  private final LocalProjection projection;
  private final NetworkParameters parameters;
  private final NetworkStats stats;

  NetworkGraph(Assembly a) {
    nodeX = a.nodeX;
    nodeY = a.nodeY;
    nodeDegree = a.nodeDegree;
    nodeStreetDegree = a.nodeStreetDegree;
    nodeDangling = a.nodeDangling;
    nodeRiddenThrough = a.nodeRiddenThrough;
    nodeComponent = a.nodeComponent;
    edgeU = a.edgeU;
    edgeV = a.edgeV;
    edgeLength = a.edgeLength;
    gainUV = a.gainUV;
    lossUV = a.lossUV;
    allowUV = a.allowUV;
    allowVU = a.allowVU;
    support = a.support;
    trackOffset = a.trackOffset;
    trackIds = a.trackIds;
    transitions = java.util.Map.copyOf(a.transitions);
    z = a.z;
    zByType = a.zByType;
    supportByKind = a.supportByKind;
    surface = a.surface;
    surfaceDetail = a.surfaceDetail;
    surfaceSource = a.surfaceSource;
    wayKind = a.wayKind;
    trackType = a.trackType;
    bicycle = a.bicycle;
    foot = a.foot;
    aStarScale = a.aStarScale;
    bridge = a.bridge;
    geomOffset = a.geomOffset;
    geomX = a.geomX;
    geomY = a.geomY;
    int edges = geomOffset.length - 1;
    polyLen = new double[Math.max(0, edges)];
    for (int e = 0; e < polyLen.length; e++) {
      double len = 0;
      for (int i = geomOffset[e] + 1; i < geomOffset[e + 1]; i++) {
        len += Math.hypot(geomX[i] - geomX[i - 1], geomY[i] - geomY[i - 1]);
      }
      polyLen[e] = len;
    }
    geomCum = new double[geomX.length];
    for (int e = 0; e < polyLen.length; e++) {
      Geo.cumulate(geomX, geomY, geomOffset[e], geomOffset[e + 1], geomCum);
    }
    startHeading = a.startHeading;
    endHeading = a.endHeading;
    adjOffset = a.adjOffset;
    adjState = a.adjState;
    corridorOffset = a.corridorOffset;
    corridorEdge = a.corridorEdge;
    componentCount = a.componentCount;
    componentLength = a.componentLength;
    nodeGrid = a.nodeGrid;
    segmentGrid = a.segmentGrid;
    projection = a.projection;
    parameters = a.parameters;
    stats = a.stats;
  }

  // ---- sizes ----------------------------------------------------------------------------------

  public int nodeCount() {
    return nodeX.length;
  }

  public int edgeCount() {
    return edgeU.length;
  }

  public NetworkStats stats() {
    return stats;
  }

  public NetworkParameters parameters() {
    return parameters;
  }

  LocalProjection projection() {
    return projection;
  }

  SpatialGrid nodeGrid() {
    return nodeGrid;
  }

  SpatialGrid segmentGrid() {
    return segmentGrid;
  }

  // ---- nodes ----------------------------------------------------------------------------------

  public double nodeX(int node) {
    return nodeX[node];
  }

  public double nodeY(int node) {
    return nodeY[node];
  }

  public LatLon nodeLatLon(int node) {
    return projection.toLatLon(nodeX[node], nodeY[node]);
  }

  /** Undirected incident edge count in the team graph. */
  public int degree(int node) {
    return nodeDegree[node];
  }

  /** Street-graph degree reported by the producer, diagnostics only (0 for a dangling node). */
  public int streetDegree(int node) {
    return nodeStreetDegree[node];
  }

  /**
   * A node of team degree 2 whose two edges are ridden by a common live track: the team rides
   * through it, whatever the turn drawn there (a mountain hairpin with a side track at its apex).
   */
  public boolean riddenThrough(int node) {
    return nodeRiddenThrough[node];
  }

  public boolean dangling(int node) {
    return nodeDangling[node];
  }

  public int component(int node) {
    return nodeComponent[node];
  }

  public int componentCount() {
    return componentCount;
  }

  /** Sum of the non-bridge edge lengths of a component; 0 for a trivial one. */
  public double componentLength(int component) {
    return componentLength[component];
  }

  /** States leaving {@code node}, as a CSR range {@code [outFrom, outTo)} over {@link #adjState}. */
  public int outFrom(int node) {
    return adjOffset[node];
  }

  public int outTo(int node) {
    return adjOffset[node + 1];
  }

  public int adjState(int i) {
    return adjState[i];
  }

  /** The whole CSR array (not a copy: package-private, never mutated); {@link #outFrom}/{@link #outTo} index into it. */
  int[] adjStates() {
    return adjState;
  }

  // ---- edges and states -----------------------------------------------------------------------

  public int edgeU(int edge) {
    return edgeU[edge];
  }

  public int edgeV(int edge) {
    return edgeV[edge];
  }

  public double length(int edge) {
    return edgeLength[edge];
  }

  public int support(int edge) {
    return support[edge];
  }

  /** Ids of the live tracks that ride the edge, ascending (a copy). */
  public long[] trackIds(int edge) {
    return java.util.Arrays.copyOfRange(trackIds, trackOffset[edge], trackOffset[edge + 1]);
  }

  /** A live track that rode from edge {@code from} into edge {@code to} through {@code node}. */
  record Transition(int node, int from, int to) {}

  /**
   * The passes of live tracks, ascending by (track, rank): {@code ranks[n]} is the position of the
   * step in its track's own ride (steps between two different final edges, consecutive when the
   * track rode them one after the other without a gap).
   */
  record Passes(long[] tracks, int[] ranks) {}

  private static final Passes NO_PASSES = new Passes(new long[0], new int[0]);

  /**
   * The passes of live tracks that rode from edge {@code from} into edge {@code to} through {@code
   * node} (shared arrays: never mutated).
   */
  Passes transitionPasses(int node, int from, int to) {
    Passes t = transitions.get(new Transition(node, from, to));
    return t == null ? NO_PASSES : t;
  }

  /** Familiarity of the edge for a source, 0..1: log1p of the (weighted) track count, normalised. */
  public double z(int edge, ZSource source) {
    return source == ZSource.ALL ? z[edge] : zByType[source.ordinal() - 1][edge];
  }

  /** Number of tracks of {@code kind} that ride the edge. */
  public int supportByKind(int edge, TrackKind kind) {
    return supportByKind[4 * edge + kind.ordinal()];
  }

  /** Surface class code, equal to {@link SurfaceClass#ordinal()}. */
  public byte surface(int edge) {
    return surface[edge];
  }

  public SurfaceClass surfaceClass(int edge) {
    return SurfaceClass.values()[surface[edge]];
  }

  /** 0 = none, then the 13 known details of the contract in {@link NetworkGraphBuilder#DETAILS}. */
  public byte surfaceDetailCode(int edge) {
    return surfaceDetail[edge];
  }

  public @Nullable String surfaceDetail(int edge) {
    int c = surfaceDetail[edge];
    return c == 0 ? null : NetworkGraphBuilder.DETAILS[c - 1];
  }

  public SurfaceSource surfaceSource(int edge) {
    return SurfaceSource.values()[surfaceSource[edge]];
  }

  public WayKind wayKind(int edge) {
    return WayKind.values()[wayKind[edge]];
  }

  public @Nullable OsmTrackType trackType(int edge) {
    int c = trackType[edge];
    return c == 0 ? null : OsmTrackType.values()[c - 1];
  }

  public @Nullable Access bicycle(int edge) {
    int c = bicycle[edge];
    return c == 0 ? null : Access.values()[c - 1];
  }

  public @Nullable Access foot(int edge) {
    int c = foot[edge];
    return c == 0 ? null : Access.values()[c - 1];
  }

  /** Factor of the A* lower bound: projected distance times this never exceeds a path length. */
  public double aStarScale() {
    return aStarScale;
  }

  public boolean isBridge(int edge) {
    return bridge[edge];
  }

  public int tail(int state) {
    return (state & 1) == 0 ? edgeU[state >>> 1] : edgeV[state >>> 1];
  }

  public int head(int state) {
    return (state & 1) == 0 ? edgeV[state >>> 1] : edgeU[state >>> 1];
  }

  /** One-way rule: may the state be ridden. */
  public boolean allowed(int state) {
    return (state & 1) == 0 ? allowUV[state >>> 1] : allowVU[state >>> 1];
  }

  /** Ascent in metres when riding the state. */
  public double gain(int state) {
    return (state & 1) == 0 ? gainUV[state >>> 1] : lossUV[state >>> 1];
  }

  public double loss(int state) {
    return (state & 1) == 0 ? lossUV[state >>> 1] : gainUV[state >>> 1];
  }

  /** Heading in degrees of the first 30–50 m of the state. */
  public double startHeading(int state) {
    return startHeading[state];
  }

  public double endHeading(int state) {
    return endHeading[state];
  }

  /** Edges whose geometry runs alongside this one (dual carriageways, side paths). */
  public int[] corridorNeighbours(int edge) {
    int from = corridorOffset[edge];
    int to = corridorOffset[edge + 1];
    int[] out = new int[to - from];
    System.arraycopy(corridorEdge, from, out, 0, out.length);
    return out;
  }

  // ---- geometry -------------------------------------------------------------------------------

  /** Projected x coordinates of the edge geometry in u→v order (copy). */
  public double[] geometryX(int edge) {
    return java.util.Arrays.copyOfRange(geomX, geomOffset[edge], geomOffset[edge + 1]);
  }

  /** Length of the edge geometry as a polyline, in the projected metres of {@link #geometryX}. */
  public double polylineLength(int edge) {
    return polyLen[edge];
  }

  /** Point at {@code offset} projected metres along the state in travel direction, into {@code out}. */
  public void pointOnState(int state, double offset, double[] out) {
    int e = state >>> 1;
    Geo.pointAlongCum(
        geomX, geomY, geomCum, geomOffset[e], geomOffset[e + 1], (state & 1) == 1, offset, out);
  }

  public double[] geometryY(int edge) {
    return java.util.Arrays.copyOfRange(geomY, geomOffset[edge], geomOffset[edge + 1]);
  }

  /** Geometry of a state in travel direction (allocating: for output and tests). */
  public List<LatLon> geometryLatLon(int state) {
    double[] xs = geometryX(state >>> 1);
    double[] ys = geometryY(state >>> 1);
    List<LatLon> out = new ArrayList<>(xs.length);
    if ((state & 1) == 0) {
      for (int i = 0; i < xs.length; i++) {
        out.add(projection.toLatLon(xs[i], ys[i]));
      }
    } else {
      for (int i = xs.length - 1; i >= 0; i--) {
        out.add(projection.toLatLon(xs[i], ys[i]));
      }
    }
    return out;
  }
}
