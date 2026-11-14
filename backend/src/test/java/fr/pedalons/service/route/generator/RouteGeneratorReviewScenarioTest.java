package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Scenarios 13a-f, 15-19 and 21 of design §12.9: the cases the independent review found (B1, B2,
 * M1, M2, M4) and the ride types. Every returned route also goes through {@link RawInputOracle}.
 */
class RouteGeneratorReviewScenarioTest {
  private static final GeneratorParameters P = GeneratorParameters.defaults();
  private static final RouteGenerator GENERATOR = new RouteGenerator(P);

  private static TestNetwork base() {
    return new TestNetwork(45, 5);
  }

  private static GeneratorRequest loop(
      TestNetwork n, double x, double y, double d, RideType type, double f, long seed) {
    return new GeneratorRequest(n.latLon(x, y), null, null, d, f, type, seed);
  }

  private static void assertOracle(
      List<TrackInput> tracks, GeneratorRequest r, GeneratorResult.Success s, String label) {
    for (int i = 0; i < s.routes().size(); i++) {
      List<String> raw = RawInputOracle.violations(tracks, r, s.routes().get(i), P);
      assertTrue(raw.isEmpty(), label + " #" + i + ": " + raw);
    }
  }

  private static boolean touchesSpur(TestNetwork n, GeneratedRoute route, double minY) {
    for (LatLon q : route.points()) {
      if (n.yOf(q) > minY) {
        return true;
      }
    }
    return false;
  }

  // ---- 15: B1, the U-turn through a short connector --------------------------------------------

  /**
   * W-X-E closed by the south (22 km), and a spur north of X: X to Y1 one-way, a 15 m connector
   * Y1-Y2, Y2 to X one-way. {@code shared} makes one track ride the whole spur (contraction path).
   */
  private static TestNetwork spurNetwork(boolean shared, double carriageGapM) {
    TestNetwork n =
        base()
            .node("W", -3000, 0)
            .node("X", 0, 0)
            .node("E", 3000, 0)
            .node("S1", 3000, -5000)
            .node("S2", -3000, -5000)
            .node("Y1", 0, 2000)
            .node("Y2", carriageGapM, 2000);
    n.track(1).path("W", "X");
    n.track(2).path("X", "E");
    n.track(3).path("E", "S1", "S2", "W");
    if (shared) {
      n.track(4).oneway(Oneway.FORWARD).path("X", "Y1", "Y2", "X");
    } else {
      n.track(10).oneway(Oneway.FORWARD).path("X", "Y1");
      n.track(11).oneway(Oneway.FORWARD).path("X", "Y1");
      n.track(12).path("Y1", "Y2");
      for (long id = 13; id <= 15; id++) {
        n.track(id).oneway(Oneway.FORWARD).path("Y2", "X");
      }
    }
    return n;
  }

  private void spurIsNeverRidden(boolean shared, double gap, String label) {
    TestNetwork n = spurNetwork(shared, gap);
    NetworkGraph g = n.build();
    for (long seed = 1; seed <= 8; seed++) {
      GeneratorRequest r = loop(n, -3000, 0, 24000, RideType.ROAD, 0.5, seed);
      GeneratorResult res = GENERATOR.generate(g, r);
      if (res instanceof GeneratorResult.Success s) {
        for (GeneratedRoute route : s.routes()) {
          RouteChecks.assertValid(g, r, P, route, label + " seed " + seed);
          assertFalse(touchesSpur(n, route, 100), label + " seed " + seed + ": rides the spur");
        }
        assertOracle(n.inputs(), r, s, label + " seed " + seed);
      }
    }
  }

  @Test
  void aShortConnectorBetweenTwoDegreeTwoNodesIsNeverAUTurn() {
    spurIsNeverRidden(false, 15, "separate track sets");
  }

  @Test
  void theSameSpurRiddenByOneTrackIsNotContractedIntoAHiddenUTurn() {
    spurIsNeverRidden(true, 15, "one track");
    spurIsNeverRidden(false, 40, "carriageways 40 m apart");
  }

