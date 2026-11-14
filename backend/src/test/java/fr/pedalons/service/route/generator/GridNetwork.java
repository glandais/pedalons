package fr.pedalons.service.route.generator;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/** Synthetic grid of tracks: one track per row and per column, for algorithm and perf tests. */
final class GridNetwork {
  private GridNetwork() {}

  /**
   * @param jitterM node displacement, uniform in ±jitterM on each axis
   * @param oneWayShare share of edges ridden as one-way (observed in the sweep direction)
   * @param hotRowEvery when positive, every n-th row is ridden by 40 extra tracks (support 41)
   */
  static List<TrackInput> tracks(
      int rows,
      int cols,
      double spacingM,
      double jitterM,
      double oneWayShare,
      int hotRowEvery,
      double refLat,
      double refLon,
      long seed) {
    Random rnd = new Random(seed);
    LocalProjection proj = new LocalProjection(refLat, refLon);
    double[][][] pos = new double[rows][cols][2];
    NodeRef[][] ref = new NodeRef[rows][cols];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double x = (c - (cols - 1) / 2.0) * spacingM + (rnd.nextDouble() * 2 - 1) * jitterM;
        double y = (r - (rows - 1) / 2.0) * spacingM + (rnd.nextDouble() * 2 - 1) * jitterM;
        pos[r][c] = new double[] {x, y};
        ref[r][c] = new NodeRef(r + "_" + c, proj.toLatLon(x, y), 4);
      }
    }
    List<TrackInput> out = new ArrayList<>();
    long id = 1;
    for (int r = 0; r < rows; r++) {
      List<TrackEdge> edges = new ArrayList<>();
      for (int c = 0; c + 1 < cols; c++) {
        edges.add(edge(ref[r][c], ref[r][c + 1], rnd.nextDouble() < oneWayShare));
      }
      out.add(new TrackInput(id++, false, TrackKind.ROAD, edges));
      if (hotRowEvery > 0 && r % hotRowEvery == 0) {
        for (int k = 0; k < 40; k++) {
          out.add(new TrackInput(id++, false, TrackKind.ROAD, edges));
        }
      }
    }
    for (int c = 0; c < cols; c++) {
      List<TrackEdge> edges = new ArrayList<>();
      for (int r = 0; r + 1 < rows; r++) {
        edges.add(edge(ref[r][c], ref[r + 1][c], rnd.nextDouble() < oneWayShare));
      }
      out.add(new TrackInput(id++, false, TrackKind.ROAD, edges));
    }
    return out;
  }

  private static TrackEdge edge(NodeRef a, NodeRef b, boolean oneway) {
    return TestNetwork.complete(a, b, oneway ? Oneway.FORWARD : Oneway.BOTH, null, null);
  }
}
