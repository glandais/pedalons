package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Random road networks for the property tests: a jittered grid of 8 to 14 nodes a side at about
 * 1 km, a quarter of the edges removed, a tenth of the rest one-way, supports from 1 to 30, 5 %
 * unpaved, and a few stubs whose far end is unknown. Each edge is ridden by {@code support} tracks
 * of one edge each, which keeps the supports exact.
 */
final class RandomNetworks {
  private RandomNetworks() {}

  /** The tracks, and the half-width of the area they cover (metres, around the reference). */
  record Generated(List<TrackInput> tracks, double halfWidthM, double halfHeightM) {}

  static Generated generate(Random r) {
    int rows = 8 + r.nextInt(7);
    int cols = 8 + r.nextInt(7);
    LocalProjection proj = new LocalProjection(45, 5);
    double[][][] pos = new double[rows][cols][2];
    NodeRef[][] ref = new NodeRef[rows][cols];
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        double x = (j - (cols - 1) / 2.0) * 1000 + (r.nextDouble() * 2 - 1) * 150;
        double y = (i - (rows - 1) / 2.0) * 1000 + (r.nextDouble() * 2 - 1) * 150;
        pos[i][j] = new double[] {x, y};
        ref[i][j] = new NodeRef(i + "_" + j, proj.toLatLon(x, y), 4);
      }
    }
    List<TrackInput> out = new ArrayList<>();
    long id = 1;
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (j + 1 < cols && r.nextDouble() < 0.75) {
          id = ride(out, id, r, ref[i][j], ref[i][j + 1]);
        }
        if (i + 1 < rows && r.nextDouble() < 0.75) {
          id = ride(out, id, r, ref[i][j], ref[i + 1][j]);
        }
      }
    }
    int stubs = 1 + r.nextInt(4);
    for (int k = 0; k < stubs; k++) {
      int i = r.nextInt(rows);
      int j = r.nextInt(cols);
      double bearing = Math.toRadians(r.nextInt(360));
      double x = pos[i][j][0] + 300 * Math.sin(bearing);
      double y = pos[i][j][1] + 300 * Math.cos(bearing);
      List<LatLon> geometry = List.of(ref[i][j].position(), proj.toLatLon(x, y));
      TrackEdge stub =
          new TrackEdge(
              ref[i][j],
              null,
              true,
              null,
              300,
              0.0,
              300.0,
              Oneway.BOTH,
              geometry,
              0,
              0,
              null,
              null,
              null,
              null,
              null);
      out.add(new TrackInput(id++, false, TrackKind.ROAD, List.of(stub)));
    }
    return new Generated(out, (cols - 1) / 2.0 * 1000, (rows - 1) / 2.0 * 1000);
  }

  private static long ride(List<TrackInput> out, long id, Random r, NodeRef a, NodeRef b) {
    boolean oneWay = r.nextDouble() < 0.10;
    boolean reversed = r.nextBoolean();
    boolean unpaved = r.nextDouble() < 0.05;
    int support = 1 + r.nextInt(30);
    NodeRef from = oneWay && reversed ? b : a;
    NodeRef to = oneWay && reversed ? a : b;
    for (int k = 0; k < support; k++) {
      boolean flip = !oneWay && r.nextBoolean();
      NodeRef f = flip ? to : from;
      NodeRef t = flip ? from : to;
      TrackEdge edge =
          TestNetwork.complete(
              f,
              t,
              oneWay ? Oneway.FORWARD : Oneway.BOTH,
              unpaved
                  ? new EdgeSurface(SurfaceClass.UNPAVED, "gravel", SurfaceSource.TAGGED)
                  : null,
              null);
      out.add(new TrackInput(id++, false, TrackKind.ROAD, List.of(edge)));
    }
    return id;
  }
}
