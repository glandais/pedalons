package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;
import org.junit.jupiter.api.Test;

/**
 * 200 cases on networks that look like api 1.7 data (design §12.9, review M6). Every route
 * returned must pass the checker re-run from the test side <em>and</em> the raw-input oracle, then
 * the success rate and the candidates per family are measured per request class and held to
 * floors: the old random networks (one track per edge, no partial edge, no roundabout) could not
 * have shown B1, B2, M1, M2 or M4.
 */
class RealisticRouteGeneratorPropertyTest {
  private static final GeneratorParameters P = GeneratorParameters.defaults();
  private static final int CASES = 200;

  /**
   * Admitted road within D/2 that a request needs to count (design §12.9 says 1.2 D). At 1.2 D the
   * measured success rates were 25 % (loop), 31 % (cafe) and 76 % (one-way): 1.2 D of road is
   * necessary but far from sufficient for a loop without reuse in a network of about 10 km, so the
   * floors below are held on the requests with 3 D.
   *
   * <p>Owner decision (13 November 2026, design §12.13): the eligibility rule stays at 3 D and the
   * floors at 80 % of the measured values until they are recalibrated on the real-data bench; do
   * not tighten them, nor loosen them, before that.
   */
  private static final double ELIGIBLE_ROAD_FACTOR = 3.0;

  private static final String[] CLASSES = {"loop", "cafe", "one-way"};

  /** Measured tallies of one request class. */
  private static final class Tally {
    int eligible;
    int success;
    int loopCandidates;
    int polygonCandidates;
    final List<Integer> loopCounts = new ArrayList<>();
    final List<Integer> polygonCounts = new ArrayList<>();
    final java.util.Map<Violation, Integer> rejections = new java.util.EnumMap<>(Violation.class);
    final java.util.Map<GeneratorFailure, Integer> failures =
        new java.util.EnumMap<>(GeneratorFailure.class);
  }

  private static double median(List<Integer> values) {
    if (values.isEmpty()) {
      return 0;
    }
    List<Integer> sorted = new ArrayList<>(values);
    Collections.sort(sorted);
    return sorted.get(sorted.size() / 2);
  }

  @Test
  void everyRouteOnRealisticNetworksIsValidAndTheFamiliesAreNotEmpty() {
    Random outer = new Random(20261114L);
    RouteGenerator generator = new RouteGenerator(P);
    Tally[] tallies = {new Tally(), new Tally(), new Tally()};
    for (int c = 0; c < CASES; c++) {
      Random r = new Random(outer.nextLong());
      RealisticNetworks.Generated net = RealisticNetworks.generate(r);
      NetworkGraph g = NetworkGraphBuilder.build(net.tracks(), NetworkParameters.defaults());
      int cls = c % 3;
      Tally tally = tallies[cls];
      String label = "case " + c + " (" + CLASSES[cls] + ")";
      RideType type = RideType.values()[r.nextInt(3)];
      Bearing8 bearing = r.nextBoolean() ? Bearing8.values()[r.nextInt(8)] : null;
      double familiarity = r.nextDouble();
      long seed = r.nextLong();
      double sx = net.teamX();
      double sy = net.teamY();
      LatLon start = net.teamLocation();
      List<double[]> nodes = net.truth().nodes;
      if (r.nextDouble() >= 0.8) {
        double[] p = nodes.get(r.nextInt(nodes.size()));
        sx = p[0];
        sy = p[1];
        start = net.projection().toLatLon(sx, sy);
      }
      LatLon end = null;
      double d;
      if (cls == 0) {
        d = 15_000 + r.nextDouble() * 35_000;
      } else if (cls == 1) {
        d = 15_000 + r.nextDouble() * 35_000;
        end = nodeAt(r, net, sx, sy, 2000, 6000);
      } else {
        end = nodeAt(r, net, sx, sy, 4000, 12_000);
        double chord =
            end == null
                ? 0
                : Math.hypot(
                    net.projection().toX(end.lat(), end.lon()) - sx,
                    net.projection().toY(end.lat(), end.lon()) - sy);
        d = Math.min(40_000, Math.max(15_000, chord / (0.6 + 0.25 * r.nextDouble())));
      }
      if (cls != 0 && end == null) {
        continue;
      }
      GeneratorRequest request =
          new GeneratorRequest(start, end, bearing, d, familiarity, type, seed);
      if (net.admittedNear(sx, sy, d / 2, type) < ELIGIBLE_ROAD_FACTOR * d) {
        continue;
      }
      tally.eligible++;
      GeneratorResult result = generator.generate(g, request);
      if (!(result instanceof GeneratorResult.Success success)) {
        tally.failures.merge(((GeneratorResult.Failure) result).reason(), 1, Integer::sum);
        result
            .diagnostics()
            .rejections()
            .forEach((k, v) -> tally.rejections.merge(k, v, Integer::sum));
        continue;
      }
      tally.success++;
      GeneratorDiagnostics diag = success.diagnostics();
      diag.rejections().forEach((k, v) -> tally.rejections.merge(k, v, Integer::sum));
      if (diag.loopCandidates() >= 1) {
        tally.loopCandidates++;
      }
      if (diag.polygonCandidates() >= 1) {
        tally.polygonCandidates++;
      }
      tally.loopCounts.add(diag.loopCandidates());
      tally.polygonCounts.add(diag.polygonCandidates());
      for (int i = 0; i < success.routes().size(); i++) {
        GeneratedRoute route = success.routes().get(i);
        RouteChecks.assertValid(g, request, P, route, label + " route " + i);
        List<String> raw = RawInputOracle.violations(net.tracks(), request, route, P);
        assertTrue(raw.isEmpty(), label + " route " + i + " raw oracle: " + raw);
      }
    }
    System.out.println(
        "class     eligible success  loop>=1  polygon>=1  median loop/polygon candidates");
    for (int i = 0; i < 3; i++) {
      Tally t = tallies[i];
      System.out.printf(
          "%-8s %8d %7d %8d %10d  %.0f / %.0f   rejections %s failures %s%n",
          CLASSES[i],
          t.eligible,
          t.success,
          t.loopCandidates,
          t.polygonCandidates,
          median(t.loopCounts),
          median(t.polygonCounts),
          t.rejections,
          t.failures);
    }
    assertFloors(tallies);
  }

