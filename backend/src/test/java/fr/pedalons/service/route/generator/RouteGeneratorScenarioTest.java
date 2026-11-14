package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;

/**
 * Hand-built graphs for {@link RouteGenerator} (design §7.2). Every returned route is re-checked by
 * {@link RouteGuarantees} from the test side through {@link RouteChecks}, then the scenario's own
 * property is asserted. Coordinates are in metres, x east and y north, around (45, 5).
 *
 * <p>Edges of a degree-2 node get different supports wherever the scenario wants the node kept:
 * the builder contracts a degree-2 node whose two sides look alike.
 */
class RouteGeneratorScenarioTest {
  private static final GeneratorParameters P = GeneratorParameters.defaults();
  private static final RouteGenerator GENERATOR = new RouteGenerator(P);

  // ---- helpers --------------------------------------------------------------------------------

  private static final class Ids {
    long next = 1;
  }

  private static TestNetwork base() {
    return new TestNetwork(45, 5);
  }

  /** {@code times} tracks over the same path: support {@code times}. */
  static void ride(TestNetwork n, Ids ids, int times, String... path) {
    for (int i = 0; i < times; i++) {
      n.track(ids.next++).path(path);
    }
  }

  private static GeneratorRequest loop(TestNetwork n, double x, double y, double distanceM) {
    return loop(n, x, y, distanceM, null, 0.5, RideType.ROAD);
  }

  private static GeneratorRequest loop(
      TestNetwork n,
      double x,
      double y,
      double distanceM,
      @Nullable Bearing8 bearing,
      double familiarity,
      RideType surface) {
    return new GeneratorRequest(n.latLon(x, y), null, bearing, distanceM, familiarity, surface, 7);
  }

  private static GeneratorRequest trip(
      TestNetwork n, double x, double y, double ex, double ey, double distanceM) {
    return new GeneratorRequest(
        n.latLon(x, y), n.latLon(ex, ey), null, distanceM, 0.5, RideType.ROAD, 7);
  }

  private static GeneratorResult.Success success(GeneratorResult r) {
    return assertInstanceOf(GeneratorResult.Success.class, r, r.toString());
  }

  private static GeneratorResult.Failure failure(GeneratorResult r) {
    return assertInstanceOf(GeneratorResult.Failure.class, r, r.toString());
  }

  private static void assertAllValid(
      List<TrackInput> tracks,
      NetworkGraph g,
      GeneratorRequest r,
      GeneratorResult.Success s,
      String label) {
    assertFalse(s.routes().isEmpty(), label);
    assertTrue(s.routes().size() <= 3, label);
    for (int i = 0; i < s.routes().size(); i++) {
      RouteChecks.assertValid(g, r, P, s.routes().get(i), label + " #" + i);
      // and from the raw input only, with no graph (design §12.9, review M6)
      List<String> raw = RawInputOracle.violations(tracks, r, s.routes().get(i), P);
      assertTrue(raw.isEmpty(), label + " #" + i + " raw oracle: " + raw);
    }
  }

  private static boolean uses(GeneratedRoute route, int edge) {
    return route.steps().stream().anyMatch(st -> st.edgeId() == edge);
  }

  // ---- scenario graphs ------------------------------------------------------------------------

  /** Scenario 1: a 16 km square with a 2 km spur at B ending in a dead end X. */
  static TestNetwork deadEndInLoop() {
    TestNetwork n =
        base()
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .node("X", 6000, 0);
    Ids ids = new Ids();
    ride(n, ids, 1, "A", "B");
    ride(n, ids, 2, "B", "C");
    ride(n, ids, 3, "C", "D");
    ride(n, ids, 4, "D", "A");
    ride(n, ids, 5, "B", "X");
    return n;
  }

