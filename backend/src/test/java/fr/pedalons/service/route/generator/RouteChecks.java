package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;

/**
 * Test-side re-check of a generated route: the steps are mapped back to states of an independently
 * rebuilt query graph and handed to {@link RouteGuarantees}, so a route is judged by the checker
 * and not by the search that produced it.
 */
final class RouteChecks {
  private RouteChecks() {}

  static QueryGraph queryGraph(NetworkGraph g, GeneratorRequest r, GeneratorParameters p) {
    List<Snap> snaps = new ArrayList<>();
    QueryGraph plain = QueryGraph.of(g);
    java.util.function.IntPredicate admitted = e -> EdgeWeights.admitted(plain, e, r.type());
    snaps.add(Snapper.snap(g, r.start(), p.snapMaxM(), admitted));
    if (r.end() != null) {
      snaps.add(Snapper.snap(g, r.end(), p.snapMaxM(), admitted));
    }
    return QueryGraph.create(g, snaps, p.snapToNodeM());
  }

  static int endNode(QueryGraph qg, GeneratorRequest r) {
    return r.end() == null ? qg.snapNode(0) : qg.snapNode(1);
  }

  /** The states of a route given as parent-edge steps, walking from {@code startNode}. */
  static int[] states(QueryGraph qg, int startNode, List<RouteStep> steps) {
    int[] states = new int[steps.size()];
    int cur = startNode;
    for (int i = 0; i < states.length; i++) {
      RouteStep step = steps.get(i);
      int[] pieces = qg.pieces(step.edgeId());
      int[] candidates = pieces != null ? pieces : new int[] {step.edgeId()};
      int found = -1;
      for (int c : candidates) {
        int from = step.forward() ? qg.edgeU(c) : qg.edgeV(c);
        if (from == cur) {
          found = 2 * c + (step.forward() ? 0 : 1);
          break;
        }
      }
      assertNotEquals(-1, found, "step " + i + " does not leave node " + cur);
      states[i] = found;
      cur = qg.head(found);
    }
    return states;
  }

  /** Re-checks a returned route against every hard guarantee and its own figures. */
  static GuaranteeReport assertValid(
      NetworkGraph g,
      GeneratorRequest r,
      GeneratorParameters p,
      GeneratedRoute route,
      String label) {
    QueryGraph qg = queryGraph(g, r, p);
    int start = qg.snapNode(0);
    int end = endNode(qg, r);
    int[] states = states(qg, start, route.steps());
    GuaranteeReport report = RouteGuarantees.check(qg, start, end, r.distanceM(), states, p);
    assertTrue(report.ok(), label + ": " + report.violations());
    assertEquals(route.distanceM(), report.lengthM(), 1e-6, label);
    assertEquals(route.sharedM(), report.sharedM(), 1e-6, label);
    assertEquals(route.crossings(), report.crossings(), label);
    assertTrue(
        Math.abs(route.distanceM() - r.distanceM()) <= 0.10 * r.distanceM() + 1e-6,
        label + ": distance " + route.distanceM());
    assertTrue(route.sharedM() <= 0.15 * r.distanceM() + 1e-6, label + ": shared");
    assertTrue(route.crossings() <= 2, label + ": crossings");
    // the geometry is what is ridden: it starts and ends on the snapped nodes ...
    double first = TestNetwork.haversine(qg.nodeLatLon(start), route.points().get(0));
    assertTrue(first < 2, label + ": first point " + first + " m from the snapped start");
    double last =
        TestNetwork.haversine(qg.nodeLatLon(end), route.points().get(route.points().size() - 1));
    assertTrue(last < 2, label + ": last point " + last + " m from the snapped end");
    assertGeometryOnTheSteps(qg, route, label);
    // the steps join: the last point of one is less than 1 m from the first of the next ...
    for (int i = 0; i + 1 < states.length; i++) {
      List<LatLon> a = qg.geometryLatLon(states[i]);
      List<LatLon> b = qg.geometryLatLon(states[i + 1]);
      double gap = TestNetwork.haversine(a.get(a.size() - 1), b.get(0));
      assertTrue(gap < 1, label + ": gap of " + gap + " m between steps " + i + " and " + (i + 1));
    }
    // ... and the polyline is as long as the distance it claims
    double polyline = 0;
    for (int i = 1; i < route.points().size(); i++) {
      polyline += TestNetwork.haversine(route.points().get(i - 1), route.points().get(i));
    }
    assertTrue(
        Math.abs(polyline - route.distanceM()) <= 0.01 * route.distanceM() + 5,
        label + ": polyline " + polyline + " m for a distance of " + route.distanceM());
    return report;
  }

  /**
   * Every point of the route lies on the geometry of one of its steps (plan §2.1: every metre of
   * the route is on an edge), and consecutive points never jump further than the longest step.
   */
  private static void assertGeometryOnTheSteps(QueryGraph qg, GeneratedRoute route, String label) {
    NetworkGraph base = qg.base();
    LocalProjection projection = qg.projection();
    java.util.Set<Integer> edges = new java.util.HashSet<>();
    double longest = 0;
    for (RouteStep step : route.steps()) {
      edges.add(step.edgeId());
      longest = Math.max(longest, base.length(step.edgeId()));
    }
    List<LatLon> points = route.points();
    LatLon previous = null;
    for (int i = 0; i < points.size(); i++) {
      LatLon q = points.get(i);
      double x = projection.toX(q.lat(), q.lon());
      double y = projection.toY(q.lat(), q.lon());
      double best = Double.POSITIVE_INFINITY;
      for (int e : edges) {
        best =
            Math.min(
                best,
                NetworkGraphBuilder.distanceToRange(
                    x, y, base.geometryX(e), base.geometryY(e), 0, base.geometryX(e).length));
      }
      assertTrue(best < 3, label + ": point " + i + " is " + best + " m from every step");
      if (previous != null) {
        double gap = TestNetwork.haversine(previous, q);
        assertTrue(gap <= longest + 1, label + ": jump of " + gap + " m at point " + i);
      }
      previous = q;
    }
  }

  /**
   * Length of the edges ridden by both routes on the query graph (the pieces of the edges cut at S
   * and E count for their own length, not for their parent's), in metres.
   */
  static double sharedOnQueryGraph(
      NetworkGraph g,
      GeneratorRequest r,
      GeneratorParameters p,
      GeneratedRoute a,
      GeneratedRoute b) {
    QueryGraph qg = queryGraph(g, r, p);
    java.util.Set<Integer> in = new java.util.HashSet<>();
    for (int s : states(qg, qg.snapNode(0), a.steps())) {
      in.add(s >>> 1);
    }
    java.util.Set<Integer> both = new java.util.HashSet<>();
    for (int s : states(qg, qg.snapNode(0), b.steps())) {
      if (in.contains(s >>> 1)) {
        both.add(s >>> 1);
      }
    }
    double total = 0;
    for (int e : both) {
      total += qg.length(e);
    }
    return total;
  }

  /** Length of the edges ridden by both routes, in metres. */
  static double sharedBetween(NetworkGraph g, GeneratedRoute a, GeneratedRoute b) {
    java.util.Set<Integer> in = new java.util.HashSet<>();
    for (RouteStep s : a.steps()) {
      in.add(s.edgeId());
    }
    java.util.Set<Integer> both = new java.util.HashSet<>();
    for (RouteStep s : b.steps()) {
      if (in.contains(s.edgeId())) {
        both.add(s.edgeId());
      }
    }
    double total = 0;
    for (int e : both) {
      total += g.length(e);
    }
    return total;
  }
}