  private static LatLon nodeAt(
      Random r, RealisticNetworks.Generated net, double sx, double sy, double min, double max) {
    List<double[]> ok = new ArrayList<>();
    for (RealisticNetworks.TEdge e : net.truth().edges) {
      if (e.isPrivate || e.ridden.isEmpty()) {
        continue;
      }
      for (int n : new int[] {e.a, e.b}) {
        double[] p = net.truth().nodes.get(n);
        double dist = Math.hypot(p[0] - sx, p[1] - sy);
        if (dist >= min && dist <= max) {
          ok.add(p);
        }
      }
    }
    if (ok.isEmpty()) {
      return null;
    }
    double[] p = ok.get(r.nextInt(ok.size()));
    return net.projection().toLatLon(p[0], p[1]);
  }

  /**
   * Floors: 80 % of the values measured on 13 November 2026 (loop 13 of 20, cafe 18 of 25, one-way
   * 47 of 61 eligible requests succeeded; the families gave candidates in 13/11 of 20, 18/14 of 25
   * and 45/39 of 61 cases). The design's first guesses (0.70 / 0.60 / 0.60) were not met by the
   * cafe polygon family (0.56): see the report.
   */
  private static void assertFloors(Tally[] t) {
    double[][] floors = {
      // success, loop candidates, polygon candidates (shares of the eligible requests)
      {0.50, 0.50, 0.40},
      {0.55, 0.55, 0.40},
      {0.60, 0.55, 0.50},
    };
    for (int i = 0; i < 3; i++) {
      Tally tally = t[i];
      assertTrue(
          tally.eligible >= 15, CLASSES[i] + ": only " + tally.eligible + " eligible requests");
      double n = tally.eligible;
      assertTrue(
          tally.success / n >= floors[i][0],
          CLASSES[i] + " success " + tally.success + "/" + tally.eligible);
      assertTrue(
          tally.loopCandidates / n >= floors[i][1],
          CLASSES[i] + " loop family " + tally.loopCandidates + "/" + tally.eligible);
      assertTrue(
          tally.polygonCandidates / n >= floors[i][2],
          CLASSES[i] + " polygon family " + tally.polygonCandidates + "/" + tally.eligible);
    }
    assertTrue(median(t[0].loopCounts) >= 3, "median loop candidates for loops");
    assertTrue(median(t[0].polygonCounts) >= 3, "median polygon candidates for loops");
  }
}
