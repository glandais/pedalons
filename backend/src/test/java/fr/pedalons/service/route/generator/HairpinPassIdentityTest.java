package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Design §12.13.2: the hairpin exemption needs one single pass of one track (ranks of its steps at
 * the cluster nodes follow each other), and a connector run is not broken by a piece too short to
 * have a bearing. Checker, {@link SearchTurns#pathOk} and {@link RawInputOracle} must agree.
 */
class HairpinPassIdentityTest {
  private static final GeneratorParameters P = GeneratorParameters.defaults();
  private static final double R = 17.8;

  private static double[] pol(double a) {
    return new double[] {R * Math.cos(Math.toRadians(a)), R * Math.sin(Math.toRadians(a))};
  }

  private static double[] arc(double a0, double a1) {
    List<Double> l = new ArrayList<>();
    for (double a = a0 + 10; a < a1 - 1e-9; a += 10) {
      l.add(R * Math.cos(Math.toRadians(a)));
      l.add(R * Math.sin(Math.toRadians(a)));
    }
    double[] out = new double[l.size()];
    for (int i = 0; i < out.length; i++) {
      out[i] = l.get(i);
    }
    return out;
  }

  /** A roundabout on the way S-J-ring; one track goes round it once on its way out and once back. */
  private static TestNetwork roundabout(boolean sameTrack) {
    double[] tin = pol(-70);
    double[] tout = pol(-110);
    double[] rx = pol(-45);
    double[] ry = pol(225);
    TestNetwork n = new TestNetwork(45, 5);
    n.node("S", 0, -3000)
        .node("J", 0, -80)
        .node("Tin", tin[0], tin[1])
        .node("Tout", tout[0], tout[1])
        .node("RX", rx[0], rx[1])
        .node("RY", ry[0], ry[1])
        .node("XE", 1000, -300)
        .node("YN", -1000, -300)
        .node("C", 0, 1500);
    n.edge("J", "Tin", 4.8, -40);
    n.edge("Tout", "J", -4.8, -40);
    n.edge("Tin", "RX", arc(-70, -45));
    n.edge("RX", "RY", arc(-45, 225));
    n.edge("RY", "Tout", arc(225, 250));
    n.edge("Tout", "Tin", arc(250, 290));
    if (sameTrack) {
      n.track(4).path("S", "J", "Tin", "RX", "RY", "YN", "C", "XE", "RX", "RY", "Tout", "J", "S");
    } else {
      n.track(4).path("S", "J", "Tin", "RX", "RY", "YN", "C", "XE");
      n.track(5).path("XE", "RX", "RY", "Tout", "J", "S");
    }
    n.track(7).path("RY", "Tout", "Tin", "RX");
    n.track(8).path("S", "J", "Tin", "RX", "XE");
    n.track(9).path("XE", "C", "YN", "RY", "Tout", "J", "S");
    return n;
  }

  private static List<String> oracle(
      TestNetwork n, QueryGraph qg, int[] st, double start, double dist) {
    List<LatLon> pts = new ArrayList<>();
    List<RouteStep> steps = new ArrayList<>();
    for (int i = 0; i < st.length; i++) {
      List<LatLon> gg = qg.geometryLatLon(st[i]);
      pts.addAll(i == 0 ? gg : gg.subList(1, gg.size()));
      steps.add(new RouteStep(qg.parentEdge(st[i] >>> 1), (st[i] & 1) == 0));
    }
    GeneratedRoute gr = new GeneratedRoute(pts, dist, 0, 0, null, 0, 0, 0, 0, steps);
    return RawInputOracle.violations(
        n.inputs(),
        new GeneratorRequest(n.latLon(0, start), null, null, dist, 0.5, RideType.ROAD, 1),
        gr,
        P);
  }

  @Test
  void aTrackThatWentInAtOneNodeOnAFirstPassAndOutAtAnotherOnASecondMadeNoHairpin() {
    for (boolean same : new boolean[] {true, false}) {
      TestNetwork n = roundabout(same);
      NetworkGraph g = n.build();
      GeneratorRequest r =
          new GeneratorRequest(n.latLon(0, -3000), null, null, 6000, 0.5, RideType.ROAD, 1);
      QueryGraph qg = RouteChecks.queryGraph(g, r, P);
      int[] st = n.route(g, "S", "J", "Tin", "RX", "RY", "Tout", "J", "S");
      double dist = 0;
      for (int s : st) {
        dist += qg.length(s >>> 1);
      }
      GuaranteeReport rep = RouteGuarantees.check(qg, qg.snapNode(0), qg.snapNode(0), 6000, st, P);
      String label = "same track " + same + ": ";
      assertTrue(rep.violations().contains(Violation.SHARP_TURN), label + rep.violations());
      assertFalse(RouteGuarantees.hairpinTheTeamRides(qg, st, 1, 4), label + "hairpin");
      assertFalse(SearchTurns.pathOk(qg, st, 0, st.length, P.maxTurnDeg()), label + "pathOk");
      List<String> raw = oracle(n, qg, st, -3000, dist);
      assertTrue(raw.stream().anyMatch(v -> v.contains("turn of")), label + raw);
    }
  }

  /** A 20-25 m straight perpendicular connector drawn with a duplicate vertex, jitter or a back-zig. */
  private static TestNetwork connector(double c, int variant) {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("W", -3000, 0)
            .node("X", 0, 0)
            .node("Z", c, 0)
            .node("E", 3000, 0)
            .node("S1", 3000, -5000)
            .node("S2", -3000, -5000)
            .node("Y1", 0, 2000)
            .node("Y2", c, 2000);
    if (variant == 1) {
      n.edge("Y1", "Y2", c / 2, 2000, c / 2, 2000);
    }
    if (variant == 2) {
      n.edge("Y1", "Y2", c / 2, 2000, c / 2 + 0.05, 2000.08);
    }
    if (variant == 3) {
      n.edge("Y1", "Y2", c / 2, 2000, c / 2 - 0.3, 2000.3);
    }
    n.track(1).path("W", "X");
    n.track(2).path("X", "Z", "E");
    n.track(3).path("E", "S1", "S2", "W");
    n.track(4).path("X", "Y1", "Y2", "Z");
    return n;
  }

  @Test
  void aShortPieceDoesNotBreakAStraightConnectorRun() {
    String[] names = {"plain", "duplicate vertex", "0.1 m jitter", "0.4 m back-zig"};
    for (double c : new double[] {20, 25}) {
      for (int v = 0; v < 4; v++) {
        TestNetwork n = connector(c, v);
        NetworkGraph g = n.build();
        GeneratorRequest r =
            new GeneratorRequest(n.latLon(-3000, 0), null, null, 26000, 0.5, RideType.ROAD, 1);
        QueryGraph qg = RouteChecks.queryGraph(g, r, P);
        int[] st = n.route(g, "W", "X", "Y1", "Y2", "Z", "E", "W");
        double len = 0;
        for (int s : st) {
          len += g.length(s >>> 1);
        }
        GuaranteeReport rep = RouteGuarantees.check(qg, qg.snapNode(0), qg.snapNode(0), len, st, P);
        String label = "connector " + c + " m, " + names[v] + ": ";
        assertTrue(rep.violations().contains(Violation.SHARP_TURN), label + rep.violations());
        List<LatLon> pts = new ArrayList<>();
        List<RouteStep> steps = new ArrayList<>();
        for (int i = 0; i < st.length; i++) {
          List<LatLon> gg = qg.geometryLatLon(st[i]);
          pts.addAll(i == 0 ? gg : gg.subList(1, gg.size()));
          steps.add(new RouteStep(qg.parentEdge(st[i] >>> 1), (st[i] & 1) == 0));
        }
        GeneratedRoute gr = new GeneratedRoute(pts, len, 0, 0, null, 0, 0, 0, 0, steps);
        List<String> raw =
            RawInputOracle.violations(
                n.inputs(),
                new GeneratorRequest(n.latLon(-3000, 0), null, null, len, 0.5, RideType.ROAD, 1),
                gr,
                P);
        assertTrue(raw.stream().anyMatch(s -> s.contains("turn of")), label + raw);
      }
    }
  }

  /** A 10 m gap; track 4 rides X-Y1-Y2 and Y1-Y2-Z with a jump (no shared node) in between. */
  private static TestNetwork jumping(int jump) {
    double c = 10;
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("W", -3000, 0)
            .node("X", 0, 0)
            .node("Z", c, 0)
            .node("E", 3000, 0)
            .node("S1", 3000, -5000)
            .node("S2", -3000, -5000)
            .node("Y1", 0, 2000)
            .node("Y2", c, 2000);
    n.track(1).path("W", "X");
    n.track(2).path("X", "Z", "E");
    n.track(3).path("E", "S1", "S2", "W");
    if (jump == 0) {
      n.track(4).path("X", "Y1", "Y2").path("E", "S1").path("Y1", "Y2", "Z");
    } else if (jump == 1) {
      n.track(4).path("X", "Y1").path("Y1", "Y2").path("S2", "W").path("Y1", "Y2", "Z");
    } else {
      n.track(4).path("X", "Y1", "Y2", "Z"); // one real pass: accepted
    }
    return n;
  }

  @Test
  void aJumpInTheTracksRideSeparatesTwoPasses() {
    for (int jump = 0; jump < 3; jump++) {
      TestNetwork n = jumping(jump);
      NetworkGraph g = n.build();
      GeneratorRequest r =
          new GeneratorRequest(n.latLon(-3000, 0), null, null, 26000, 0.5, RideType.ROAD, 1);
      QueryGraph qg = RouteChecks.queryGraph(g, r, P);
      String[] names =
          java.util.Arrays.stream(new String[] {"W", "X", "Y1", "Y2", "Z", "E", "S1", "S2", "W"})
              .filter(x -> n.nodeId(g, x) >= 0)
              .toArray(String[]::new);
      int[] st = n.route(g, names);
      double len = 0;
      for (int s : st) {
        len += g.length(s >>> 1);
      }
      GuaranteeReport rep = RouteGuarantees.check(qg, qg.snapNode(0), qg.snapNode(0), len, st, P);
      boolean pathOk = SearchTurns.pathOk(qg, st, 0, st.length, P.maxTurnDeg());
      String label = "jump case " + jump + ": ";
      if (jump < 2) {
        assertTrue(rep.violations().contains(Violation.SHARP_TURN), label + rep.violations());
        assertFalse(pathOk, label + "pathOk");
        List<String> raw = oracle(n, qg, st, 0, len);
        assertTrue(raw.stream().anyMatch(v -> v.contains("turn of")), label + raw);
      } else {
        assertFalse(rep.violations().contains(Violation.SHARP_TURN), label + rep.violations());
        assertTrue(pathOk, label + "pathOk");
      }
    }
  }
}
