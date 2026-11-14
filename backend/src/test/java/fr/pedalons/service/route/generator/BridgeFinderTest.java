package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Arrays;
import org.junit.jupiter.api.Test;

class BridgeFinderTest {

  private static double[] lengths(int n) {
    double[] l = new double[n];
    Arrays.fill(l, 10);
    return l;
  }

  @Test
  void squareWithAPendantEdgeOnlyTheEdgeIsABridge() {
    int[] u = {0, 1, 2, 3, 0};
    int[] v = {1, 2, 3, 0, 4};
    BridgeFinder.Result r = BridgeFinder.find(5, u, v, lengths(5));
    assertFalse(r.bridge()[0]);
    assertFalse(r.bridge()[3]);
    assertTrue(r.bridge()[4]);
    assertEquals(r.component()[0], r.component()[2]);
    assertTrue(r.component()[0] != r.component()[4]);
    assertEquals(2, r.componentCount());
    assertEquals(40, r.componentLength()[r.component()[0]], 1e-9);
    assertEquals(0, r.componentLength()[r.component()[4]], 1e-9);
  }

  @Test
  void twoSquaresJoinedByOneEdgeThatEdgeIsTheBridge() {
    int[] u = {0, 1, 2, 3, 4, 5, 6, 7, 0};
    int[] v = {1, 2, 3, 0, 5, 6, 7, 4, 4};
    BridgeFinder.Result r = BridgeFinder.find(8, u, v, lengths(9));
    for (int e = 0; e < 8; e++) {
      assertFalse(r.bridge()[e], "edge " + e);
    }
    assertTrue(r.bridge()[8]);
    assertEquals(2, r.componentCount());
  }

  @Test
  void parallelEdgesAreNotBridges() {
    BridgeFinder.Result r = BridgeFinder.find(2, new int[] {0, 0}, new int[] {1, 1}, lengths(2));
    assertFalse(r.bridge()[0]);
    assertFalse(r.bridge()[1]);
    assertEquals(1, r.componentCount());
  }

  @Test
  void selfLoopsAreIgnored() {
    BridgeFinder.Result r = BridgeFinder.find(2, new int[] {0, 0}, new int[] {0, 1}, lengths(2));
    assertFalse(r.bridge()[0]);
    assertTrue(r.bridge()[1]);
  }

  @Test
  void aVeryLongPathDoesNotOverflowTheStack() {
    int n = 200_000;
    int[] u = new int[n - 1];
    int[] v = new int[n - 1];
    for (int i = 0; i < n - 1; i++) {
      u[i] = i;
      v[i] = i + 1;
    }
    BridgeFinder.Result r = BridgeFinder.find(n, u, v, lengths(n - 1));
    for (int i = 0; i < n - 1; i++) {
      assertTrue(r.bridge()[i]);
    }
    assertEquals(n, r.componentCount());
  }

  @Test
  void aBuiltGraphKnowsItsBridgesAndComponents() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("A", 0, 0)
            .node("B", 1000, 0)
            .node("C", 1000, 1000)
            .node("D", 0, 1000)
            .node("S", -1000, 0);
    // distinct supports keep every square corner a node
    n.track(1).path("A", "B");
    n.track(2).path("B", "C");
    n.track(3).path("B", "C");
    n.track(4).path("C", "D");
    n.track(5).path("C", "D");
    n.track(6).path("C", "D");
    n.track(7).path("D", "A");
    n.track(8).path("S", "A");
    NetworkGraph g = n.build();
    assertTrue(g.isBridge(n.edgeBetween(g, "S", "A")));
    assertFalse(g.isBridge(n.edgeBetween(g, "A", "B")));
    assertEquals(g.component(n.nodeId(g, "A")), g.component(n.nodeId(g, "C")));
    assertTrue(g.component(n.nodeId(g, "S")) != g.component(n.nodeId(g, "A")));
    assertEquals(4000, g.componentLength(g.component(n.nodeId(g, "A"))), 10);
  }
}
