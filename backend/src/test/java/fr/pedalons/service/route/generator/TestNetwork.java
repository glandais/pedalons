package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * Test DSL: named nodes placed in metres (x east, y north) around a reference point, tracks made of
 * straight or bent edges between them, lengths measured by haversine on the generated geometry.
 */
final class TestNetwork {
  private final LocalProjection projection;
  private final Map<String, double[]> positions = new LinkedHashMap<>();
  private final List<Track> tracks = new ArrayList<>();
  private final Map<String, double[][]> truth = new LinkedHashMap<>();
  private final Map<String, Integer> streetDegrees = new LinkedHashMap<>();

  TestNetwork(double refLat, double refLon) {
    this.projection = new LocalProjection(refLat, refLon);
  }

  TestNetwork node(String name, double x, double y) {
    positions.put(name, new double[] {x, y});
    return this;
  }

  /** A second key whose position is offset from {@code name}: for node-merge tests. */
  TestNetwork alias(String name, String alias, double dx, double dy) {
    double[] p = positions.get(name);
    positions.put(alias, new double[] {p[0] + dx, p[1] + dy});
    return this;
  }

  /** The street-graph degree the producer reports for a node (default 3). */
  TestNetwork streetDegree(String name, int degree) {
    streetDegrees.put(name, degree);
    return this;
  }

  /** The true geometry of the street a to b (bend points as x, y pairs), used by every track. */
  TestNetwork edge(String a, String b, double... bends) {
    double[] pa = positions.get(a);
    double[] pb = positions.get(b);
    double[][] pts = new double[bends.length / 2 + 2][];
    pts[0] = pa;
    for (int i = 0; i + 1 < bends.length; i += 2) {
      pts[i / 2 + 1] = new double[] {bends[i], bends[i + 1]};
    }
    pts[pts.length - 1] = pb;
    truth.put(a + "|" + b, pts);
    return this;
  }

  Track track(long id) {
    return track(id, TrackKind.ROAD);
  }

  Track track(long id, TrackKind kind) {
    Track t = new Track(id, kind);
    tracks.add(t);
    return t;
  }

  /** The true geometry of a to b in metres: declared, or the straight line. */
  double[][] truthOf(String a, String b) {
    double[][] pts = truth.get(a + "|" + b);
    if (pts != null) {
      return pts;
    }
    pts = truth.get(b + "|" + a);
    if (pts != null) {
      double[][] r = new double[pts.length][];
      for (int i = 0; i < pts.length; i++) {
        r[i] = pts[pts.length - 1 - i];
      }
      return r;
    }
    return new double[][] {positions.get(a), positions.get(b)};
  }

  private static double[][] slice(double[][] pts, double fromM, double toM) {
    double[] xs = new double[pts.length];
    double[] ys = new double[pts.length];
    for (int i = 0; i < pts.length; i++) {
      xs[i] = pts[i][0];
      ys[i] = pts[i][1];
    }
    double[][] sl = Geo.slice(xs, ys, fromM, toM);
    double[][] out = new double[sl[0].length][];
    for (int i = 0; i < out.length; i++) {
      out[i] = new double[] {sl[0][i], sl[1][i]};
    }
    return out;
  }

  double xOf(LatLon p) {
    return projection.toX(p.lat(), p.lon());
  }

  double yOf(LatLon p) {
    return projection.toY(p.lat(), p.lon());
  }

  LatLon latLon(double x, double y) {
    return projection.toLatLon(x, y);
  }

  List<TrackInput> inputs() {
    List<TrackInput> out = new ArrayList<>();
    for (Track t : tracks) {
      out.add(new TrackInput(t.id, t.excluded, t.kind, List.copyOf(t.edges)));
    }
    return out;
  }

  NetworkGraph build() {
    return build(NetworkParameters.defaults());
  }

  NetworkGraph build(NetworkParameters p) {
    return NetworkGraphBuilder.build(inputs(), p);
  }

  /** The graph node placed at the named position (within 3 m), or -1. */
  int nodeId(NetworkGraph g, String name) {
    double[] p = positions.get(name);
    for (int i = 0; i < g.nodeCount(); i++) {
      if (Math.hypot(g.nodeX(i) - toGraphX(g, p), g.nodeY(i) - toGraphY(g, p)) < 3) {
        return i;
      }
    }
    return -1;
  }

  /** The state riding from the node at {@code from} to the node at {@code to}, or -1. */
  int state(NetworkGraph g, String from, String to) {
    int a = nodeId(g, from);
    int b = nodeId(g, to);
    if (a < 0 || b < 0) {
      return -1;
    }
    for (int i = g.outFrom(a); i < g.outTo(a); i++) {
      int s = g.adjState(i);
      if (g.head(s) == b) {
        return s;
      }
    }
    return -1;
  }

