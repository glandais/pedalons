package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Arrays;
import java.util.BitSet;
import java.util.Random;
import java.util.function.IntPredicate;
import org.junit.jupiter.api.Test;

class EdgeDijkstraTest {
  private static final double MAX_TURN = 150;

  private static double[] lengthWeights(QueryGraph qg) {
    double[] w = new double[qg.stateCount()];
    for (int s = 0; s < w.length; s++) {
      w[s] = qg.length(s >>> 1);
    }
    return w;
  }

  private static EdgeDijkstra.Request request(
      QueryGraph qg,
      int[] sources,
      IntPredicate target,
      double[] w,
      BitSet banned,
      double[] penalty,
      boolean backward) {
    double[] costs = new double[sources.length];
    double[] metres = new double[sources.length];
    for (int i = 0; i < sources.length; i++) {
      costs[i] = w[sources[i]];
      metres[i] = qg.length(sources[i] >>> 1);
    }
    return new EdgeDijkstra.Request(
        backward,
        sources,
        costs,
        metres,
        target,
        w,
        banned,
        penalty,
        Double.POSITIVE_INFINITY,
        -1,
        0);
  }

  private static int[] statesLeaving(QueryGraph qg, int node) {
    int[] s = new int[qg.outCount(node)];
    for (int i = 0; i < s.length; i++) {
      s[i] = qg.outState(node, i);
    }
    return s;
  }

  private static EdgeDijkstra.Result shortest(
      QueryGraph qg, int from, int toNode, BitSet banned, double[] penalty) {
    double[] w = lengthWeights(qg);
    return new EdgeDijkstra(qg, MAX_TURN)
        .search(
            request(
                qg, statesLeaving(qg, from), s -> qg.head(s) == toNode, w, banned, penalty, false));
  }

  /** S -> J -> T where T leaves J with the given bearing; the long way round goes through K. */
  private static TestNetwork yJunction(double outBearingDeg) {
    double tx = 1000 * Math.sin(Math.toRadians(outBearingDeg));
    double ty = 1000 * Math.cos(Math.toRadians(outBearingDeg));
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("S", -1000, 0)
            .node("J", 0, 0)
            .node("T", tx, ty)
            .node("K", 1000, 0)
            .node("M", 0, -2000);
    n.track(1).path("S", "J", "T");
    n.track(2).path("J", "K");
    // the long way bends at M: the turn rule now applies at every real node, a hairpin at K would
    // be refused too (design §12.4)
    n.track(3).path("K", "M", "T");
    n.track(4).path("K", "M", "T");
    return n;
  }

  @Test
  void aSharpTurnForcesTheLongerLegalWay() {
    TestNetwork n = yJunction(250); // straight on is a 160 degree turn
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    EdgeDijkstra.Result r = shortest(qg, n.nodeId(g, "S"), n.nodeId(g, "T"), null, null);
    assertTrue(r.found());
    assertEquals(4, r.path().length); // S-J, J-K, K-M, M-T
    assertEquals(n.edgeBetween(g, "J", "K"), r.path()[1] >>> 1);
  }

  @Test
  void aWideEnoughTurnIsTakenDirectly() {
    TestNetwork n = yJunction(230); // 140 degrees
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    EdgeDijkstra.Result r = shortest(qg, n.nodeId(g, "S"), n.nodeId(g, "T"), null, null);
    assertTrue(r.found());
    assertEquals(2, r.path().length);
    assertEquals(1000 + 1000, r.targetCost(), 5);
  }

  @Test
  void thereIsNoUTurnAtADeadEnd() {
    TestNetwork n = new TestNetwork(45, 5).node("P", 0, 0).node("R", 2000, 0);
    n.track(1).path("P", "R");
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int p = n.nodeId(g, "P");
    int r = n.nodeId(g, "R");
    // from P towards R, then back to P would need a reversal at R
    int[] sources = {n.state(g, "P", "R")};
    EdgeDijkstra.Result result =
        new EdgeDijkstra(qg, MAX_TURN)
            .search(
                request(qg, sources, s -> qg.head(s) == p, lengthWeights(qg), null, null, false));
    assertFalse(result.found());
    // while reaching R is fine
    EdgeDijkstra.Result ok =
        new EdgeDijkstra(qg, MAX_TURN)
            .search(
                request(qg, sources, s -> qg.head(s) == r, lengthWeights(qg), null, null, false));
    assertTrue(ok.found());
  }

