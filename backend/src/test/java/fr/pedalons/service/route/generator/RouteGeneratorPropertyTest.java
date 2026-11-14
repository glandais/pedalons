package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;
import org.junit.jupiter.api.Test;

/**
 * 300 random networks and requests (design §7.3). Whatever the generator returns must pass the
 * checker re-run from the test side, stay within the distance, tail and crossing bounds, differ
 * from its siblings, and be the same twice. A failure message carries the case index.
 */
class RouteGeneratorPropertyTest {
  private static final GeneratorParameters P = GeneratorParameters.defaults();
  private static final int CASES = 300;

  private static GeneratorRequest randomRequest(
      Random r, LocalProjection proj, RandomNetworks.Generated net) {
    // the start is usually on the network, sometimes up to 1.5 km beyond its edge
    double x = (r.nextDouble() * 2 - 1) * (net.halfWidthM() + (r.nextInt(5) == 0 ? 1500 : 0));
    double y = (r.nextDouble() * 2 - 1) * (net.halfHeightM() + (r.nextInt(5) == 0 ? 1500 : 0));
    LatLon start = proj.toLatLon(x, y);
    LatLon end = null;
    if (r.nextBoolean()) {
      double angle = r.nextDouble() * 2 * Math.PI;
      double d = r.nextDouble() * 8000;
      end = proj.toLatLon(x + d * Math.sin(angle), y + d * Math.cos(angle));
    }
    Bearing8 bearing = r.nextBoolean() ? Bearing8.values()[r.nextInt(8)] : null;
    double distance = 8000 + r.nextDouble() * 32000;
    double familiarity = r.nextDouble();
    RideType type = RideType.values()[r.nextInt(3)];
    return new GeneratorRequest(start, end, bearing, distance, familiarity, type, r.nextLong());
  }

  @Test
  void everyRouteReturnedOnRandomNetworksHonoursTheGuarantees() {
    Random outer = new Random(20261113L);
    LocalProjection proj = new LocalProjection(45, 5);
    RouteGenerator generator = new RouteGenerator(P);
    int successes = 0;
    int routes = 0;
    for (int c = 0; c < CASES; c++) {
      Random r = new Random(outer.nextLong());
      RandomNetworks.Generated net = RandomNetworks.generate(r);
      NetworkGraph g = NetworkGraphBuilder.build(net.tracks(), NetworkParameters.defaults());
      GeneratorRequest request = randomRequest(r, proj, net);
      String label = "case " + c;
      GeneratorResult result = generator.generate(g, request);
      if (!(result instanceof GeneratorResult.Success success)) {
        continue;
      }
      successes++;
      assertTrue(success.routes().size() <= P.maxResults(), label);
      for (int i = 0; i < success.routes().size(); i++) {
        GeneratedRoute route = success.routes().get(i);
        routes++;
        GuaranteeReport report =
            RouteChecks.assertValid(g, request, P, route, label + " route " + i);
        List<String> raw = RawInputOracle.violations(net.tracks(), request, route, P);
        assertTrue(raw.isEmpty(), label + " route " + i + " raw oracle: " + raw);
        // The steps are parent edges of the NetworkGraph and follow each other: the head of one is
        // the tail of the next (the distance itself is checked on the query graph by RouteChecks).
        List<RouteStep> steps = route.steps();
        for (int k = 0; k + 1 < steps.size(); k++) {
          RouteStep a = steps.get(k);
          RouteStep b = steps.get(k + 1);
          if (a.edgeId() == b.edgeId() && a.forward() == b.forward()) {
            continue; // two pieces of one edge split at S and E (a close end on the start's edge)
          }
          int head = a.forward() ? g.edgeV(a.edgeId()) : g.edgeU(a.edgeId());
          int tail = b.forward() ? g.edgeU(b.edgeId()) : g.edgeV(b.edgeId());
          assertEquals(head, tail, label + ": steps " + k + " and " + (k + 1) + " are not joined");
        }
        assertEquals(report.lengthM(), route.distanceM(), 1e-6, label);
        for (int j = i + 1; j < success.routes().size(); j++) {
          GeneratedRoute other = success.routes().get(j);
          double shared = RouteChecks.sharedOnQueryGraph(g, request, P, route, other);
          double shorter = Math.min(route.distanceM(), other.distanceM());
          assertTrue(shared / shorter < 0.5 + 0.05, label + ": routes " + i + " and " + j);
        }
      }
      // determinism: the same request gives equal results
      assertEquals(
          success.routes(),
          ((GeneratorResult.Success) generator.generate(g, request)).routes(),
          label);
      if (c % 10 == 0) {
        // and a graph built from the same tracks in another order gives the same routes
        List<TrackInput> shuffled = new ArrayList<>(net.tracks());
        Collections.shuffle(shuffled, new Random(c));
        NetworkGraph g2 = NetworkGraphBuilder.build(shuffled, NetworkParameters.defaults());
        GeneratorResult again = generator.generate(g2, request);
        assertTrue(again instanceof GeneratorResult.Success, label + ": shuffled");
        assertEquals(success.routes(), ((GeneratorResult.Success) again).routes(), label);
      }
    }
    System.out.println(
        "property test: " + successes + " of " + CASES + " cases gave " + routes + " routes");
    assertTrue(successes >= CASES / 5, "only " + successes + " cases produced a route");
  }
}