  int edgeBetween(NetworkGraph g, String a, String b) {
    int s = state(g, a, b);
    return s < 0 ? -1 : s >>> 1;
  }

  /** States of a route through the named nodes, in order. */
  int[] route(NetworkGraph g, String... names) {
    int[] states = new int[names.length - 1];
    for (int i = 0; i < states.length; i++) {
      states[i] = state(g, names[i], names[i + 1]);
      if (states[i] < 0) {
        throw new IllegalArgumentException("no edge " + names[i] + " -> " + names[i + 1]);
      }
    }
    return states;
  }

  private double toGraphX(NetworkGraph g, double[] p) {
    LatLon ll = latLon(p[0], p[1]);
    return g.projection().toX(ll.lat(), ll.lon());
  }

  private double toGraphY(NetworkGraph g, double[] p) {
    LatLon ll = latLon(p[0], p[1]);
    return g.projection().toY(ll.lat(), ll.lon());
  }

  static double haversine(LatLon a, LatLon b) {
    double dLat = Math.toRadians(b.lat() - a.lat());
    double dLon = Math.toRadians(b.lon() - a.lon());
    double h =
        Math.pow(Math.sin(dLat / 2), 2)
            + Math.cos(Math.toRadians(a.lat()))
                * Math.cos(Math.toRadians(b.lat()))
                * Math.pow(Math.sin(dLon / 2), 2);
    return 2 * LocalProjection.EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
  }

  /** A complete observation with the ends of the edge and its geometry as given. */
  static TrackEdge complete(
      NodeRef a, NodeRef b, Oneway oneway, @Nullable EdgeSurface surface, @Nullable WayKind kind) {
    List<LatLon> geometry = List.of(a.position(), b.position());
    double len = haversine(a.position(), b.position());
    return new TrackEdge(
        a, b, false, len, len, 0.0, len, oneway, geometry, 0, 0, surface, kind, null, null, null);
  }

  /** One track under construction; the settings apply to the edges added afterwards. */
  final class Track {
    final long id;
    final TrackKind kind;
    boolean excluded;
    final List<TrackEdge> edges = new ArrayList<>();
    private Oneway oneway = Oneway.BOTH;
    private @Nullable EdgeSurface surface;
    private @Nullable WayKind wayKind;
    private @Nullable OsmTrackType trackType;
    private @Nullable Access bicycle;
    private boolean partial;
    private double gain;
    private double loss;

    Track(long id, TrackKind kind) {
      this.id = id;
      this.kind = kind;
    }

    Track excluded() {
      this.excluded = true;
      return this;
    }

    Track oneway(Oneway o) {
      this.oneway = o;
      return this;
    }

    /** Shorthand: true = unpaved gravel, false = paved asphalt, null = no surface. */
    Track unpaved(@Nullable Boolean u) {
      this.surface =
          u == null
              ? null
              : u
                  ? new EdgeSurface(SurfaceClass.UNPAVED, "gravel", SurfaceSource.TAGGED)
                  : new EdgeSurface(SurfaceClass.PAVED, "asphalt", SurfaceSource.TAGGED);
      return this;
    }

    Track surface(SurfaceClass c, @Nullable String detail, SurfaceSource source) {
      this.surface = new EdgeSurface(c, detail, source);
      return this;
    }

    Track wayKind(@Nullable WayKind k) {
      this.wayKind = k;
      return this;
    }

    Track trackType(@Nullable OsmTrackType t) {
      this.trackType = t;
      return this;
    }

    Track bicycle(@Nullable Access a) {
      this.bicycle = a;
      return this;
    }

    /** Marks the following complete edges as partial without offsets (legacy shape). */
    Track partial(boolean p) {
      this.partial = p;
      return this;
    }

    Track gain(double gain, double loss) {
      this.gain = gain;
      this.loss = loss;
      return this;
    }

    /** Straight (or declared) complete edges between consecutive named nodes. */
    Track path(String... names) {
      for (int i = 0; i + 1 < names.length; i++) {
        via(names[i], names[i + 1]);
      }
      return this;
    }

    /** One complete edge from {@code a} to {@code b}, through bend points given as x, y pairs. */
    Track via(String a, String b, double... bends) {
      List<LatLon> geometry = new ArrayList<>();
      if (bends.length > 0) {
        double[] pa = positions.get(a);
        double[] pb = positions.get(b);
        geometry.add(latLon(pa[0], pa[1]));
        for (int i = 0; i + 1 < bends.length; i += 2) {
          geometry.add(latLon(bends[i], bends[i + 1]));
        }
        geometry.add(latLon(pb[0], pb[1]));
      } else {
        for (double[] q : truthOf(a, b)) {
          geometry.add(latLon(q[0], q[1]));
        }
      }
      edges.add(edge(ref(a), ref(b), geometry, partial, null, null));
      return this;
    }