  private static TestNetwork oneWaySquare() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("A", 0, 0)
            .node("B", 1000, 0)
            .node("C", 1000, 1000)
            .node("D", 0, 1000);
    n.track(1).oneway(Oneway.FORWARD).path("A", "B");
    for (int i = 0; i < 2; i++) {
      n.track(10 + i).path("B", "C");
    }
    for (int i = 0; i < 3; i++) {
      n.track(20 + i).path("C", "D");
    }
    for (int i = 0; i < 4; i++) {
      n.track(30 + i).path("D", "A");
    }
    return n;
  }

  @Test
  void theShortestPathRespectsOneWays() {
    TestNetwork n = oneWaySquare();
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int a = n.nodeId(g, "A");
    int b = n.nodeId(g, "B");
    EdgeDijkstra.Result forward = shortest(qg, a, b, null, null);
    assertEquals(1000, forward.targetCost(), 5);
    EdgeDijkstra.Result back = shortest(qg, b, a, null, null);
    assertTrue(back.found());
    assertEquals(3000, back.targetCost(), 15);
    assertEquals(3, back.path().length);
  }

  private static TestNetwork asymmetricSquare() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("A", 0, 0)
            .node("B", 1000, 0)
            .node("C", 1000, 1000)
            .node("D", 0, 1200);
    n.track(1).path("A", "B");
    for (int i = 0; i < 2; i++) {
      n.track(10 + i).path("B", "C");
    }
    for (int i = 0; i < 3; i++) {
      n.track(20 + i).path("C", "D");
    }
    for (int i = 0; i < 4; i++) {
      n.track(30 + i).path("D", "A");
    }
    return n;
  }

  @Test
  void bannedEdgesAndNodePenaltiesChangeThePath() {
    TestNetwork n = asymmetricSquare();
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int a = n.nodeId(g, "A");
    int c = n.nodeId(g, "C");
    int viaB = n.state(g, "A", "B");

    EdgeDijkstra.Result plain = shortest(qg, a, c, null, null);
    assertEquals(viaB, plain.path()[0]);

    BitSet banned = new BitSet();
    banned.set(n.edgeBetween(g, "A", "B"));
    EdgeDijkstra.Result bannedResult = shortest(qg, a, c, banned, null);
    assertEquals(n.state(g, "A", "D"), bannedResult.path()[0]);

    double[] penalty = new double[qg.nodeCount()];
    penalty[n.nodeId(g, "B")] = 10_000;
    EdgeDijkstra.Result penalised = shortest(qg, a, c, null, penalty);
    assertEquals(n.state(g, "A", "D"), penalised.path()[0]);
  }

  private static NetworkGraph randomGrid(long seed, int size) {
    return NetworkGraphBuilder.build(
        GridNetwork.tracks(size, size, 500, 120, 0.15, 0, 45, 5, seed),
        NetworkParameters.defaults());
  }

  @Test
  void backwardSearchGivesTheCostsOfTheForwardOne() {
    NetworkGraph g = randomGrid(7, 6);
    QueryGraph qg = QueryGraph.of(g);
    double[] w = lengthWeights(qg);
    EdgeDijkstra fwd = new EdgeDijkstra(qg, MAX_TURN);
    EdgeDijkstra bwd = new EdgeDijkstra(qg, MAX_TURN);
    Random rnd = new Random(42);
    int compared = 0;
    for (int trial = 0; trial < 30; trial++) {
      int s0 = rnd.nextInt(qg.stateCount());
      int target = rnd.nextInt(qg.nodeCount());
      if (!qg.allowed(s0)) {
        continue;
      }
      EdgeDijkstra.Tree f =
          fwd.search(
                  new EdgeDijkstra.Request(
                      false,
                      new int[] {s0},
                      new double[] {w[s0]},
                      new double[] {qg.length(s0 >>> 1)},
                      null,
                      w,
                      null,
                      null,
                      Double.POSITIVE_INFINITY,
                      -1,
                      0))
              .tree();
      double best = Double.POSITIVE_INFINITY;
      for (int s = 0; s < qg.stateCount(); s++) {
        if (qg.head(s) == target && f.reached(s)) {
          best = Math.min(best, f.cost[s]);
        }
      }
      int[] arriving =
          java.util.stream.IntStream.range(0, qg.stateCount())
              .filter(s -> qg.head(s) == target && qg.allowed(s))
              .toArray();
      double[] costs = Arrays.stream(arriving).mapToDouble(s -> w[s]).toArray();
      double[] metres = Arrays.stream(arriving).mapToDouble(s -> qg.length(s >>> 1)).toArray();
      EdgeDijkstra.Tree b =
          bwd.search(
                  new EdgeDijkstra.Request(
                      true,
                      arriving,
                      costs,
                      metres,
                      null,
                      w,
                      null,
                      null,
                      Double.POSITIVE_INFINITY,
                      -1,
                      0))
              .tree();
      double backward = b.cost[s0];
      if (Double.isInfinite(best)) {
        assertTrue(Double.isInfinite(backward), "trial " + trial);
      } else {
        assertEquals(best, backward, 1e-6, "trial " + trial);
        compared++;
      }
    }
    assertTrue(compared > 5);
  }

  @Test
  void aStarFindsTheSameCostAsDijkstra() {
    NetworkGraph g = randomGrid(11, 8);
    QueryGraph qg = QueryGraph.of(g);
    double[] w = lengthWeights(qg);
    double factor = 0.97 * EdgeDijkstra.minWeightPerMetre(qg, w);
    EdgeDijkstra plain = new EdgeDijkstra(qg, MAX_TURN);
    EdgeDijkstra astar = new EdgeDijkstra(qg, MAX_TURN);
    Random rnd = new Random(5);
    int found = 0;
    for (int trial = 0; trial < 200; trial++) {
      int from = rnd.nextInt(qg.nodeCount());
      int to = rnd.nextInt(qg.nodeCount());
      if (from == to) {
        continue;
      }
      int[] sources = statesLeaving(qg, from);
      EdgeDijkstra.Result a =
          plain.search(request(qg, sources, s -> qg.head(s) == to, w, null, null, false));
      double[] costs = Arrays.stream(sources).mapToDouble(s -> w[s]).toArray();
      double[] metres = Arrays.stream(sources).mapToDouble(s -> qg.length(s >>> 1)).toArray();
      EdgeDijkstra.Result b =
          astar.search(
              new EdgeDijkstra.Request(
                  false,
                  sources,
                  costs,
                  metres,
                  s -> qg.head(s) == to,
                  w,
                  null,
                  null,
                  Double.POSITIVE_INFINITY,
                  to,
                  factor));
      assertEquals(a.found(), b.found(), "trial " + trial);
      if (a.found()) {
        assertEquals(a.targetCost(), b.targetCost(), 1e-6, "trial " + trial);
        found++;
      }
    }
    assertTrue(found > 100);
  }
}
