package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class QueryGraphTest {

  private static TestNetwork lineNetwork() {
    TestNetwork n = new TestNetwork(45.0, 5.0).node("A", 0, 0).node("B", 1000, 0);
    n.track(1).gain(100, 40).path("A", "B");
    return n;
  }

  @Test
  void snappingMidEdgeSplitsItIntoTwoVirtualEdges() {
    TestNetwork n = lineNetwork();
    NetworkGraph g = n.build();
    Snap snap = Snapper.snap(g, n.latLon(400, 5), 2000);
    assertNotNull(snap);
    assertEquals(5, snap.distanceM(), 0.5);
    QueryGraph qg = QueryGraph.create(g, List.of(snap), 30);
    assertEquals(3, qg.nodeCount());
    assertEquals(3, qg.edgeCount());
    assertTrue(qg.isMasked(0));
    int p0 = g.edgeCount();
    int p1 = g.edgeCount() + 1;
    assertEquals(g.length(0), qg.length(p0) + qg.length(p1), 1e-6);
    assertEquals(100, qg.gain(2 * p0) + qg.gain(2 * p1), 1e-3);
    assertEquals(40, qg.loss(2 * p0) + qg.loss(2 * p1), 1e-3);
    assertEquals(0, qg.parentEdge(p0));
    assertEquals(2, qg.degree(qg.snapNode(0)));
    assertEquals(g.isBridge(0), qg.isBridge(p0));
  }

  @Test
  void theGeometryOfAPieceRunsFromTheCutPointToTheEndOfTheParent() {
    TestNetwork n = lineNetwork();
    NetworkGraph g = n.build();
    Snap snap = Snapper.snap(g, n.latLon(400, 0), 2000);
    QueryGraph qg = QueryGraph.create(g, List.of(snap), 30);
    int cut = qg.snapNode(0);
    int p0 = g.edgeCount();
    int p1 = g.edgeCount() + 1;
    for (int piece : new int[] {p0, p1}) {
      double[] xs = qg.geometryX(piece);
      double[] ys = qg.geometryY(piece);
      int last = xs.length - 1;
      int u = qg.edgeU(piece);
      int v = qg.edgeV(piece);
      assertEquals(qg.nodeX(u), xs[0], 0.5);
      assertEquals(qg.nodeY(u), ys[0], 0.5);
      assertEquals(qg.nodeX(v), xs[last], 0.5);
      assertEquals(qg.nodeY(v), ys[last], 0.5);
      assertEquals(qg.length(piece), Geo.polylineLength(xs, ys), 1.0);
      assertTrue(u == cut || v == cut, "a piece touches the cut point");
    }
    // each piece reaches one end of the parent, the other starts or ends at the cut point
    assertEquals(
        g.length(0),
        Geo.polylineLength(qg.geometryX(p0), qg.geometryY(p0))
            + Geo.polylineLength(qg.geometryX(p1), qg.geometryY(p1)),
        1.0);
  }

  @Test
  void aSnapNearAnEndNodeBecomesThatNode() {
    TestNetwork n = lineNetwork();
    NetworkGraph g = n.build();
    Snap snap = Snapper.snap(g, n.latLon(20, 0), 2000);
    QueryGraph qg = QueryGraph.create(g, List.of(snap), 30);
    assertEquals(2, qg.nodeCount());
    assertEquals(1, qg.edgeCount());
    assertEquals(n.nodeId(g, "A"), qg.snapNode(0));
  }

  @Test
  void startAndEndOnTheSameEdgeMakeAChain() {
    TestNetwork n = lineNetwork();
    NetworkGraph g = n.build();
    Snap s = Snapper.snap(g, n.latLon(300, 0), 2000);
    Snap e = Snapper.snap(g, n.latLon(700, 0), 2000);
    QueryGraph qg = QueryGraph.create(g, List.of(s, e), 30);
    assertEquals(4, qg.nodeCount());
    assertEquals(4, qg.edgeCount());
    double sum = 0;
    for (int piece = 1; piece <= 3; piece++) {
      sum += qg.length(piece);
    }
    assertEquals(g.length(0), sum, 1e-6);
    // the chain is walkable from one end to the other
    int node = n.nodeId(g, "A");
    int steps = 0;
    int previous = -1;
    while (steps < 10) {
      int next = -1;
      for (int i = 0; i < qg.outCount(node); i++) {
        int st = qg.outState(node, i);
        if (previous < 0 || st != (previous ^ 1)) {
          next = st;
        }
      }
      if (next < 0) {
        break;
      }
      previous = next;
      node = qg.head(next);
      steps++;
    }
    assertEquals(3, steps);
    assertEquals(n.nodeId(g, "B"), node);
  }

  @Test
  void theMaskedParentIsAbsentFromEveryAdjacency() {
    TestNetwork n = lineNetwork();
    NetworkGraph g = n.build();
    Snap snap = Snapper.snap(g, n.latLon(500, 0), 2000);
    QueryGraph qg = QueryGraph.create(g, List.of(snap), 30);
    for (int node = 0; node < qg.nodeCount(); node++) {
      for (int i = 0; i < qg.outCount(node); i++) {
        assertTrue(qg.outState(node, i) >> 1 != 0, "node " + node);
      }
    }
  }

  @Test
  void aSnapBeyondTheMaximumDistanceIsNull() {
    NetworkGraph g = lineNetwork().build();
    assertNull(Snapper.snap(g, lineNetwork().latLon(400, 2500), 2000));
    assertNotNull(Snapper.snap(g, lineNetwork().latLon(400, 1500), 2000));
  }

  @Test
  void aSnapCanLandOnADanglingStub() {
    TestNetwork n =
        new TestNetwork(45.0, 5.0).node("A", 0, 0).node("B", 1000, 0).node("C", 1000, -1000);
    n.track(1).path("A", "B", "C");
    n.track(2).stubFrom("B", 300, 0);
    NetworkGraph g = n.build();
    Snap snap = Snapper.snap(g, n.latLon(1005, 150), 2000);
    assertNotNull(snap);
    assertTrue(g.dangling(g.edgeU(snap.edge())) || g.dangling(g.edgeV(snap.edge())));
    QueryGraph qg = QueryGraph.create(g, List.of(snap), 30);
    assertEquals(g.nodeCount() + 1, qg.nodeCount());
    assertTrue(qg.dangling(g.edgeV(snap.edge())) || qg.dangling(g.edgeU(snap.edge())));
  }

  @Test
  void snappingPrefersAnEdgeTheRideTypeAdmitsAndFallsBackOnAForbiddenOne() {
    TestNetwork n =
        new TestNetwork(45.0, 5.0)
            .node("W", -3000, 0)
            .node("E", 3000, 0)
            .node("F1", -3000, 10)
            .node("F2", 3000, 10);
    n.track(1).unpaved(false).wayKind(WayKind.MINOR_ROAD).path("W", "E");
    n.track(2).unpaved(false).wayKind(WayKind.FOOTWAY).path("F1", "F2");
    NetworkGraph g = n.build();
    int road = n.edgeBetween(g, "W", "E");
    int footway = n.edgeBetween(g, "F1", "F2");
    QueryGraph plain = QueryGraph.of(g);
    LatLon start = n.latLon(0, 7);
    assertEquals(footway, Snapper.snap(g, start, 2000).edge());
    Snap snap = Snapper.snap(g, start, 2000, e -> EdgeWeights.admitted(plain, e, RideType.ROAD));
    assertEquals(road, snap.edge());
    // nothing admitted within reach: the forbidden edge is the last resort
    Snap fallback = Snapper.snap(g, n.latLon(0, 12), 5, e -> e == road);
    assertEquals(footway, fallback.edge());
  }
}