  /** Scenario 2: two 16 km squares, L at the origin and R 6 km east, joined by a 2 km bridge. */
  static TestNetwork twoSquaresAndABridge() {
    TestNetwork n =
        base()
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .node("A2", 6000, 0)
            .node("B2", 10000, 0)
            .node("C2", 10000, 4000)
            .node("D2", 6000, 4000);
    Ids ids = new Ids();
    ride(n, ids, 1, "A", "B");
    ride(n, ids, 2, "B", "C");
    ride(n, ids, 3, "C", "D");
    ride(n, ids, 4, "D", "A");
    ride(n, ids, 1, "A2", "B2");
    ride(n, ids, 2, "B2", "C2");
    ride(n, ids, 3, "C2", "D2");
    ride(n, ids, 4, "D2", "A2");
    ride(n, ids, 6, "B", "A2");
    return n;
  }

  /** Scenario 3: a dual carriageway (two one-way roads 15 m apart) and a road to the west. */
  static TestNetwork dualCarriageway() {
    TestNetwork n =
        base()
            .node("A1", 0, 0)
            .node("A2", 15, 0)
            .node("B1", 0, 8000)
            .node("B2", 15, 8000)
            .node("W", -3000, 4000);
    Ids ids = new Ids();
    n.track(ids.next++).oneway(Oneway.FORWARD).path("A2", "B2"); // northbound
    n.track(ids.next++).oneway(Oneway.FORWARD).path("B1", "A1"); // southbound
    ride(n, ids, 2, "A1", "A2");
    ride(n, ids, 3, "B2", "B1");
    ride(n, ids, 4, "A1", "W", "B1");
    return n;
  }

  /**
   * Scenario 4: a roundabout of four one-way quarter arcs (counter-clockwise), an arm of 3 km to
   * each side, and an outer ring linking the arm ends.
   */
  static TestNetwork roundabout() {
    TestNetwork n =
        base()
            .node("RN", 0, 20)
            .node("RW", -20, 0)
            .node("RS", 0, -20)
            .node("RE", 20, 0)
            .node("N1", 0, 3000)
            .node("W1", -3000, 0)
            .node("S1", 0, -3000)
            .node("E1", 3000, 0);
    Ids ids = new Ids();
    double k = 20 * Math.sqrt(0.5);
    n.track(ids.next++).oneway(Oneway.FORWARD).via("RN", "RW", -k, k);
    n.track(ids.next++).oneway(Oneway.FORWARD).via("RW", "RS", -k, -k);
    n.track(ids.next++).oneway(Oneway.FORWARD).via("RS", "RE", k, -k);
    n.track(ids.next++).oneway(Oneway.FORWARD).via("RE", "RN", k, k);
    ride(n, ids, 1, "RN", "N1");
    ride(n, ids, 1, "RW", "W1");
    ride(n, ids, 1, "RS", "S1");
    ride(n, ids, 1, "RE", "E1");
    ride(n, ids, 2, "N1", "E1");
    ride(n, ids, 2, "E1", "S1");
    ride(n, ids, 2, "S1", "W1");
    ride(n, ids, 2, "W1", "N1");
    return n;
  }

  /** Scenario 5: a 16 km square with a branch of {@code branchM} metres ending at S. */
  static TestNetwork squareWithBranch(double branchM) {
    TestNetwork n =
        base()
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .node("S", -branchM, 0);
    Ids ids = new Ids();
    ride(n, ids, 1, "A", "B");
    ride(n, ids, 2, "B", "C");
    ride(n, ids, 3, "C", "D");
    ride(n, ids, 4, "D", "A");
    ride(n, ids, 5, "S", "A");
    return n;
  }

  /**
   * Scenario 6: S and E 5 km apart, joined by a straight road, by a road through N1 (7.8 km) and
   * by a road through N2 (16.8 km), with N1 and N2 linked.
   */
  static TestNetwork cafeFiveKilometresAway() {
    TestNetwork n =
        base().node("S", 0, 0).node("E", 5000, 0).node("N1", 2500, 3000).node("N2", 2500, 8000);
    Ids ids = new Ids();
    ride(n, ids, 1, "S", "E");
    ride(n, ids, 2, "S", "N1");
    ride(n, ids, 3, "N1", "E");
    ride(n, ids, 4, "S", "N2");
    ride(n, ids, 5, "N2", "E");
    ride(n, ids, 6, "N1", "N2");
    return n;
  }