  @Test
  void aHandWrittenRouteThroughTheSpurIsASharpTurn() {
    TestNetwork n = spurNetwork(false, 15);
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, -3000, 0, 24000, RideType.ROAD, 0.5, 1);
    QueryGraph qg = RouteChecks.queryGraph(g, r, P);
    int[] states = n.route(g, "W", "X", "Y1", "Y2", "X", "E", "W");
    GuaranteeReport report =
        RouteGuarantees.check(qg, qg.snapNode(0), qg.snapNode(0), 24000, states, P);
    assertTrue(report.violations().contains(Violation.SHARP_TURN), report.violations().toString());
  }

  // ---- 15b: contraction refuses a hidden U-turn ------------------------------------------------

  /**
   * W-X-Z-E closed by the south (22 km), and a spur north: X to Y1 up one carriageway, a connector
   * Y1-Y2 of {@code connectorM}, Y2 back down to Z (a node other than X, {@code connectorM} east of
   * it), all ridden by one track so the two Y nodes are contraction candidates. With {@code
   * junctionAtY2} a side track leaves Y2 to a dead end, so Y2 is a team junction and the walk of
   * the contraction check stops there (design §12.13).
   */
  private static TestNetwork spurToZ(double connectorM, boolean junctionAtY2) {
    return spurToZ(connectorM, junctionAtY2, 0);
  }

  /** {@code shape}: 0 straight connector, 1 drawn with a vertex every 10 m, 2 slanted (Y2 lower). */
  private static TestNetwork spurToZ(double connectorM, boolean junctionAtY2, int shape) {
    double y2 = shape == 2 ? 2000 - connectorM : 2000;
    TestNetwork n =
        base()
            .node("W", -3000, 0)
            .node("X", 0, 0)
            .node("Z", connectorM, 0)
            .node("E", 3000, 0)
            .node("S1", 3000, -5000)
            .node("S2", -3000, -5000)
            .node("Y1", 0, 2000)
            .node("Y2", connectorM, y2);
    if (shape == 1) {
      java.util.List<Double> bends = new java.util.ArrayList<>();
      for (double x = 10; x < connectorM - 0.5; x += 10) {
        bends.add(x);
        bends.add(2000.0);
      }
      n.edge("Y1", "Y2", bends.stream().mapToDouble(Double::doubleValue).toArray());
    }
    n.track(1).path("W", "X");
    n.track(2).path("X", "Z", "E");
    n.track(3).path("E", "S1", "S2", "W");
    n.track(4).path("X", "Y1", "Y2", "Z");
    if (junctionAtY2) {
      n.node("Q", connectorM, y2 + 400);
      n.track(5).path("Y2", "Q");
    }
    return n;
  }

  @Test
  void contractionNeverHidesAUTurnMadeOfTwoCarriagewaysAndAConnector() {
    for (boolean junction : new boolean[] {false, true}) {
      for (double connector : new double[] {15, 40, 80}) {
        spurToZIsRefused(connector, junction, 0);
      }
    }
  }

  /** A connector drawn with a vertex every 10 m, or slanted, is the same U-turn (review round 3). */
  @Test
  void aConnectorDrawnWithManyVerticesOrSlantedIsStillAUTurn() {
    for (boolean junction : new boolean[] {false, true}) {
      for (double connector : new double[] {15, 40, 80}) {
        spurToZIsRefused(connector, junction, 1);
      }
      for (double connector : new double[] {40, 60}) {
        spurToZIsRefused(connector, junction, 2);
      }
    }
  }

  private void spurToZIsRefused(double connector, boolean junctionAtY2, int shape) {
    String label =
        "connector " + connector + " m, shape " + shape + ", Y2 junction " + junctionAtY2;
    TestNetwork n = spurToZ(connector, junctionAtY2, shape);
    NetworkGraph g = n.build();
    boolean y1 = n.nodeId(g, "Y1") >= 0;
    boolean y2 = n.nodeId(g, "Y2") >= 0;
    assertTrue(y1 && y2, label + ": a Y node was contracted, the U-turn is hidden in an edge");
    // the hand-written route through the spur is refused by the checker
    GeneratorRequest r = loop(n, -3000, 0, 26000, RideType.ROAD, 0.5, 1);
    QueryGraph qg = RouteChecks.queryGraph(g, r, P);
    int[] states = n.route(g, "W", "X", "Y1", "Y2", "Z", "E", "W");
    GuaranteeReport report =
        RouteGuarantees.check(qg, qg.snapNode(0), qg.snapNode(0), 26000, states, P);
    assertTrue(
        report.violations().contains(Violation.SHARP_TURN), label + ": " + report.violations());
    for (long seed = 1; seed <= 4; seed++) {
      GeneratorRequest req = loop(n, -3000, 0, 26000, RideType.ROAD, 0.5, seed);
      if (GENERATOR.generate(g, req) instanceof GeneratorResult.Success ok) {
        for (GeneratedRoute route : ok.routes()) {
          RouteChecks.assertValid(g, req, P, route, label);
          assertFalse(touchesSpur(n, route, 100), label + ": rides the spur");
        }
        assertOracle(n.inputs(), req, ok, label + " seed " + seed);
      }
    }
  }

  // ---- 15c: hairpins the team rides (design §12.13) ---------------------------------------------

  /**
   * D-A north to a hairpin, back down to B and on to C, closed by C-D: one track rides all of it
   * ({@code apex} 0: one apex node; 1: a second junction 30 m after the apex; 2: one 40 m before).
   * The side streets make the apex and the second junction nodes of street degree 3 without any
   * team edge, so the team rides through every one of them.
   */
  private static TestNetwork hairpin(int variant) {
    TestNetwork n =
        base()
            .node("A", 0, 0)
            .node("H", 0, 3000)
            .node("B", 600, 0)
            .node("C", 600, -4000)
            .node("D", 0, -4000);
    String[] names;
    if (variant == 0) {
      n.streetDegree("H", 3);
      n.edge("A", "H", 0, 2960, 2, 2985);
      n.edge("H", "B", 18, 2985, 20, 2960);
      names = new String[] {"D", "A", "H", "B", "C", "D"};
    } else if (variant == 1) {
      n.node("H2", 20, 2960).streetDegree("H", 3).streetDegree("H2", 3);
      n.edge("A", "H", 0, 2960, 2, 2985);
      n.edge("H", "H2", 18, 2985);
      n.edge("H2", "B", 25, 2900);
      names = new String[] {"D", "A", "H", "H2", "B", "C", "D"};
    } else {
      n.node("H0", 0, 2960).streetDegree("H0", 3).streetDegree("H", 3);
      n.edge("H0", "H", 2, 2985);
      n.edge("H", "B", 18, 2985, 20, 2960);
      names = new String[] {"D", "A", "H0", "H", "B", "C", "D"};
    }
    for (long id = 1; id <= 3; id++) {
      n.track(id).path(java.util.Arrays.copyOfRange(names, 0, names.length - 1));
    }
    n.track(9).path("C", "D");
    return n;
  }

  @Test
  void aHairpinTheTeamRidesStaysLegalWithAnApexAloneOrWithAJunctionBeforeOrAfter() {
    for (int variant = 0; variant < 3; variant++) {
      TestNetwork n = hairpin(variant);
      NetworkGraph g = n.build();
      GeneratorRequest r = loop(n, 0, -4000, 14665, RideType.ROAD, 0.5, 1);
      QueryGraph qg = RouteChecks.queryGraph(g, r, P);
      String[] all =
          variant == 0
              ? new String[] {"D", "A", "H", "B", "C", "D"}
              : variant == 1
                  ? new String[] {"D", "A", "H", "H2", "B", "C", "D"}
                  : new String[] {"D", "A", "H0", "H", "B", "C", "D"};
      String[] kept =
          java.util.Arrays.stream(all).filter(x -> n.nodeId(g, x) >= 0).toArray(String[]::new);
      int[] states = n.route(g, kept);
      double len = 0;
      for (int st : states) {
        len += g.length(st >>> 1);
      }
      GuaranteeReport report =
          RouteGuarantees.check(qg, qg.snapNode(0), qg.snapNode(0), len, states, P);
      assertTrue(report.violations().isEmpty(), "variant " + variant + ": " + report.violations());
      GeneratorRequest req = loop(n, 0, -4000, len, RideType.ROAD, 0.5, 1);
      GeneratorResult res = GENERATOR.generate(g, req);
      GeneratorResult.Success ok =
          assertInstanceOf(GeneratorResult.Success.class, res, "variant " + variant + ": " + res);
      for (GeneratedRoute route : ok.routes()) {
        RouteChecks.assertValid(g, req, P, route, "hairpin variant " + variant);
      }
      assertOracle(n.inputs(), req, ok, "hairpin variant " + variant);
    }
  }

  // ---- 15d: the team rode both carriageways, but never crossed from one to the other in a pass
  // ---

  /**
   * The spur of 15b with a 10 m gap (a narrow median), ridden by track 4 only. {@code mode} 0: one
   * pass X Y1 Y2 Z, the team made that U-turn itself. {@code mode} 1: the track went out on one
   * carriageway, turned round at T1-T2 and came back on the other, then rode up again and crossed
   * the connector from the north: it never went from X-Y1 into the connector.
   */
  private static TestNetwork narrowDual(int mode) {
    double c = 10;
    TestNetwork n =
        base()
            .node("W", -3000, 0)
            .node("X", 0, 0)
            .node("Z", c, 0)
            .node("E", 3000, 0)
            .node("S1", 3000, -5000)
            .node("S2", -3000, -5000)
            .node("Y1", 0, 2000)
            .node("Y2", c, 2000)
            .node("T1", 0, 3500)
            .node("T2", c, 3500);
    n.track(1).path("W", "X");
    n.track(2).path("X", "Z", "E");
    n.track(3).path("E", "S1", "S2", "W");
    if (mode == 0) {
      n.track(4).path("X", "Y1", "Y2", "Z");
    } else {
      n.track(4).path("X", "Y1", "T1", "T2", "Y2", "Z", "X", "Y1", "T1", "Y1", "Y2");
    }
    return n;
  }

  @Test
  void aTrackThatRodeBothCarriagewaysAtOtherMomentsDoesNotMakeTheConnectorAHairpin() {
    TestNetwork n = narrowDual(1);
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, -3000, 0, 26000, RideType.ROAD, 0.5, 1);
    QueryGraph qg = RouteChecks.queryGraph(g, r, P);
    int[] states = n.route(g, "W", "X", "Y1", "Y2", "Z", "E", "W");
    GuaranteeReport report =
        RouteGuarantees.check(qg, qg.snapNode(0), qg.snapNode(0), 26000, states, P);
    assertTrue(
        report.violations().contains(Violation.SHARP_TURN), "out and back: " + report.violations());
    // the predicate on its own: the two Y nodes are a hairpin only when one pass rode them
    assertFalse(RouteGuarantees.hairpinTheTeamRides(qg, states, 1, 2), "out and back, no pass");
    TestNetwork one = narrowDual(0);
    NetworkGraph og = one.build();
    QueryGraph oq = RouteChecks.queryGraph(og, r, P);
    assertTrue(
        RouteGuarantees.hairpinTheTeamRides(
            oq, one.route(og, "W", "X", "Y1", "Y2", "Z", "E", "W"), 1, 2),
        "one pass");
    for (long seed = 1; seed <= 4; seed++) {
      GeneratorRequest req = loop(n, -3000, 0, 26000, RideType.ROAD, 0.5, seed);
      if (GENERATOR.generate(g, req) instanceof GeneratorResult.Success ok) {
        for (GeneratedRoute route : ok.routes()) {
          RouteChecks.assertValid(g, req, P, route, "out and back seed " + seed);
          assertFalse(touchesSpur(n, route, 100), "out and back seed " + seed + ": rides the spur");
        }
        assertOracle(n.inputs(), req, ok, "out and back seed " + seed);
      }
    }
  }

  /**
   * Known and wanted (owner decision, option A): when one track really rode a gap narrower than a
   * connector (15 m), the team made that hairpin itself.
   */
  @Test
  void aNarrowGapOneTrackRodeInOnePassIsAHairpinTheTeamMade() {
    TestNetwork n = narrowDual(0);
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, -3000, 0, 26000, RideType.ROAD, 0.5, 1);
    QueryGraph qg = RouteChecks.queryGraph(g, r, P);
    int[] states = n.route(g, "W", "X", "Y1", "Y2", "Z", "E", "W");
    GuaranteeReport report =
        RouteGuarantees.check(qg, qg.snapNode(0), qg.snapNode(0), 26000, states, P);
    assertFalse(report.violations().contains(Violation.SHARP_TURN), report.violations().toString());
  }

  // ---- 15e: a junction with many short team branches does not hide the turn (walk cap) ----------

  @Test
  void contractionIsRefusedWhenTheWalkPastANearbyJunctionWasCutShort() {
    for (int spurs : new int[] {8, 12}) {
      for (double connector : new double[] {40, 60, 80}) {
        TestNetwork n = spurToZ(connector, false);
        // east of Y2, a street with a node every 10 m and a 30 m dead-end spur at each, ridden by
        // tracks that sort before track 4 so their edges come first around Y2
        String prev = "Y2";
        for (int k = 1; k <= spurs; k++) {
          String street = "P" + k;
          String spur = "F" + k;
          n.node(street, connector + 10.0 * k, 2000).node(spur, connector + 10.0 * k, 2030);
          n.track(-k).path(prev, street, spur);
          prev = street;
        }
        NetworkGraph g = n.build();
        String label = "comb " + spurs + " spurs, connector " + connector;
        assertTrue(
            n.nodeId(g, "Y1") >= 0 && n.nodeId(g, "Y2") >= 0,
            label + ": a Y node was contracted, the U-turn is hidden in an edge");
        for (long seed = 1; seed <= 4; seed++) {
          GeneratorRequest req = loop(n, -3000, 0, 26000, RideType.ROAD, 0.5, seed);
          if (GENERATOR.generate(g, req) instanceof GeneratorResult.Success ok) {
            for (GeneratedRoute route : ok.routes()) {
              RouteChecks.assertValid(g, req, P, route, label);
              assertFalse(touchesSpur(n, route, 100), label + ": rides the spur");
            }
            assertOracle(n.inputs(), req, ok, label + " seed " + seed);
          }
        }
      }
    }
  }

  // ---- 22: a start on a forbidden dead-end spur takes the piece that leads on (§12.13) ---------

  @Test
  void aStartOnAForbiddenDeadEndSpurLeavesByThePieceThatLeadsOn() {
    TestNetwork n =
        base()
            .node("W", -6000, 0)
            .node("X", 0, 0)
            .node("E", 6000, 0)
            .node("S1", 6000, -10000)
            .node("S2", -6000, -10000)
            .node("F", 0, 3000);
    n.track(1).unpaved(false).wayKind(WayKind.MINOR_ROAD).path("W", "X", "E", "S1", "S2", "W");
    n.track(2).unpaved(false).wayKind(WayKind.FOOTWAY).path("X", "F");
    NetworkGraph g = n.build();
    // 2100 m up the footway: the road is out of snap reach, the piece to F is 900 m of dead end.
    // 2985 m and 3040 m: the start snaps onto F itself, whose only edge is the forbidden one
    for (double y : new double[] {2100, 2985, 3040}) {
      GeneratorRequest r = loop(n, 0, y, 48200, RideType.ROAD, 0.5, 1);
      GeneratorResult res = GENERATOR.generate(g, r);
      GeneratorResult.Success ok =
          assertInstanceOf(
              GeneratorResult.Success.class, res, "the footway start " + y + ": " + res);
      for (GeneratedRoute route : ok.routes()) {
        RouteChecks.assertValid(g, r, P, route, "footway start " + y);
      }
      assertOracle(n.inputs(), r, ok, "footway start " + y);
    }
  }

  // ---- 17: M2, the team street cut at the start point ------------------------------------------

  @Test
  void aStreetWhoseTracksAllStartAtTheTeamLocationIsOneEdgeAndTheLoopUsesBothEnds() {
    TestNetwork n =
        base().node("A", 0, 0).node("B", 1200, 0).node("C", 1200, 5500).node("D", 0, 5500);
    // laps starting and ending at T = 480 m from A, in both directions
    for (long id = 1; id <= 3; id++) {
      n.track(id).startAt("A", "B", 480).path("B", "C", "D", "A").endAt("A", "B", 480);
    }
    for (long id = 4; id <= 5; id++) {
      n.track(id).startAt("B", "A", 720).path("A", "D", "C", "B").endAt("B", "A", 720);
    }
    n.track(6).path("B", "C", "D");
    n.track(7).path("D", "A");
    NetworkGraph g = n.build();
    assertEquals(0, g.stats().danglingStubCount(), "no phantom stub at the start point");
    int street = n.edgeBetween(g, "A", "B");
    assertNotEquals(-1, street);
    assertEquals(1200, g.length(street), 2);
    assertTrue(g.stats().stitchedEdges() >= 1);

    GeneratorRequest r = loop(n, 480, 0, 14000, RideType.ROAD, 0.5, 5);
    GeneratorResult.Success s =
        assertInstanceOf(GeneratorResult.Success.class, GENERATOR.generate(g, r));
    for (GeneratedRoute route : s.routes()) {
      RouteChecks.assertValid(g, r, P, route, "team street");
      assertEquals(0, route.sharedM(), 1e-9, "leaves by one end and returns by the other");
    }
    assertOracle(n.inputs(), r, s, "team street");
  }

  // ---- 18: M1, the polygon family for a close end ----------------------------------------------

  @Test
  void aCloseEndDistinctFromTheStartStillGetsPolygonCandidates() {
    List<TrackInput> tracks = GridNetwork.tracks(10, 10, 1000, 0, 0, 0, 45, 5, 1);
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    LocalProjection proj = new LocalProjection(45, 5);
    GeneratorRequest r =
        new GeneratorRequest(
            proj.toLatLon(-500, -500),
            proj.toLatLon(2500, -500),
            null,
            20000,
            0.5,
            RideType.ROAD,
            4);
    GeneratorResult res = GENERATOR.generate(g, r);
    GeneratorResult.Success s =
        assertInstanceOf(GeneratorResult.Success.class, res, res.toString());
    assertTrue(s.diagnostics().polygonCandidates() > 0, s.diagnostics().toString());
    assertTrue(s.diagnostics().validPolygon() > 0, s.diagnostics().toString());
    for (GeneratedRoute route : s.routes()) {
      RouteChecks.assertValid(g, r, P, route, "cafe 3 km");
    }
    assertOracle(tracks, r, s, "cafe 3 km");
  }

  // ---- 19: M4, a one-way trip from a long branch -----------------------------------------------

  private static List<TrackInput> gridWithBranch(boolean branchOneWay) {
    List<TrackInput> tracks = new ArrayList<>(GridNetwork.tracks(6, 6, 2000, 0, 0, 0, 45, 5, 1));
    LocalProjection proj = new LocalProjection(45, 5);
    NodeRef junction = new NodeRef("2_0", proj.toLatLon(-5000, -1000), 4);
    NodeRef tip = new NodeRef("S", proj.toLatLon(-9000, -1000), 1);
    List<TrackEdge> edges = new ArrayList<>();
    edges.add(
        TestNetwork.complete(
            tip, junction, branchOneWay ? Oneway.FORWARD : Oneway.BOTH, null, null));
    if (!branchOneWay) {
      edges.add(TestNetwork.complete(junction, tip, Oneway.BOTH, null, null));
    }
    tracks.add(new TrackInput(9001, false, TrackKind.ROAD, edges));
    return tracks;
  }

  @Test
  void aTripFromAFourKilometreBranchRidesTheBranchOnce() {
    LocalProjection proj = new LocalProjection(45, 5);
    for (boolean oneWay : new boolean[] {false, true}) {
      List<TrackInput> tracks = gridWithBranch(oneWay);
      NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
      GeneratorRequest r =
          new GeneratorRequest(
              proj.toLatLon(-9000, -1000),
              proj.toLatLon(3000, 1000),
              null,
              20000,
              0.5,
              RideType.ROAD,
              2);
      GeneratorResult res = GENERATOR.generate(g, r);
      String label = "branch one-way=" + oneWay;
      GeneratorResult.Success s =
          assertInstanceOf(GeneratorResult.Success.class, res, label + " " + res);
      for (GeneratedRoute route : s.routes()) {
        RouteChecks.assertValid(g, r, P, route, label);
        assertEquals(0, route.sharedM(), 1e-9, label);
      }
      assertOracle(tracks, r, s, label);
    }
  }

  @Test
  void aLoopFromTheSameBranchIsStillRefusedAsATailTooLong() {
    List<TrackInput> tracks = gridWithBranch(false);
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    LocalProjection proj = new LocalProjection(45, 5);
    GeneratorRequest r =
        new GeneratorRequest(proj.toLatLon(-9000, -1000), null, null, 24000, 0.5, RideType.ROAD, 2);
    GeneratorResult.Failure f =
        assertInstanceOf(GeneratorResult.Failure.class, GENERATOR.generate(g, r));
    assertEquals(GeneratorFailure.NO_ROUTE, f.reason());
    assertEquals("TAIL_TOO_LONG", f.detail());
  }

  // ---- 21: an excluded track's private road ----------------------------------------------------

  @Test
  void aRoadOnlyAnExcludedTrackRodeIsNeverUsedAndTheOracleAgrees() {
    TestNetwork n =
        base()
            .node("A", 0, 0)
            .node("B", 4000, 0)
            .node("C", 4000, 4000)
            .node("D", 0, 4000)
            .node("G", -3000, 0)
            .node("H", -3000, 4000);
    n.track(1).path("A", "B");
    n.track(2).path("B", "C");
    n.track(3).path("C", "D");
    n.track(4).path("D", "H");
    n.track(5).path("H", "G");
    n.track(6).path("G", "A");
    n.track(7).excluded().path("D", "A"); // the private road
    NetworkGraph g = n.build();
    assertEquals(-1, n.edgeBetween(g, "D", "A"));
    for (double d : new double[] {16000, 22000}) {
      GeneratorRequest r = loop(n, 0, 0, d, RideType.ROAD, 0.5, 3);
      if (GENERATOR.generate(g, r) instanceof GeneratorResult.Success s) {
        for (GeneratedRoute route : s.routes()) {
          for (LatLon q : route.points()) {
            boolean onPrivate = Math.abs(n.xOf(q)) < 20 && n.yOf(q) > 100 && n.yOf(q) < 3900;
            assertFalse(onPrivate, "rides the private road");
          }
        }
        assertOracle(n.inputs(), r, s, "private road " + d);
      }
    }
  }

  // ---- 13a-f: ride types -----------------------------------------------------------------------

  /** A 16 km square; the side C-D is the one the scenario varies. */
  private static TestNetwork square() {
    return base().node("A", 0, 0).node("B", 4000, 0).node("C", 4000, 4000).node("D", 0, 4000);
  }

  private static void sides(TestNetwork n, int firstId) {
    n.track(firstId).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("A", "B");
    n.track(firstId + 1).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("B", "C");
    n.track(firstId + 2).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("D", "A");
  }

  private static boolean succeeds(TestNetwork n, RideType type, double d) {
    NetworkGraph g = n.build();
    GeneratorResult res = GENERATOR.generate(g, loop(n, 0, 0, d, type, 0.5, 5));
    if (res instanceof GeneratorResult.Success s) {
      GeneratorRequest r = loop(n, 0, 0, d, type, 0.5, 5);
      for (GeneratedRoute route : s.routes()) {
        RouteChecks.assertValid(g, r, P, route, "type " + type);
      }
      assertOracle(n.inputs(), r, s, "type " + type);
      return true;
    }
    return false;
  }

  @Test
  void roadNeverUsesAParallelUnpavedTrack() {
    TestNetwork n = square();
    sides(n, 1);
    n.track(4).wayKind(WayKind.TRACK).unpaved(true).via("C", "D", 2000, 4300);
    NetworkGraph g = n.build();
    // the only way round is the unpaved track: a road ride has no loop
    assertFalse(succeeds(n, RideType.ROAD, 16000));
    // with the paved road beside it, the road ride exists and never touches the track
    n.track(5).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("C", "D");
    NetworkGraph g2 = n.build();
    GeneratorRequest r = loop(n, 0, 0, 16000, RideType.ROAD, 0.5, 5);
    GeneratorResult.Success s =
        assertInstanceOf(GeneratorResult.Success.class, GENERATOR.generate(g2, r));
    for (GeneratedRoute route : s.routes()) {
      assertEquals(0, route.unpavedShare(), 1e-9);
    }
    assertTrue(g.edgeCount() < g2.edgeCount());
  }

  @Test
  void roadUsesAPavedCyclewayButNotAnUnknownSurfaceRiddenByGravelOnly() {
    TestNetwork n = square();
    sides(n, 1);
    n.track(4).wayKind(WayKind.CYCLEWAY).unpaved(false).path("C", "D");
    assertTrue(succeeds(n, RideType.ROAD, 16000));

    TestNetwork unknown = square();
    sides(unknown, 1);
    unknown.track(4, TrackKind.GRAVEL).path("C", "D"); // no way kind, no surface
    assertFalse(succeeds(unknown, RideType.ROAD, 16000));
    unknown.track(5, TrackKind.ROAD).path("C", "D");
    assertTrue(succeeds(unknown, RideType.ROAD, 16000));
  }

  @Test
  void gravelNeedsAGravelOrMixedTrackOnAPath() {
    TestNetwork n = square();
    sides(n, 1);
    n.track(4, TrackKind.ROAD).wayKind(WayKind.PATH).path("C", "D");
    assertFalse(succeeds(n, RideType.GRAVEL, 16000));
    n.track(5, TrackKind.MIXED).wayKind(WayKind.PATH).path("C", "D");
    assertTrue(succeeds(n, RideType.GRAVEL, 16000));
  }

  @Test
  void stepsAreNeverForGravelAndOnlyForMtbWhenAnMtbTrackRodeThem() {
    TestNetwork n = square();
    sides(n, 1);
    n.track(4, TrackKind.GRAVEL).wayKind(WayKind.STEPS).path("C", "D");
    assertFalse(succeeds(n, RideType.GRAVEL, 16000));
    assertFalse(succeeds(n, RideType.MTB, 16000));
    n.track(5, TrackKind.MTB).wayKind(WayKind.STEPS).path("C", "D");
    assertTrue(succeeds(n, RideType.MTB, 16000));
    assertFalse(succeeds(n, RideType.GRAVEL, 16000));
  }

  /** A hub S with a north ring ridden by gravel tracks and a south ring ridden by road tracks. */
  private static TestNetwork twoRings(int gravelTracks, int roadTracks, int mtbTracks) {
    TestNetwork n =
        base()
            .node("S", 0, 0)
            .node("N1", 4000, 1000)
            .node("N2", 4000, 5000)
            .node("N3", 0, 4000)
            .node("S1", 4000, -1000)
            .node("S2", 4000, -5000)
            .node("S3", 0, -4000);
    long id = 1;
    for (int i = 0; i < gravelTracks; i++) {
      n.track(id++, TrackKind.GRAVEL)
          .wayKind(WayKind.MINOR_ROAD)
          .unpaved(false)
          .path("S", "N1", "N2", "N3", "S");
    }
    for (int i = 0; i < roadTracks; i++) {
      n.track(id++, TrackKind.ROAD)
          .wayKind(WayKind.MINOR_ROAD)
          .unpaved(false)
          .path("S", "S1", "S2", "S3", "S");
    }
    for (int i = 0; i < mtbTracks; i++) {
      n.track(id++, TrackKind.MTB)
          .wayKind(WayKind.MINOR_ROAD)
          .unpaved(false)
          .path("S", "N1", "N2", "N3", "S");
    }
    return n;
  }

  private static double meanY(TestNetwork n, GeneratedRoute route) {
    double sum = 0;
    for (LatLon q : route.points()) {
      sum += n.yOf(q);
    }
    return sum / route.points().size();
  }

  @Test
  void theFamiliarityOfTheRequestedTypeFallsBackWhenTheNetworkHasTooFewTracksOfIt() {
    TestNetwork n = twoRings(30, 0, 3);
    NetworkGraph g = n.build();
    GeneratorRequest mtb = loop(n, 0, 0, 16200, RideType.MTB, 0.5, 5);
    GeneratorResult.Success sm =
        assertInstanceOf(GeneratorResult.Success.class, GENERATOR.generate(g, mtb));
    assertTrue(sm.familiarityFallback());
    GeneratorRequest gravel = loop(n, 0, 0, 16200, RideType.GRAVEL, 0.5, 5);
    GeneratorResult.Success sg =
        assertInstanceOf(GeneratorResult.Success.class, GENERATOR.generate(g, gravel));
    assertFalse(sg.familiarityFallback());
  }

  @Test
  void theSliderFollowsTheFamiliarityOfTheRequestedType() {
    TestNetwork n = twoRings(15, 15, 0);
    NetworkGraph g = n.build();
    GeneratorRequest gravel = loop(n, 0, 0, 16200, RideType.GRAVEL, 1.0, 5);
    GeneratorResult.Success sg =
        assertInstanceOf(GeneratorResult.Success.class, GENERATOR.generate(g, gravel));
    assertTrue(meanY(n, sg.routes().get(0)) > 0, "gravel ring is the north one");
    GeneratorRequest road = loop(n, 0, 0, 16200, RideType.ROAD, 1.0, 5);
    GeneratorResult.Success sr =
        assertInstanceOf(GeneratorResult.Success.class, GENERATOR.generate(g, road));
    assertTrue(meanY(n, sr.routes().get(0)) < 0, "road ring is the south one");
    assertOracle(n.inputs(), gravel, sg, "gravel");
    assertOracle(n.inputs(), road, sr, "road");
  }

  // ---- 20: the joins of the flow solution are re-checked (stand-in for the 160 degree join) ----

  @Test
  void aFlowSolutionWhoseJoinIsAUTurnIsRejectedAndTheSequentialFallbackTakesOver() {
    // the cheapest pair of disjoint paths is both carriageways of the dual carriageway, joined by
    // a 15 m link: a U-turn that only the walked windows see
    TestNetwork n = RouteGeneratorScenarioTest.dualCarriageway();
    NetworkGraph g = n.build();
    GeneratorRequest r = loop(n, 0, 0, 17000, RideType.ROAD, 0.5, 7);
    GeneratorResult res = GENERATOR.generate(g, r);
    GeneratorResult.Success s =
        assertInstanceOf(GeneratorResult.Success.class, res, res.toString());
    assertTrue(s.diagnostics().disjointJoinRejected() > 0, s.diagnostics().toString());
    assertTrue(s.diagnostics().disjointFallbacks() > 0, s.diagnostics().toString());
    assertOracle(n.inputs(), r, s, "dual carriageway");
  }
}
