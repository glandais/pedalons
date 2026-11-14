package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.EnumSet;
import org.junit.jupiter.api.Test;

class RouteGuaranteesTest {
  private static final GeneratorParameters P = GeneratorParameters.defaults();

  private static void support(TestNetwork n, long firstId, int times, String... path) {
    for (int i = 0; i < times; i++) {
      n.track(firstId + i).path(path);
    }
  }

  /**
   * A 16 km square (A-B one-way, ridden A to B), a branch S-E-A of 1.5 km, a spur B-F that leaves
   * B at 155 degrees from the arrival on A-B, and an unknown-ended stub at C. Supports differ on
   * both sides of every degree-2 node so that none is contracted.
   */
  private static TestNetwork square() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .node("E", -500, 0)
            .node("S", -1500, 0)
            .node("F", 3094, -423);
    n.track(1).oneway(Oneway.FORWARD).path("A", "B");
    n.track(2).path("B", "C");
    n.track(3).path("C", "D");
    support(n, 4, 2, "D", "A");
    support(n, 6, 2, "E", "A");
    n.track(8).path("S", "E");
    n.track(9).path("B", "F");
    n.track(10).stubFrom("C", 300, 45);
    return n;
  }

  private static GuaranteeReport check(
      TestNetwork n, NetworkGraph g, String start, String end, double target, int[] states) {
    return RouteGuarantees.check(
        QueryGraph.of(g), n.nodeId(g, start), n.nodeId(g, end), target, states, P);
  }

  private static int stubState(NetworkGraph g, TestNetwork n, boolean outwards) {
    int c = n.nodeId(g, "C");
    for (int i = g.outFrom(c); i < g.outTo(c); i++) {
      int s = g.adjState(i);
      if (g.dangling(g.head(s))) {
        return outwards ? s : s ^ 1;
      }
    }
    throw new IllegalStateException("no stub");
  }

  @Test
  void aValidLoopIsAccepted() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r = check(n, g, "A", "A", 16000, n.route(g, "A", "B", "C", "D", "A"));
    assertTrue(r.ok(), r.violations().toString());
    assertEquals(0, r.crossings());
    assertEquals(0, r.sharedM(), 1e-9);
    assertEquals(16000, r.lengthM(), 100);
  }

  @Test
  void emptyAndForeignStatesAreRejected() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    assertTrue(check(n, g, "A", "A", 1000, new int[0]).violations().contains(Violation.EMPTY));
    assertTrue(
        check(n, g, "A", "A", 1000, new int[] {10_000})
            .violations()
            .contains(Violation.NOT_ON_NETWORK));
  }

  @Test
  void wrongStartAndWrongEnd() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    int[] route = n.route(g, "A", "B", "C", "D", "A");
    assertEquals(
        EnumSet.of(Violation.WRONG_START), check(n, g, "B", "A", 16000, route).violations());
    assertEquals(EnumSet.of(Violation.WRONG_END), check(n, g, "A", "B", 16000, route).violations());
  }

  @Test
  void aGapIsDiscontinuous() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    int[] route = {
      n.state(g, "A", "B"), n.state(g, "C", "D"), n.state(g, "D", "A"),
    };
    assertTrue(check(n, g, "A", "A", 16000, route).violations().contains(Violation.DISCONTINUOUS));
  }

  @Test
  void ridingAOnewayTheWrongWayIsRejected() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r = check(n, g, "A", "A", 16000, n.route(g, "A", "D", "C", "B", "A"));
    assertEquals(EnumSet.of(Violation.ONE_WAY), r.violations());
  }

  @Test
  void aUTurnAndTheDeadEndItReachesAreRejected() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r =
        check(n, g, "B", "B", 2000, new int[] {n.state(g, "B", "F"), n.state(g, "F", "B")});
    assertTrue(r.violations().contains(Violation.U_TURN));
    assertTrue(r.violations().contains(Violation.DEAD_END));
  }

  @Test
  void aTurnOf155DegreesAtAJunctionIsRejected() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r = check(n, g, "A", "F", 5000, n.route(g, "A", "B", "F"));
    assertEquals(EnumSet.of(Violation.SHARP_TURN), r.violations());
  }

  @Test
  void anInteriorDanglingNodeIsADeadEnd() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r =
        check(n, g, "C", "C", 600, new int[] {stubState(g, n, true), stubState(g, n, false)});
    assertTrue(r.violations().contains(Violation.DEAD_END));
  }

  @Test
  void anEdgeUsedThreeTimesIsRejected() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r =
        check(n, g, "A", "B", 40000, n.route(g, "A", "B", "C", "D", "A", "B", "C", "D", "A", "B"));
    assertTrue(r.violations().contains(Violation.EDGE_USED_MORE_THAN_TWICE));
  }

  @Test
  void reuseInTheMiddleOfARouteIsRejected() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r = check(n, g, "A", "C", 24000, n.route(g, "A", "B", "C", "D", "A", "B", "C"));
    assertTrue(r.violations().contains(Violation.REUSE_OUTSIDE_TAIL));
    assertTrue(r.violations().contains(Violation.TAIL_TOO_LONG));
  }

  @Test
  void aFourKilometreTailIsTooLongForTwentyKilometres() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .node("S", -4000, 0);
    support(n, 1, 1, "A", "B");
    support(n, 10, 2, "B", "C");
    support(n, 20, 3, "C", "D");
    support(n, 30, 4, "D", "A");
    n.track(40).path("S", "A");
    NetworkGraph g = n.build();
    GuaranteeReport r = check(n, g, "S", "S", 20000, n.route(g, "S", "A", "B", "C", "D", "A", "S"));
    assertTrue(r.violations().contains(Violation.TAIL_TOO_LONG));
    assertEquals(4000, r.sharedM(), 20);
  }

  @Test
  void startingOnABranchIsAcceptedWithItsSharedLength() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r =
        check(n, g, "S", "S", 19000, n.route(g, "S", "E", "A", "B", "C", "D", "A", "E", "S"));
    assertTrue(r.ok(), r.violations().toString());
    assertEquals(1500, r.sharedM(), 10);
    assertEquals(0, r.crossings());
  }

  @Test
  void aCafeOnTheWayOutIsAcceptedWithItsSharedLength() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GuaranteeReport r =
        check(n, g, "S", "E", 18000, n.route(g, "S", "E", "A", "B", "C", "D", "A", "E"));
    assertTrue(r.ok(), r.violations().toString());
    assertEquals(500, r.sharedM(), 5);
    assertEquals(0, r.crossings());
  }

  @Test
  void aRouteTooFarFromTheTargetDistanceIsRejected() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    int[] route = n.route(g, "A", "B", "C", "D", "A");
    double total = check(n, g, "A", "A", 16000, route).lengthM();
    assertTrue(
        check(n, g, "A", "A", total / 1.15, route)
            .violations()
            .contains(Violation.DISTANCE_OUT_OF_TOLERANCE));
    assertTrue(check(n, g, "A", "A", total / 1.05, route).ok());
  }

  /** A hub with four triangles, each ridden without turning back on itself. */
  private static TestNetwork hub() {
    TestNetwork n = new TestNetwork(45, 5).node("H", 0, 0);
    for (int k = 0; k < 4; k++) {
      double phi = 90.0 * k;
      double pa = Math.toRadians(phi - 20);
      double qa = Math.toRadians(phi + 20);
      n.node("P" + k, 1500 * Math.sin(pa), 1500 * Math.cos(pa));
      n.node("Q" + k, 1500 * Math.sin(qa), 1500 * Math.cos(qa));
      support(n, 100 * (k + 1), 1, "H", "P" + k);
      support(n, 100 * (k + 1) + 10, 2, "P" + k, "Q" + k);
      support(n, 100 * (k + 1) + 20, 3, "Q" + k, "H");
    }
    return n;
  }

  private static String[] triangles(int count) {
    String[] names = new String[1 + 3 * count];
    names[0] = "H";
    for (int k = 0; k < count; k++) {
      names[1 + 3 * k] = "P" + k;
      names[2 + 3 * k] = "Q" + k;
      names[3 + 3 * k] = "H";
    }
    return names;
  }

  @Test
  void aFigureEightThroughOneJunctionCountsOneCrossing() {
    TestNetwork n = hub();
    NetworkGraph g = n.build();
    int[] route = n.route(g, triangles(2));
    double total = check(n, g, "H", "H", 8000, route).lengthM();
    GuaranteeReport r = check(n, g, "H", "H", total, route);
    assertEquals(1, r.crossings());
    assertTrue(r.ok(), r.violations().toString());
  }

  @Test
  void twoCrossingsAreTheLimitAndThreeAreTooMany() {
    TestNetwork n = hub();
    NetworkGraph g = n.build();
    int[] three = n.route(g, triangles(3));
    GuaranteeReport r3 = check(n, g, "H", "H", check(n, g, "H", "H", 1, three).lengthM(), three);
    assertEquals(2, r3.crossings());
    assertTrue(r3.ok(), r3.violations().toString());

    int[] four = n.route(g, triangles(4));
    GuaranteeReport r4 = check(n, g, "H", "H", check(n, g, "H", "H", 1, four).lengthM(), four);
    assertEquals(3, r4.crossings());
    assertEquals(EnumSet.of(Violation.TOO_MANY_CROSSINGS), r4.violations());
    assertFalse(r4.ok());
  }

  /** A loop out along one carriageway and back along the other, 20 m apart, linked at both ends. */
  private static TestNetwork dualCarriagewayLoop(int streetDegreeOfTheLinks) {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("A1", 0, 0)
            .node("B1", 0, 6000)
            .node("B2", 20, 6000)
            .node("A2", 20, 0)
            .streetDegree("B1", streetDegreeOfTheLinks)
            .streetDegree("B2", streetDegreeOfTheLinks);
    n.track(1).oneway(Oneway.FORWARD).path("A1", "B1");
    n.track(2).path("B1", "B2");
    n.track(3).oneway(Oneway.FORWARD).path("B2", "A2");
    n.track(4).path("A2", "A1");
    return n;
  }

  @Test
  void aDualCarriagewayRiddenOutAndBackIsADoubledCorridor() {
    TestNetwork n = dualCarriagewayLoop(3);
    NetworkGraph g = n.build();
    int[] route = n.route(g, "A1", "B1", "B2", "A2", "A1");
    GuaranteeReport r = check(n, g, "A1", "A1", 12000, route);
    assertTrue(r.violations().contains(Violation.CORRIDOR_DOUBLED), r.violations().toString());
    // the 180 degree turn across the 20 m link is measured at a real node of team degree 2
    assertTrue(r.violations().contains(Violation.SHARP_TURN), r.violations().toString());
  }

  @Test
  void theTurnRuleSkipsANodeOfStreetDegreeTwoButNotTheCorridorRule() {
    TestNetwork n = dualCarriagewayLoop(2);
    NetworkGraph g = n.build();
    int[] route = n.route(g, "A1", "B1", "B2", "A2", "A1");
    GuaranteeReport r = check(n, g, "A1", "A1", 12000, route);
    assertFalse(r.violations().contains(Violation.SHARP_TURN), r.violations().toString());
    assertTrue(r.violations().contains(Violation.CORRIDOR_DOUBLED), r.violations().toString());
  }

  @Test
  void aFigureEightIsNotADoubledCorridor() {
    TestNetwork n = hub();
    NetworkGraph g = n.build();
    GuaranteeReport r = check(n, g, "H", "H", 8000, n.route(g, triangles(2)));
    assertFalse(r.violations().contains(Violation.CORRIDOR_DOUBLED), r.violations().toString());
  }

  @Test
  void aVirtualNodeNeverCountsAsAJunctionForTheTurnRule() {
    // S is cut in the middle of A-B: arriving and leaving there along the same road is not a turn
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GeneratorRequest request =
        new GeneratorRequest(n.latLon(2000, 0), null, null, 16000, 0.5, RideType.ROAD, 1);
    QueryGraph qg = RouteChecks.queryGraph(g, request, P);
    assertTrue(qg.isVirtual(qg.snapNode(0)));
    assertFalse(RouteGuarantees.turnApplies(qg, qg.snapNode(0)));
  }
}