  /** Scenario 6b: a 16 km square with a 2 km branch S-E-A, the café E being 1 km from S. */
  static TestNetwork cafeOnTheWayOut() {
    TestNetwork n =
        base()
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .node("E", -1000, 0)
            .node("S", -2000, 0);
    Ids ids = new Ids();
    ride(n, ids, 1, "A", "B");
    ride(n, ids, 2, "B", "C");
    ride(n, ids, 3, "C", "D");
    ride(n, ids, 4, "D", "A");
    ride(n, ids, 5, "E", "A");
    ride(n, ids, 6, "S", "E");
    return n;
  }

  /** Scenario 7: a 15 km triangle whose side A-B was only ever ridden from A to B. */
  static TestNetwork oneWayTriangle(Oneway oneway, boolean fromAToB) {
    TestNetwork n = base().node("A", 0, 0).node("B", 5000, 0).node("C", 2500, 4330);
    Ids ids = new Ids();
    if (fromAToB) {
      n.track(ids.next++).oneway(oneway).path("A", "B");
    } else {
      n.track(ids.next++).oneway(oneway).path("B", "A");
    }
    ride(n, ids, 2, "B", "C");
    ride(n, ids, 3, "C", "A");
    return n;
  }

  /** Scenario 8: two 16 km diamonds meeting at S, the north one ridden by 10, the south by 1. */
  static TestNetwork twoDiamonds() {
    TestNetwork n =
        base()
            .node("S", 0, 0)
            .node("N1", 2800, 2800)
            .node("N2", 0, 5600)
            .node("N3", -2800, 2800)
            .node("S1", 2800, -2800)
            .node("S2", 0, -5600)
            .node("S3", -2800, -2800);
    Ids ids = new Ids();
    ride(n, ids, 10, "S", "N1", "N2", "N3", "S");
    ride(n, ids, 1, "S", "S1", "S2", "S3", "S");
    return n;
  }

  /**
   * Scenario 9: a square whose side B-C was only ridden by an excluded track, and a detour B-X-C
   * ridden by a normal one.
   */
  static TestNetwork excludedSide() {
    TestNetwork n =
        base()
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .node("X", 5500, 2000);
    Ids ids = new Ids();
    ride(n, ids, 1, "A", "B");
    ride(n, ids, 2, "B", "X");
    ride(n, ids, 3, "X", "C");
    ride(n, ids, 4, "C", "D");
    ride(n, ids, 5, "D", "A");
    n.track(ids.next++).excluded().path("B", "C");
    return n;
  }

  /** Scenario 10: the 16 km square, its corner C given by two keys 1.8 m apart. */
  static TestNetwork squareWithSplitCorner() {
    TestNetwork n =
        base()
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .alias("C", "C2", 1.8, 0);
    Ids ids = new Ids();
    ride(n, ids, 1, "A", "B");
    ride(n, ids, 2, "B", "C");
    ride(n, ids, 3, "C2", "D");
    ride(n, ids, 4, "D", "A");
    return n;
  }

  /** Scenario 11 and 12: the plain 16 km square. */
  static TestNetwork square() {
    TestNetwork n =
        base().node("A", 0, 0).node("B", 4000, 0).node("C", 4000, 4000).node("D", 0, 4000);
    Ids ids = new Ids();
    ride(n, ids, 1, "A", "B");
    ride(n, ids, 2, "B", "C");
    ride(n, ids, 3, "C", "D");
    ride(n, ids, 4, "D", "A");
    return n;
  }

