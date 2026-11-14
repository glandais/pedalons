package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Arrays;
import java.util.BitSet;
import java.util.List;
import java.util.Random;
import org.junit.jupiter.api.Test;

/** The search-side turn rule, against the checker's definition (design §12.4). */
class SearchTurnsTest {
  private static final double MAX = 150;
  private static final GeneratorParameters P = GeneratorParameters.defaults();

  private static EdgeDijkstra.Request lengths(
      QueryGraph qg,
      int[] sources,
      java.util.function.IntPredicate target,
      int aStarNode,
      double factor) {
    double[] w = new double[qg.stateCount()];
    for (int s = 0; s < w.length; s++) {
      w[s] = qg.length(s >>> 1);
    }
    double[] costs = new double[sources.length];
    double[] metres = new double[sources.length];
    for (int i = 0; i < sources.length; i++) {
      costs[i] = w[sources[i]];
      metres[i] = qg.length(sources[i] >>> 1);
    }
    return new EdgeDijkstra.Request(
        false,
        sources,
        costs,
        metres,
        target,
        w,
        new BitSet(),
        null,
        Double.POSITIVE_INFINITY,
        aStarNode,
        factor);
  }

  /** Up the P-Q1 carriageway, a 15 m connector, and down the Q2-R carriageway: a hidden U-turn. */
  private static TestNetwork connectorHairpin() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("P", 0, -2000)
            .node("Q1", 0, 0)
            .node("Q2", 15, 0)
            .node("R", 15, -2000);
    n.track(1).oneway(Oneway.FORWARD).path("P", "Q1");
    n.track(2).path("Q1", "Q2");
    n.track(3).oneway(Oneway.FORWARD).path("Q2", "R");
    return n;
  }

  @Test
  void aConnectorBetweenTwoDegreeTwoNodesIsNotAWayToTurnBack() {
    TestNetwork n = connectorHairpin();
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int p = n.nodeId(g, "P");
    int r = n.nodeId(g, "R");
    int[] sources = {n.state(g, "P", "Q1")};
    EdgeDijkstra.Result res =
        new EdgeDijkstra(qg, MAX).search(lengths(qg, sources, s -> qg.head(s) == r, -1, 0));
    assertFalse(res.found(), "P to R would be a U-turn over 15 m");
    // and the checker agrees on the hand-made route
    int[] route = n.route(g, "P", "Q1", "Q2", "R");
    assertFalse(SearchTurns.pathOk(qg, route, 0, route.length, MAX));
    GuaranteeReport report = RouteGuarantees.check(qg, p, r, 4015, route, P);
    assertTrue(report.violations().contains(Violation.SHARP_TURN), report.violations().toString());
  }

  @Test
  void aShortConnectorIsFineWhenTheTurnIsOnlyNinetyDegrees() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("P", 0, -2000)
            .node("Q1", 0, 0)
            .node("Q2", 15, 0)
            .node("R", 2015, 0);
    n.track(1).path("P", "Q1");
    n.track(2).path("Q1", "Q2");
    n.track(3).path("Q2", "R");
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int[] route = n.route(g, "P", "Q1", "Q2", "R");
    assertTrue(SearchTurns.pathOk(qg, route, 0, route.length, MAX));
  }

  @Test
  void whateverTheSearchAcceptsTheCheckerDoesNotCallASharpTurnOnChainsOfLongEdges() {
    List<TrackInput> tracks = GridNetwork.tracks(8, 8, 900, 250, 0, 0, 45, 5, 3);
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    QueryGraph qg = QueryGraph.of(g);
    Random rnd = new Random(11);
    int accepted = 0;
    for (int chain = 0; chain < 500; chain++) {
      int s0 = rnd.nextInt(qg.stateCount());
      if (!qg.allowed(s0)) {
        continue;
      }
      int[] pred = new int[qg.stateCount()];
      Arrays.fill(pred, -1);
      int[] states = new int[8];
      states[0] = s0;
      int len = 1;
      boolean ok = true;
      for (int i = 1; i < states.length; i++) {
        int node = qg.head(states[i - 1]);
        int n = qg.outCount(node);
        int pick = qg.outState(node, rnd.nextInt(n));
        if (!qg.allowed(pick) || !SearchTurns.ok(qg, pred, states[i - 1], pick, MAX)) {
          ok = false;
          break;
        }
        pred[pick] = states[i - 1];
        states[i] = pick;
        len++;
      }
      if (!ok || len < 3) {
        continue;
      }
      accepted++;
      GuaranteeReport r =
          RouteGuarantees.check(qg, qg.tail(states[0]), qg.head(states[len - 1]), 1, states, P);
      assertFalse(r.violations().contains(Violation.SHARP_TURN), "chain " + chain);
      assertFalse(r.violations().contains(Violation.U_TURN), "chain " + chain);
    }
    assertTrue(accepted > 20, "only " + accepted + " chains accepted");
  }

  @Test
  void aStarAgreesWithDijkstraOnAGraphSpanningSixDegreesOfLatitude() {
    List<TrackInput> tracks = GridNetwork.tracks(12, 4, 60_000, 0, 0, 0, 47, 5, 1);
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    QueryGraph qg = QueryGraph.of(g);
    EdgeDijkstra dijkstra = new EdgeDijkstra(qg, MAX);
    double factor = g.aStarScale() * 1.0; // metres as weights: the lower bound is 1 per metre
    Random rnd = new Random(5);
    int compared = 0;
    for (int q = 0; q < 200; q++) {
      int from = rnd.nextInt(qg.nodeCount());
      int to = rnd.nextInt(qg.nodeCount());
      if (from == to) {
        continue;
      }
      int[] sources = new int[qg.outCount(from)];
      for (int i = 0; i < sources.length; i++) {
        sources[i] = qg.outState(from, i);
      }
      final int target = to;
      EdgeDijkstra.Result plain =
          dijkstra.search(lengths(qg, sources, s -> qg.head(s) == target, -1, 0));
      EdgeDijkstra.Result astar =
          dijkstra.search(lengths(qg, sources, s -> qg.head(s) == target, target, factor));
      assertEquals(plain.found(), astar.found(), "query " + q);
      if (plain.found()) {
        assertEquals(plain.targetCost(), astar.targetCost(), 1e-6, "query " + q);
        compared++;
      }
    }
    assertTrue(compared > 100);
  }
}
