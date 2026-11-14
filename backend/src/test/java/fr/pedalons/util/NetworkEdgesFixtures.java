package fr.pedalons.util;

import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.service.route.planner.PolylineCodec;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Hand-made {@link NetworkEdgesDocument}s on a regular grid of streets (docs/LEDGER_*.md API-198,
 * lot 3 plan §5.2): node {@code (x, y)} is {@code z14:x:y}, one kilometre from its neighbours,
 * complete two-way minor roads. A route is a path through the grid, a row, a column, or any walk.
 */
public final class NetworkEdgesFixtures {
  public static final double LAT0 = 47.0;
  public static final double LON0 = -1.5;
  public static final double SPACING_M = 1000;

  private static final double M_PER_DEG = 111_320.0;
  private static final Instant AT = Instant.parse("2026-11-14T08:00:00Z");

  private NetworkEdgesFixtures() {}

  public static double lat(double y) {
    return LAT0 + y * SPACING_M / M_PER_DEG;
  }

  public static double lon(double x) {
    return LON0 + x * SPACING_M / (M_PER_DEG * Math.cos(Math.toRadians(LAT0)));
  }

  /** A document walking the grid nodes {@code xy[i] = {x, y}} in order, one edge per step. */
  public static NetworkEdgesDocument walk(long rev, int[]... xy) {
    List<NetworkEdgesDocument.Node> nodes = new ArrayList<>();
    Map<String, Integer> index = new HashMap<>();
    List<NetworkEdgesDocument.Edge> edges = new ArrayList<>();
    double along = 0;
    for (int i = 0; i + 1 < xy.length; i++) {
      int a = nodeIndex(xy[i], nodes, index);
      int b = nodeIndex(xy[i + 1], nodes, index);
      double len = SPACING_M * Math.hypot(xy[i + 1][0] - xy[i][0], xy[i + 1][1] - xy[i][1]);
      String g =
          PolylineCodec.encode2(
              new double[][] {
                {lon(xy[i][0]), lat(xy[i][1])}, {lon(xy[i + 1][0]), lat(xy[i + 1][1])}
              });
      edges.add(edge(along, along + len, a, b, len, g));
      along += len;
    }
    return new NetworkEdgesDocument(
        NetworkEdgesDocument.VERSION,
        rev,
        AT,
        NetworkEdgesDocument.STATUS_OK,
        "1.7",
        "2026.11.14",
        "full",
        null,
        along,
        List.copyOf(nodes),
        List.copyOf(edges),
        Map.of(),
        along);
  }

  /** Row {@code y}, west to east, over the whole grid of {@code size} nodes a side. */
  public static NetworkEdgesDocument row(long rev, int y, int size) {
    int[][] xy = new int[size][];
    for (int x = 0; x < size; x++) {
      xy[x] = new int[] {x, y};
    }
    return walk(rev, xy);
  }

  /** Column {@code x}, south to north. */
  public static NetworkEdgesDocument column(long rev, int x, int size) {
    int[][] xy = new int[size][];
    for (int y = 0; y < size; y++) {
      xy[y] = new int[] {x, y};
    }
    return walk(rev, xy);
  }

  /** The same document with another revision. */
  public static NetworkEdgesDocument withRev(NetworkEdgesDocument d, long rev) {
    return new NetworkEdgesDocument(
        d.v(),
        rev,
        d.at(),
        d.status(),
        d.api(),
        d.rules(),
        d.profile(),
        d.dv(),
        d.len(),
        d.nodes(),
        d.edges(),
        d.unmatched(),
        d.covered());
  }

  /** The same document with another version of the shape. */
  public static NetworkEdgesDocument withVersion(NetworkEdgesDocument d, int v) {
    return new NetworkEdgesDocument(
        v,
        d.rev(),
        d.at(),
        d.status(),
        d.api(),
        d.rules(),
        d.profile(),
        d.dv(),
        d.len(),
        d.nodes(),
        d.edges(),
        d.unmatched(),
        d.covered());
  }

  /** A complete, two-way minor-road edge from node index {@code fn} to {@code tn}. */
  public static NetworkEdgesDocument.Edge edge(
      double fm, double tm, int fn, int tn, double len, String polyline) {
    return new NetworkEdgesDocument.Edge(
        fm,
        tm,
        fn,
        tn,
        false,
        len,
        len,
        0.0,
        len,
        "both",
        polyline,
        0,
        0,
        0,
        0,
        null,
        "paved",
        "asphalt",
        "tagged",
        "minor_road",
        null,
        null,
        null);
  }

  private static int nodeIndex(
      int[] xy, List<NetworkEdgesDocument.Node> nodes, Map<String, Integer> index) {
    String id = "z14:" + xy[0] + ":" + xy[1];
    Integer known = index.get(id);
    if (known != null) {
      return known;
    }
    nodes.add(new NetworkEdgesDocument.Node(id, lat(xy[1]), lon(xy[0]), 4));
    index.put(id, nodes.size() - 1);
    return nodes.size() - 1;
  }
}