    private double truthLength(String a, String b) {
      double len = 0;
      double[][] pts = truthOf(a, b);
      for (int i = 1; i < pts.length; i++) {
        len += haversine(latLon(pts[i - 1][0], pts[i - 1][1]), latLon(pts[i][0], pts[i][1]));
      }
      return len;
    }

    private List<LatLon> sliced(String a, String b, double fromM, double toM) {
      double[][] pts = truthOf(a, b);
      double projected = 0;
      for (int i = 1; i < pts.length; i++) {
        projected += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
      }
      double scale = projected / truthLength(a, b);
      List<LatLon> out = new ArrayList<>();
      for (double[] q : slice(pts, fromM * scale, toM * scale)) {
        out.add(latLon(q[0], q[1]));
      }
      return out;
    }

    /** Starts mid-edge at {@code offsetM} from {@code a} and rides to {@code b} (partial). */
    Track startAt(String a, String b, double offsetM) {
      double len = truthLength(a, b);
      edges.add(edge(ref(a), ref(b), sliced(a, b, offsetM, len), true, offsetM, len));
      return this;
    }

    /** Rides from {@code a} and stops mid-edge at {@code offsetM} (partial). */
    Track endAt(String a, String b, double offsetM) {
      edges.add(edge(ref(a), ref(b), sliced(a, b, 0, offsetM), true, 0.0, offsetM));
      return this;
    }

    /** Rides from {@code a} to {@code offsetM}, turns round, and rides back to {@code a}. */
    Track uTurnAt(String a, String b, double offsetM) {
      double len = truthLength(a, b);
      endAt(a, b, offsetM);
      List<LatLon> back = new ArrayList<>(sliced(a, b, 0, offsetM));
      java.util.Collections.reverse(back);
      edges.add(edge(ref(b), ref(a), back, true, len - offsetM, len));
      return this;
    }

    /** An edge from {@code a} leaving at {@code bearingDeg}, whose far end is unknown. */
    Track stubFrom(String a, double lengthM, double bearingDeg) {
      double[] pa = positions.get(a);
      double x = pa[0] + lengthM * Math.sin(Math.toRadians(bearingDeg));
      double y = pa[1] + lengthM * Math.cos(Math.toRadians(bearingDeg));
      List<LatLon> geometry = List.of(latLon(pa[0], pa[1]), latLon(x, y));
      edges.add(edge(ref(a), null, geometry, true, 0.0, lengthM));
      return this;
    }

    /** An edge arriving at {@code a} from an unknown start, {@code lengthM} long. */
    Track stubTo(String a, double lengthM, double bearingDeg) {
      double[] pa = positions.get(a);
      double x = pa[0] + lengthM * Math.sin(Math.toRadians(bearingDeg));
      double y = pa[1] + lengthM * Math.cos(Math.toRadians(bearingDeg));
      List<LatLon> geometry = List.of(latLon(x, y), latLon(pa[0], pa[1]));
      edges.add(edge(null, ref(a), geometry, true, null, null));
      return this;
    }

    /** Appends a hand-made input edge. */
    Track raw(TrackEdge e) {
      edges.add(e);
      return this;
    }

    NodeRef ref(String name) {
      double[] p = positions.get(name);
      return new NodeRef(name, latLon(p[0], p[1]), streetDegrees.getOrDefault(name, 3));
    }

    private TrackEdge edge(
        @Nullable NodeRef from,
        @Nullable NodeRef to,
        List<LatLon> geometry,
        boolean partial,
        @Nullable Double fromOffset,
        @Nullable Double toOffset) {
      double length = 0;
      for (int i = 1; i < geometry.size(); i++) {
        length += haversine(geometry.get(i - 1), geometry.get(i));
      }
      boolean both = from != null && to != null;
      Double complete = null;
      if (both) {
        complete =
            partial && fromOffset != null && toOffset != null ? completeLength(from, to) : length;
      }
      return new TrackEdge(
          from,
          to,
          partial || !both,
          complete,
          length,
          from == null ? null : fromOffset,
          from == null ? null : toOffset,
          oneway,
          geometry,
          gain,
          loss,
          surface,
          wayKind,
          trackType,
          bicycle,
          null);
    }

    private double completeLength(NodeRef from, NodeRef to) {
      return truthLength(from.key(), to.key());
    }
  }
}
