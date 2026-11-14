package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class EdgeDisjointPathsTest {
  private static final double MAX_TURN = 150;

  private static double[] lengthWeights(QueryGraph qg) {
    double[] w = new double[qg.stateCount()];
    for (int s = 0; s < w.length; s++) {
      w[s] = qg.length(s >>> 1);
    }
    return w;
  }

  private static void assertContinuous(QueryGraph qg, int[] core) {
    for (int i = 0; i + 1 < core.length; i++) {
      assertEquals(qg.head(core[i]), qg.tail(core[i + 1]), "gap at " + i);
    }
  }

  private static double length(QueryGraph qg, int[] core) {
    double sum = 0;
    for (int s : core) {
      sum += qg.length(s >>> 1);
    }
    return sum;
  }

  /** Repeats a path as several tracks so that its edges get a given support. */
  private static void support(TestNetwork n, long firstId, int times, String... path) {
    for (int i = 0; i < times; i++) {
      n.track(firstId + i).path(path);
    }
  }

  /**
   * The classic Suurballe trap: the shortest T-S path uses the rung a-b and leaves no second
   * disjoint path; the only disjoint pair goes around through the two long edges.
   */
  private static TestNetwork trap() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("T", 0, 0)
            .node("a", 1000, 500)
            .node("b", 1000, -500)
            .node("S", 2000, 0);
    support(n, 1, 2, "T", "a");
    n.track(10).path("a", "b");
    n.track(11).via("a", "S", 1500, 3000);
    n.track(12).via("T", "b", 500, -3000);
    support(n, 20, 2, "b", "S");
    return n;
  }

  @Test
  void theSuurballeTrapIsSolvedByTheOptimalDisjointPair() {
    TestNetwork n = trap();
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int s = n.nodeId(g, "S");
    int t = n.nodeId(g, "T");
    EdgeDisjointPaths solver = new EdgeDisjointPaths(qg, MAX_TURN);
    EdgeDisjointPaths.Solution sol =
        solver.solve(t, s, s, new int[0], new int[0], lengthWeights(qg), null);
    assertNotNull(sol);
    assertFalse(sol.fallback());
    int[] core = sol.core();
    assertEquals(4, core.length);
    assertContinuous(qg, core);
    assertEquals(s, qg.tail(core[0]));
    assertEquals(s, qg.head(core[3]));
    assertEquals(t, qg.head(core[1]));
    int rung = n.edgeBetween(g, "a", "b");
    Set<Integer> edges = new HashSet<>();
    for (int st : core) {
      assertTrue(st >>> 1 != rung);
      assertTrue(edges.add(st >>> 1));
    }
    // hand computed: 2 * (1118.03 + 5590.9)
    assertEquals(13417.9, length(qg, core), 25);
  }

  @Test
  void aVirtualSinkLetsOnePathEndAtEachAnchor() {
    TestNetwork n = new TestNetwork(45, 5).node("S", -3000, 0).node("T", 0, 0).node("E", 3000, 0);
    support(n, 1, 2, "S", "T");
    n.track(5).path("T", "E");
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int s = n.nodeId(g, "S");
    int e = n.nodeId(g, "E");
    int t = n.nodeId(g, "T");
    EdgeDisjointPaths.Solution sol =
        new EdgeDisjointPaths(qg, MAX_TURN)
            .solve(t, s, e, new int[0], new int[0], lengthWeights(qg), null);
    assertNotNull(sol);
    int[] core = sol.core();
    assertEquals(2, core.length);
    assertEquals(s, qg.tail(core[0]));
    assertEquals(t, qg.head(core[0]));
    assertEquals(e, qg.head(core[1]));
    assertEquals(6000, length(qg, core), 10);
  }

  private static TestNetwork squareWithBridgedTriangle() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("A", 0, 0)
            .node("B", 2000, 0)
            .node("C", 2000, 2000)
            .node("D", 0, 2000)
            .node("X", -2000, 0)
            .node("U", -3000, -800)
            .node("V", -3000, 800);
    support(n, 1, 1, "A", "B");
    support(n, 10, 2, "B", "C");
    support(n, 20, 3, "C", "D");
    support(n, 30, 4, "D", "A");
    support(n, 40, 1, "A", "X");
    support(n, 50, 1, "X", "U");
    support(n, 60, 2, "U", "V");
    support(n, 70, 3, "V", "X");
    return n;
  }

  @Test
  void aTurningPointBeyondABridgeIsInfeasible() {
    TestNetwork n = squareWithBridgedTriangle();
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int a = n.nodeId(g, "A");
    EdgeDisjointPaths solver = new EdgeDisjointPaths(qg, MAX_TURN);
    double[] w = lengthWeights(qg);
    assertNull(solver.solve(n.nodeId(g, "U"), a, a, new int[0], new int[0], w, null));
    assertEquals(1, solver.infeasible);

    EdgeDisjointPaths.Solution ok =
        solver.solve(n.nodeId(g, "C"), a, a, new int[0], new int[0], w, null);
    assertNotNull(ok);
    assertEquals(4, ok.core().length);
    assertContinuous(qg, ok.core());
    assertEquals(a, qg.tail(ok.core()[0]));
    assertEquals(a, qg.head(ok.core()[3]));
  }

  @Test
  void aOnewayOnTheSideOfTheStartIsCaughtAndTheFallbackFindsALegalPair() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("T", 0, 0)
            .node("X", -1500, 300)
            .node("P", -3000, 0)
            .node("Q", 3000, 0);
    n.track(1).oneway(Oneway.FORWARD).path("T", "X");
    support(n, 10, 2, "X", "P");
    n.track(20).via("T", "P", -1500, -2500);
    n.track(30).path("T", "Q");
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int p = n.nodeId(g, "P");
    int q = n.nodeId(g, "Q");
    int t = n.nodeId(g, "T");
    EdgeDisjointPaths solver = new EdgeDisjointPaths(qg, MAX_TURN);
    EdgeDisjointPaths.Solution sol =
        solver.solve(t, p, q, new int[0], new int[0], lengthWeights(qg), null);
    assertNotNull(sol);
    assertTrue(sol.fallback());
    assertEquals(1, solver.postCheckFailures);
    int[] core = sol.core();
    assertEquals(2, core.length);
    assertContinuous(qg, core);
    assertEquals(p, qg.tail(core[0]));
    assertEquals(q, qg.head(core[1]));
    for (int s : core) {
      assertTrue(qg.allowed(s));
    }
  }

  @Test
  void aOneWayRiddenAgainstItsFlowIsFoundWithoutTheFallback() {
    // triangle A, B, C: B-A was only ridden from B to A, so the loop at A must run A, C, B, A;
    // the flow runs towards T and so rides one of the two paths against the route direction
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 5000, 0).node("C", 2500, 4330);
    n.track(1).oneway(Oneway.FORWARD).path("B", "A");
    support(n, 10, 2, "B", "C");
    support(n, 20, 3, "C", "A");
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int a = n.nodeId(g, "A");
    for (String turning : new String[] {"B", "C"}) {
      EdgeDisjointPaths solver = new EdgeDisjointPaths(qg, MAX_TURN);
      EdgeDisjointPaths.Solution sol =
          solver.solve(n.nodeId(g, turning), a, a, new int[0], new int[0], lengthWeights(qg), null);
      assertNotNull(sol, turning);
      assertEquals(3, sol.core().length, turning);
      assertContinuous(qg, sol.core());
      for (int s : sol.core()) {
        assertTrue(qg.allowed(s), turning);
      }
      assertEquals(a, qg.tail(sol.core()[0]), turning);
      assertEquals(a, qg.head(sol.core()[2]), turning);
    }
  }
}