  /** Scenario 13: two 16 km diamonds meeting at S, the first side of the north one unpaved. */
  static TestNetwork oneUnpavedSide() {
    TestNetwork n =
        base()
            .node("S", 0, 0)
            .node("N1", 2800, 2800)
            .node("N2", 0, 5600)
            .node("N3", -2800, 2800)
            .node("S1", 2800, -2800)
            .node("S2", 0, -5600)
            .node("S3", -2800, -2800);
    Ids ids = new Ids();
    n.track(ids.next++).unpaved(true).path("S", "N1");
    n.track(ids.next++).unpaved(false).path("N1", "N2", "N3", "S");
    n.track(ids.next++).unpaved(false).path("S", "S1", "S2", "S3", "S");
    return n;
  }

  // ---- 11, 12: feasibility --------------------------------------------------------------------

  @Test
  void aStartOrAnEndFarFromTheNetworkIsRefused() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GeneratorResult.Failure far = failure(GENERATOR.generate(g, loop(n, -2500, 2000, 16000)));
    assertEquals(GeneratorFailure.START_TOO_FAR, far.reason());

    GeneratorResult.Failure farEnd =
        failure(GENERATOR.generate(g, trip(n, 0, 0, 6500, 2000, 16000)));
    assertEquals(GeneratorFailure.END_TOO_FAR, farEnd.reason());
  }

  @Test
  void aNetworkTooSmallForTheDistanceIsReportedAsSuch() {
    TestNetwork n = square();
    NetworkGraph g = n.build();
    GeneratorResult.Failure f = failure(GENERATOR.generate(g, loop(n, 0, 0, 40000)));
    assertEquals(GeneratorFailure.NETWORK_TOO_SMALL, f.reason());
  }

  // ---- 1: dead end in a loop ------------------------------------------------------------------

  @Test
  void aDeadEndInsideTheLoopIsNeverEntered() {
    TestNetwork n = deadEndInLoop();
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 0, 0, 16000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "square");
    int spur = n.edgeBetween(g, "B", "X");
    assertNotEquals(-1, spur);
    for (GeneratedRoute route : s.routes()) {
      assertFalse(uses(route, spur));
      assertEquals(16000, route.distanceM(), 200);
      assertEquals(0, route.sharedM(), 1e-9);
    }
    // The square plus the spur out and back is 20 km, 5 % off 19 km and so inside the tolerance,
    // the bare square 16 km, 16 % off: the only candidate that fits is the forbidden one. 19 km
    // also clears the feasibility check (road within reach 18 km >= 0.9 x 19 km), so the refusal
    // comes from the search, not from NETWORK_TOO_SMALL.
    GeneratorResult.Failure nineteen = failure(GENERATOR.generate(g, loop(n, 0, 0, 19000)));
    assertEquals(GeneratorFailure.NO_ROUTE, nineteen.reason());
  }

  // ---- 2: a bridge between two components -----------------------------------------------------

  @Test
  void aBridgeIsNeverCrossedTwiceInTheMiddleOfARoute() {
    TestNetwork n = twoSquaresAndABridge();
    NetworkGraph g = n.build();
    int bridge = n.edgeBetween(g, "B", "A2");

    GeneratorRequest r = loop(n, 0, 0, 16000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "left square");
    for (GeneratedRoute route : s.routes()) {
      assertFalse(uses(route, bridge));
    }

    GeneratorResult.Failure both = failure(GENERATOR.generate(g, loop(n, 0, 0, 36000)));
    assertEquals(GeneratorFailure.NO_ROUTE, both.reason());
  }

  @Test
  void aStartOnTheBridgeRidesOneKilometreOutAndBack() {
    TestNetwork n = twoSquaresAndABridge();
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 5000, 0, 18000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "start on the bridge");
    for (GeneratedRoute route : s.routes()) {
      assertEquals(1000, route.sharedM(), 50);
      assertEquals(0, route.crossings());
    }
  }

  @Test
  void twoSquaresApartNeedTheBridgeOnce() {
    TestNetwork n = twoSquaresAndABridge();
    NetworkGraph g = n.build();
    GeneratorResult.Failure tooShort =
        failure(GENERATOR.generate(g, trip(n, 0, 4000, 10000, 4000, 18000)));
    assertEquals(GeneratorFailure.DISTANCE_TOO_SHORT, tooShort.reason());

    GeneratorRequest r = trip(n, 0, 4000, 10000, 4000, 19500);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "square to square");
    int bridge = n.edgeBetween(g, "B", "A2");
    for (GeneratedRoute route : s.routes()) {
      assertEquals(0, route.sharedM(), 1e-9);
      assertEquals(18000, route.distanceM(), 300);
      assertEquals(1, route.steps().stream().filter(st -> st.edgeId() == bridge).count());
    }
  }

  // ---- 3: dual carriageway --------------------------------------------------------------------

  @Test
  void bothCarriagewaysOfADualCarriagewayAreNeverRiddenInTheSameRoute() {
    TestNetwork n = dualCarriageway();
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 0, 0, 17000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "dual carriageway");
    QueryGraph qg = RouteChecks.queryGraph(g, r, P);
    for (int i = 0; i < s.routes().size(); i++) {
      GeneratedRoute route = s.routes().get(i);
      int[] states = RouteChecks.states(qg, qg.snapNode(0), route.steps());
      assertTrue(
          CandidateScorer.corridorShare(qg, states) <= P.maxCorridorShare(),
          "route " + i + " rides both carriageways");
    }
    // the best route takes the road to the west: 18 km, one carriageway plus the long road
    GeneratedRoute best = s.routes().get(0);
    assertEquals(18000, best.distanceM(), 200);
    assertTrue(best.steps().stream().anyMatch(st -> g.length(st.edgeId()) > 9000));
    // judged without the implementation's own corridor measure: the 16 km out and back along both
    // carriageways (A2-B2 northbound, B1-A1 southbound) is never returned
    int northbound = n.edgeBetween(g, "A2", "B2");
    int southbound = n.edgeBetween(g, "B1", "A1");
    for (GeneratedRoute route : s.routes()) {
      assertFalse(uses(route, northbound) && uses(route, southbound));
    }
  }

  // ---- 4: roundabout --------------------------------------------------------------------------

  @Test
  void aRoundaboutIsRiddenInItsOwnDirectionOnly() {
    TestNetwork n = roundabout();
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 0, 3000, 15000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "roundabout");
    String[][] arcs = {{"RN", "RW"}, {"RW", "RS"}, {"RS", "RE"}, {"RE", "RN"}};
    String[][] arms = {{"RN", "N1"}, {"RW", "W1"}, {"RS", "S1"}, {"RE", "E1"}};
    for (GeneratedRoute route : s.routes()) {
      // no route enters and leaves the roundabout by the same arm
      for (String[] arm : arms) {
        int edge = n.edgeBetween(g, arm[0], arm[1]);
        assertTrue(
            route.steps().stream().filter(st -> st.edgeId() == edge).count() <= 1,
            "arm " + arm[0] + "-" + arm[1] + " ridden twice");
      }
      for (RouteStep step : route.steps()) {
        for (String[] arc : arcs) {
          if (step.edgeId() == n.edgeBetween(g, arc[0], arc[1])) {
            assertEquals(n.state(g, arc[0], arc[1]), 2 * step.edgeId() + (step.forward() ? 0 : 1));
          }
        }
      }
    }
  }

  @Test
  void crossingTheRoundaboutFromTheNorthArmToTheSouthArmIsNotAUTurn() {
    TestNetwork n = roundabout();
    NetworkGraph g = n.build();
    int[] states = n.route(g, "N1", "RN", "RW", "RS", "S1");
    GuaranteeReport report =
        RouteGuarantees.check(
            QueryGraph.of(g), n.nodeId(g, "N1"), n.nodeId(g, "S1"), 6100, states, P);
    assertTrue(report.ok(), report.violations().toString());
  }

  // ---- 5: start on a branch -------------------------------------------------------------------

  @Test
  void aStartOnABranchRidesTheBranchOutAndBack() {
    TestNetwork n = squareWithBranch(1500);
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, -1500, 0, 19000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "branch of 1.5 km");
    for (GeneratedRoute route : s.routes()) {
      assertEquals(1500, route.sharedM(), 20);
      assertEquals(0, route.crossings());
      assertEquals(19000, route.distanceM(), 100);
    }
    // the whole network is 17.5 km: far under 0.9 x 30 km
    GeneratorResult.Failure tooBig = failure(GENERATOR.generate(g, loop(n, -1500, 0, 30000)));
    assertEquals(GeneratorFailure.NETWORK_TOO_SMALL, tooBig.reason());
  }

  @Test
  void aBranchLongerThanTheTailAllowsRefusesTheRoute() {
    TestNetwork n = squareWithBranch(4000);
    NetworkGraph g = n.build();
    GeneratorResult.Failure f = failure(GENERATOR.generate(g, loop(n, -4000, 0, 22000)));
    assertEquals(GeneratorFailure.NO_ROUTE, f.reason());
    assertEquals("TAIL_TOO_LONG", f.detail());
  }

  // ---- 6: end different from start ------------------------------------------------------------

  @Test
  void aCafeFiveKilometresAwayIsReachedByTheLongWayWhenTheDistanceAsks() {
    TestNetwork n = cafeFiveKilometresAway();
    NetworkGraph g = n.build();
    GeneratorResult.Failure tooShort = failure(GENERATOR.generate(g, trip(n, 0, 0, 5000, 0, 5000)));
    assertEquals(GeneratorFailure.DISTANCE_TOO_SHORT, tooShort.reason());

    GeneratorRequest r = trip(n, 0, 0, 5000, 0, 8000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "cafe");
    GeneratedRoute best = s.routes().get(0);
    assertEquals(7810, best.distanceM(), 100);
    assertEquals(0, best.sharedM(), 1e-9);
  }

  @Test
  void aCafeOnTheWayOutIsPassedTwice() {
    TestNetwork n = cafeOnTheWayOut();
    NetworkGraph g = n.build();
    GeneratorRequest r = trip(n, -2000, 0, -1000, 0, 19000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "cafe on the way out");
    for (GeneratedRoute route : s.routes()) {
      assertEquals(1000, route.sharedM(), 20);
      assertEquals(19000, route.distanceM(), 100);
    }
  }

  // ---- 7: one-way observed in one direction ---------------------------------------------------

  @Test
  void aOneWayObservedOneWayIsRiddenThatWayOnly() {
    TestNetwork n = oneWayTriangle(Oneway.FORWARD, true);
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 0, 0, 15000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "forward triangle");
    int ab = n.edgeBetween(g, "A", "B");
    int forward = n.state(g, "A", "B");
    for (GeneratedRoute route : s.routes()) {
      for (RouteStep st : route.steps()) {
        if (st.edgeId() == ab) {
          assertEquals(forward, 2 * ab + (st.forward() ? 0 : 1));
        }
      }
    }
  }

  @Test
  void aContraflowObservedAgainstTheOneWayIsRiddenAgainstIt() {
    TestNetwork n = oneWayTriangle(Oneway.AGAINST, false);
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 0, 0, 15000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "contraflow triangle");
    int ab = n.edgeBetween(g, "A", "B");
    int allowed = n.state(g, "B", "A");
    for (GeneratedRoute route : s.routes()) {
      for (RouteStep st : route.steps()) {
        if (st.edgeId() == ab) {
          assertEquals(allowed, 2 * ab + (st.forward() ? 0 : 1));
        }
      }
    }
  }

  // ---- 8: familiarity -------------------------------------------------------------------------

  @Test
  void theFamiliaritySliderPicksTheRoadsTheTeamRidesOftenOrRarely() {
    TestNetwork n = twoDiamonds();
    NetworkGraph g = n.build();

    GeneratorRequest often = loop(n, 0, 0, 16000, null, 1.0, RideType.ROAD);
    GeneratorResult.Success sOften = success(GENERATOR.generate(g, often));
    assertAllValid(n.inputs(), g, often, sOften, "f = 1");
    assertEquals(1.0, sOften.routes().get(0).familiarity(), 0.05);

    GeneratorRequest rarely = loop(n, 0, 0, 16000, null, 0.0, RideType.ROAD);
    GeneratorResult.Success sRarely = success(GENERATOR.generate(g, rarely));
    assertAllValid(n.inputs(), g, rarely, sRarely, "f = 0");
    // a support of 1 is log1p(1) / log1p(max): the rare diamond is not at zero any more (§12.7)
    double rare = Math.log1p(1) / Math.log1p(g.stats().maxSupport());
    assertEquals(rare, sRarely.routes().get(0).familiarity(), 0.05);

    GeneratorRequest neutral = loop(n, 0, 0, 16000);
    GeneratorResult.Success sNeutral = success(GENERATOR.generate(g, neutral));
    assertAllValid(n.inputs(), g, neutral, sNeutral, "f = 0.5");
    assertTrue(sNeutral.routes().stream().anyMatch(rt -> rt.familiarity() > 0.95));
    assertTrue(sNeutral.routes().stream().anyMatch(rt -> rt.familiarity() < rare + 0.05));
  }

  // ---- 9, 10: builder inputs reach the generator ----------------------------------------------

  @Test
  void aSideOnlyAnExcludedTrackRodeIsNeverUsed() {
    TestNetwork n = excludedSide();
    NetworkGraph g = n.build();
    assertEquals(-1, n.edgeBetween(g, "B", "C"));
    GeneratorRequest r = loop(n, 0, 0, 17000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "detour");
    int detour = n.edgeBetween(g, "B", "X");
    for (GeneratedRoute route : s.routes()) {
      assertTrue(uses(route, detour));
    }
  }

  @Test
  void aCornerGivenByTwoKeysLessThanTwoAndAHalfMetresApartIsOneNode() {
    TestNetwork n = squareWithSplitCorner();
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 0, 0, 16000);
    GeneratorResult.Success s = success(GENERATOR.generate(g, r));
    assertAllValid(n.inputs(), g, r, s, "merged corner");
  }

  // ---- 13: surface ----------------------------------------------------------------------------

  @Test
  void roadBansTheUnpavedSideAndGravelAllowsIt() {
    TestNetwork n = oneUnpavedSide();
    NetworkGraph g = n.build();
    int unpaved = n.edgeBetween(g, "S", "N1");
    assertNotEquals(-1, unpaved);

    GeneratorRequest road = loop(n, 0, 0, 16000, null, 0.5, RideType.ROAD);
    GeneratorResult.Success sRoad = success(GENERATOR.generate(g, road));
    assertAllValid(n.inputs(), g, road, sRoad, "ROAD");
    for (GeneratedRoute route : sRoad.routes()) {
      assertFalse(uses(route, unpaved));
      assertEquals(0, route.unpavedShare(), 1e-9);
    }

    GeneratorRequest any = loop(n, 0, 0, 16000, null, 0.5, RideType.GRAVEL);
    GeneratorResult.Success sAny = success(GENERATOR.generate(g, any));
    assertAllValid(n.inputs(), g, any, sAny, "GRAVEL");
    assertTrue(sAny.routes().stream().anyMatch(rt -> rt.unpavedShare() > 0));
  }

  // ---- 14: bearing ----------------------------------------------------------------------------

  @Test
  void aBearingOrientsTheRouteAndNoBearingLeavesTheFieldEmpty() {
    List<TrackInput> tracks = GridNetwork.tracks(11, 11, 1000, 0, 0, 0, 45, 5, 1);
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    LatLon centre = new LocalProjection(45, 5).toLatLon(0, 0);

    GeneratorRequest north =
        new GeneratorRequest(centre, null, Bearing8.N, 12000, 0.5, RideType.ROAD, 3);
    GeneratorResult.Success s = success(GENERATOR.generate(g, north));
    assertAllValid(tracks, g, north, s, "north");
    Double deviation = s.routes().get(0).bearingDeviationDeg();
    assertNotNull(deviation);
    assertTrue(deviation <= 35, "deviation " + deviation);

    // judged from the test side: the middle of the route lies in the requested sector, east too
    // (the grid is symmetric, so only an east-west mirror in the search would show on E)
    GeneratorRequest east =
        new GeneratorRequest(centre, null, Bearing8.E, 12000, 0.5, RideType.ROAD, 3);
    GeneratorResult.Success se = success(GENERATOR.generate(g, east));
    assertAllValid(tracks, g, east, se, "east");
    LocalProjection projection = new LocalProjection(45, 5);
    for (GeneratedRoute route : se.routes()) {
      double sx = 0;
      double sy = 0;
      for (LatLon q : route.points()) {
        sx += projection.toX(q.lat(), q.lon());
        sy += projection.toY(q.lat(), q.lon());
      }
      double bearing = Geo.bearingDeg(0, 0, sx / route.points().size(), sy / route.points().size());
      assertTrue(Geo.turnAngleDeg(bearing, 90) <= 60, "barycentre bearing " + bearing);
    }

    // the bearing only applies when the end is closer than D/2: here it is 4 km away for 7.9 km
    LatLon far = projection.toLatLon(4000, 0);
    GeneratorRequest distantEnd =
        new GeneratorRequest(centre, far, Bearing8.N, 7900, 0.5, RideType.ROAD, 3);
    GeneratorResult.Success sd = success(GENERATOR.generate(g, distantEnd));
    assertAllValid(tracks, g, distantEnd, sd, "distant end");
    for (GeneratedRoute route : sd.routes()) {
      assertNull(route.bearingDeviationDeg());
    }

    GeneratorRequest any = new GeneratorRequest(centre, null, null, 12000, 0.5, RideType.ROAD, 3);
    GeneratorResult.Success none = success(GENERATOR.generate(g, any));
    assertAllValid(tracks, g, any, none, "no bearing");
    for (GeneratedRoute route : none.routes()) {
      assertNull(route.bearingDeviationDeg());
    }
  }

  // ---- determinism and diversity ---------------------------------------------------------------

  @Test
  void theSameRequestTwiceGivesTheSameRoutesAndTheRoutesDiffer() {
    TestNetwork n = twoDiamonds();
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 0, 0, 16000);
    GeneratorResult.Success a = success(GENERATOR.generate(g, r));
    GeneratorResult.Success b = success(GENERATOR.generate(g, r));
    assertEquals(a.routes(), b.routes());
    for (int i = 0; i < a.routes().size(); i++) {
      for (int j = i + 1; j < a.routes().size(); j++) {
        double shared = RouteChecks.sharedBetween(g, a.routes().get(i), a.routes().get(j));
        double shorter = Math.min(a.routes().get(i).distanceM(), a.routes().get(j).distanceM());
        assertTrue(shared / shorter < 0.5);
      }
    }
  }

  @Test
  void theRequestRejectsANonPositiveDistanceAndAFamiliarityOutOfRange() {
    LatLon p = new LatLon(45, 5);
    boolean thrown = false;
    try {
      new GeneratorRequest(p, null, null, 0, 0.5, RideType.ROAD, 1);
    } catch (IllegalArgumentException e) {
      thrown = true;
    }
    assertTrue(thrown);
    thrown = false;
    try {
      new GeneratorRequest(p, null, null, 1000, 1.5, RideType.ROAD, 1);
    } catch (IllegalArgumentException e) {
      thrown = true;
    }
    assertTrue(thrown);
  }
}
