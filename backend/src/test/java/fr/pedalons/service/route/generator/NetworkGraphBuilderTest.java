package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class NetworkGraphBuilderTest {

  private static TestNetwork net() {
    return new TestNetwork(45.0, 5.0);
  }

  @Test
  void sameEdgeFromTwoTracksInOppositeDirectionsIsOneEdge() {
    TestNetwork n = net().node("A", 0, 0).node("B", 1000, 0);
    n.track(1).path("A", "B");
    n.track(2).path("B", "A");
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertEquals(2, g.support(0));
    assertTrue(g.allowed(n.state(g, "A", "B")));
    assertTrue(g.allowed(n.state(g, "B", "A")));
    assertEquals(1000, g.length(0), 2);
  }

  @Test
  void aContractionThatMakesASecondCopyOfAnEdgeFoldsItIntoTheFirst() {
    // older tracks rode the spur a-b in one edge, newer ones after a node m was added in the
    // middle: a-m and m-b contract into a second a-b edge, which must merge with the first
    TestNetwork n =
        net()
            .node("X", -1000, 0)
            .node("a", 0, 0)
            .node("Y", 1000, 0)
            .node("m", 0, 750)
            .node("b", 0, 1500);
    n.track(1).path("X", "a", "Y");
    n.track(2).path("a", "b");
    n.track(3).path("a", "m", "b");
    NetworkGraph g = n.build();
    assertEquals(3, g.edgeCount());
    assertEquals(1, g.degree(n.nodeId(g, "b")));
    assertEquals(2, g.support(n.edgeBetween(g, "a", "b")));
  }

  @Test
  void parallelRoadsBetweenTheSameJunctionsSurviveOnlyWhenFarApart() {
    TestNetwork far = net().node("A", 0, 0).node("B", 1000, 0);
    far.track(1).path("A", "B");
    far.track(2).via("A", "B", 500, 60);
    assertEquals(2, far.build().edgeCount());

    TestNetwork near = net().node("A", 0, 0).node("B", 1000, 0);
    near.track(1).path("A", "B");
    near.track(2).via("A", "B", 500, 5);
    NetworkGraph g = near.build();
    assertEquals(1, g.edgeCount());
    assertEquals(2, g.support(0));
  }

  @Test
  void nodesCloserThanTwoAndAHalfMetresMerge() {
    // three branches meet at J; the third track starts from a key 1.8 m away
    TestNetwork merged =
        net().node("A", 0, 0).node("J", 1000, 0).node("B", 2000, 0).node("C", 1000, 1000);
    merged.alias("J", "J2", 1.8, 0);
    merged.track(1).path("A", "J");
    merged.track(2).path("J2", "B");
    merged.track(3).path("J", "C");
    NetworkGraph g = merged.build();
    assertEquals(4, g.nodeCount());
    assertEquals(3, g.edgeCount());
    assertEquals(3, g.degree(merged.nodeId(g, "J")));

    TestNetwork apart =
        net().node("A", 0, 0).node("J", 1000, 0).node("B", 2000, 0).node("C", 1000, 1000);
    apart.alias("J", "J2", 3.0, 0);
    apart.track(1).path("A", "J");
    apart.track(2).path("J2", "B");
    apart.track(3).path("J", "C");
    NetworkGraph h = apart.build();
    // J has degree 2 but its two edges are ridden by different tracks: kept (contraction needs
    // identical track sets), and J2-B stays on its own
    assertEquals(3, h.edgeCount());
  }

  @Test
  void chainOfCloseNodesMergesTransitively() {
    TestNetwork n =
        net().node("A", 0, 0).node("K1", 1000, 0).node("B", 2000, 0).node("C", 1000, 1000);
    n.alias("K1", "K2", 2, 0).alias("K1", "K3", 4, 0);
    n.track(1).path("A", "K1");
    n.track(2).path("K2", "B");
    n.track(3).path("K3", "C");
    NetworkGraph g = n.build();
    // K1-K3 are 4 m apart but the chain K1-K2-K3 merges them all: documented behaviour
    assertEquals(4, g.nodeCount());
    assertEquals(3, g.degree(n.nodeId(g, "K1")));
  }

  @Test
  void forwardOnewayOnlyAllowsTheRiddenDirection() {
    TestNetwork n = net().node("A", 0, 0).node("B", 1000, 0);
    n.track(1).oneway(Oneway.FORWARD).path("A", "B");
    NetworkGraph g = n.build();
    assertTrue(g.allowed(n.state(g, "A", "B")));
    assertFalse(g.allowed(n.state(g, "B", "A")));
  }

  @Test
  void againstOnewayOnlyAllowsTheRiddenDirection() {
    TestNetwork n = net().node("A", 0, 0).node("B", 1000, 0);
    n.track(1).oneway(Oneway.AGAINST).path("B", "A");
    NetworkGraph g = n.build();
    assertTrue(g.allowed(n.state(g, "B", "A")));
    assertFalse(g.allowed(n.state(g, "A", "B")));
  }

  @Test
  void oneObservationSayingOnewayWinsOverTwoWay() {
    TestNetwork n = net().node("A", 0, 0).node("B", 1000, 0);
    n.track(1).path("A", "B");
    n.track(2).oneway(Oneway.FORWARD).path("A", "B");
    n.track(3).path("B", "A"); // rode it backwards, but only a BOTH observation
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    // directions observed by non-excluded tracks: both, so both stay allowed on a one-way edge
    assertTrue(g.allowed(n.state(g, "A", "B")));
    assertTrue(g.allowed(n.state(g, "B", "A")));

    TestNetwork m = net().node("A", 0, 0).node("B", 1000, 0);
    m.track(1).path("A", "B");
    m.track(2).oneway(Oneway.FORWARD).path("A", "B");
    NetworkGraph h = m.build();
    assertTrue(h.allowed(m.state(h, "A", "B")));
    assertFalse(h.allowed(m.state(h, "B", "A")));
  }

  @Test
  void edgeUsedOnlyByAnExcludedTrackIsAbsent() {
    TestNetwork n =
        net().node("A", 0, 0).node("B", 1000, 0).node("C", 1000, 1000).node("D", 0, 1000);
    n.track(1).path("C", "D", "A", "B");
    n.track(2).excluded().path("B", "C");
    NetworkGraph g = n.build();
    assertEquals(3000, g.stats().totalLengthM(), 10);
    assertEquals(1, g.stats().excludedTrackCount());
    // the three ridden sides are one contracted chain from C to B: no edge closes the square
    assertEquals(1, g.edgeCount());
    assertEquals(2, g.nodeCount());
  }

  @Test
  void excludedTrackDoesNotCountAsSupport() {
    TestNetwork n = net().node("A", 0, 0).node("B", 1000, 0);
    n.track(1).path("A", "B");
    n.track(2).excluded().path("A", "B");
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertEquals(1, g.support(0));
  }

  @Test
  void directionObservedOnlyByAnExcludedTrackIsNotAllowed() {
    TestNetwork n = net().node("A", 0, 0).node("B", 1000, 0);
    n.track(1).oneway(Oneway.FORWARD).path("A", "B");
    n.track(2).excluded().oneway(Oneway.FORWARD).path("B", "A");
    NetworkGraph g = n.build();
    assertTrue(g.allowed(n.state(g, "A", "B")));
    assertFalse(g.allowed(n.state(g, "B", "A")));
  }

  @Test
  void stubWithAnUnknownEndIsADanglingNode() {
    TestNetwork n = net().node("A", 0, 0).node("B", 1000, 0).node("C", 2000, 0);
    n.track(1).path("A", "B", "C");
    n.track(2).stubFrom("B", 300, 0);
    n.track(3).stubFrom("B", 250, 0);
    NetworkGraph g = n.build();
    assertEquals(1, g.stats().danglingStubCount());
    assertEquals(3, g.edgeCount());
    int dangling = -1;
    for (int i = 0; i < g.nodeCount(); i++) {
      if (g.dangling(i)) {
        dangling = i;
      }
    }
    assertEquals(1, g.degree(dangling));
    // two overlapping stubs from one node are one stub, with the support of both tracks
    int stubEdge = -1;
    for (int e = 0; e < g.edgeCount(); e++) {
      if (g.dangling(g.edgeU(e)) || g.dangling(g.edgeV(e))) {
        stubEdge = e;
      }
    }
    assertEquals(2, g.support(stubEdge));
    assertEquals(300, g.length(stubEdge), 2);
  }

  @Test
  void chainOfDegreeTwoNodesWithEqualSupportIsContracted() {
    TestNetwork n = net().node("A", 0, 0).node("n1", 300, 0).node("n2", 700, 0).node("B", 1000, 0);
    n.track(1).gain(10, 5).path("A", "n1", "n2", "B");
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertEquals(2, g.nodeCount());
    assertEquals(1000, g.length(0), 2);
    int s = n.state(g, "A", "B");
    assertEquals(30, g.gain(s), 1e-3);
    assertEquals(15, g.loss(s), 1e-3);
    // reversed: gain and loss swap
    assertEquals(15, g.gain(s ^ 1), 1e-3);
  }

  @Test
  void aSupportChangeStopsTheContraction() {
    TestNetwork n = net().node("A", 0, 0).node("n1", 300, 0).node("n2", 700, 0).node("B", 1000, 0);
    n.track(1).path("A", "n1", "n2", "B");
    n.track(2).path("n1", "n2", "B");
    NetworkGraph g = n.build();
    // n2 has the same support on both sides (2, 2) and goes; n1 (1, 2) stays
    assertEquals(2, g.edgeCount());
    assertEquals(3, g.nodeCount());
    assertTrue(n.nodeId(g, "n1") >= 0);
    assertEquals(-1, n.nodeId(g, "n2"));
  }

  @Test
  void contractionNeverCreatesASelfLoop() {
    TestNetwork n = net().node("A", 0, 0).node("N", 500, 0);
    n.track(1).path("A", "N");
    n.track(2).via("A", "N", 250, 100);
    NetworkGraph g = n.build();
    assertEquals(2, g.edgeCount());
    assertEquals(2, g.nodeCount());
  }

  @Test
  void headingsComeFromTheThirtyToFiftyMetreWindow() {
    TestNetwork n = net().node("A", 0, 0).node("B", 100, 100);
    n.track(1).via("A", "B", 5, 10, 0, 20, 0, 100);
    NetworkGraph g = n.build();
    int s = n.state(g, "A", "B");
    assertEquals(0, Geo.turnAngleDeg(g.startHeading(s), 0), 1.0);
    assertEquals(90, g.endHeading(s), 1.0);
    // reversed state: start is the end seen backwards
    assertEquals(270, g.startHeading(s ^ 1), 1.0);
  }

  @Test
  void aVeryShortEdgeGetsAClampedFiniteHeading() {
    TestNetwork n = net().node("A", 0, 0).node("B", 31, 0);
    n.track(1).path("A", "B");
    NetworkGraph g = n.build();
    int s = n.state(g, "A", "B");
    assertEquals(90, g.startHeading(s), 1.0);
    assertEquals(90, g.endHeading(s), 1.0);
  }

  @Test
  void dualCarriagewayIsACorridorButCrossingRoadsAreNot() {
    TestNetwork n =
        net()
            .node("A", 0, 0)
            .node("B", 0, 1000)
            .node("C", 15, 0)
            .node("D", 15, 1000)
            .node("E", -500, 500)
            .node("F", 500, 500);
    n.track(1).path("A", "B");
    n.track(2).path("D", "C");
    n.track(3).path("E", "F");
    NetworkGraph g = n.build();
    int ab = n.edgeBetween(g, "A", "B");
    int cd = n.edgeBetween(g, "C", "D");
    int ef = n.edgeBetween(g, "E", "F");
    assertTrue(contains(g.corridorNeighbours(ab), cd));
    assertTrue(contains(g.corridorNeighbours(cd), ab));
    assertFalse(contains(g.corridorNeighbours(ab), ef));
    assertFalse(contains(g.corridorNeighbours(ef), ab));
  }

  @Test
  void twoConsecutiveEdgesOfOneRoadAreNotACorridor() {
    TestNetwork n =
        net().node("A", 0, 0).node("M", 1000, 0).node("B", 2000, 0).node("C", 1000, 1000);
    n.track(1).path("A", "M", "B");
    n.track(2).path("M", "C");
    NetworkGraph g = n.build();
    int am = n.edgeBetween(g, "A", "M");
    int mb = n.edgeBetween(g, "M", "B");
    assertTrue(am >= 0 && mb >= 0);
    assertFalse(contains(g.corridorNeighbours(am), mb));
  }

  @Test
  void aBuildIsDeterministicWhateverTheInputOrder() {
    TestNetwork n = net().node("A", 0, 0).node("B", 1000, 0).node("C", 1000, 1000);
    n.track(1).path("A", "B", "C");
    n.track(2).path("C", "A");
    var inputs = new java.util.ArrayList<>(n.inputs());
    NetworkGraph g1 = NetworkGraphBuilder.build(inputs, NetworkParameters.defaults());
    java.util.Collections.reverse(inputs);
    NetworkGraph g2 = NetworkGraphBuilder.build(inputs, NetworkParameters.defaults());
    assertEquals(g1.edgeCount(), g2.edgeCount());
    for (int e = 0; e < g1.edgeCount(); e++) {
      assertEquals(g1.edgeU(e), g2.edgeU(e));
      assertEquals(g1.edgeV(e), g2.edgeV(e));
      assertEquals(g1.length(e), g2.length(e), 1e-9);
    }
  }

  private static boolean contains(int[] values, int v) {
    for (int x : values) {
      if (x == v) {
        return true;
      }
    }
    return false;
  }
}
