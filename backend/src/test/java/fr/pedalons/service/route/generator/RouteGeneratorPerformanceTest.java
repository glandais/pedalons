package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

/**
 * Performance on a 160 x 160 grid at 500 m (about 50 900 edges): the graph build, then one {@code
 * generate}. The wall-clock assertions are opt-in ({@code -Dgenerator.perf.strict=true}): the suite
 * shares a JVM with the Quarkus tests on shared CI runners, where a GC pause would fail the build
 * without any code change. Without the flag the timings are only printed. If the one second
 * assertion fails, reduce {@code turningPoints} / {@code polygonEvaluations} in {@link GeneratorParameters}
 * or bound pass 1 of the disjoint-paths search before touching anything else (design §7.4).
 */
@Tag("perf")
class RouteGeneratorPerformanceTest {
  private static final boolean STRICT = Boolean.getBoolean("generator.perf.strict");

  @Test
  void buildingA50kEdgeGraphTakesLessThanFiveSeconds() {
    List<TrackInput> tracks = GridNetwork.tracks(160, 160, 500, 0, 0.05, 10, 45, 5, 1);
    long start = System.nanoTime();
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    long ms = (System.nanoTime() - start) / 1_000_000;
    System.out.println(
        "graph build: " + ms + " ms, " + g.edgeCount() + " edges, " + g.nodeCount() + " nodes");
    assertTrue(g.edgeCount() > 45_000);
    assertTrue(!STRICT || ms < 5_000, "build took " + ms + " ms");
  }

  @Test
  void aFiftyKilometreLoopOnTheBigGridTakesLessThanOneSecond() {
    List<TrackInput> tracks = GridNetwork.tracks(160, 160, 500, 0, 0.05, 10, 45, 5, 1);
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    LatLon centre = new LocalProjection(45, 5).toLatLon(0, 0);
    GeneratorRequest request =
        new GeneratorRequest(centre, null, Bearing8.NE, 50_000, 0.7, RideType.ROAD, 11);
    RouteGenerator generator = new RouteGenerator();

    // warm-up: class loading and JIT must not count
    assertInstanceOf(GeneratorResult.Success.class, generator.generate(g, request));

    long start = System.nanoTime();
    GeneratorResult result = generator.generate(g, request);
    long ms = (System.nanoTime() - start) / 1_000_000;
    System.out.println("generate: " + ms + " ms, " + result.diagnostics());
    GeneratorResult.Success success = assertInstanceOf(GeneratorResult.Success.class, result);
    assertFalse(success.routes().isEmpty());
    for (GeneratedRoute route : success.routes()) {
      RouteChecks.assertValid(g, request, GeneratorParameters.defaults(), route, "50 km loop");
    }
    assertTrue(!STRICT || ms < 1_000, "generate took " + ms + " ms");
  }

  /**
   * A town: the same topology cut into edges of 45 m, shorter than the 50 m turn window, so every
   * relaxation reads the walked windows (review: the 500 m grid never does). The distance scales
   * with the spacing.
   */
  @Test
  void aLoopOnAGridOfShortEdgesTakesLessThanTwoSeconds() {
    List<TrackInput> tracks = GridNetwork.tracks(120, 120, 45, 0, 0.05, 10, 45, 5, 1);
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    LatLon centre = new LocalProjection(45, 5).toLatLon(0, 0);
    GeneratorRequest request =
        new GeneratorRequest(centre, null, Bearing8.NE, 4_500, 0.7, RideType.ROAD, 11);
    RouteGenerator generator = new RouteGenerator();
    generator.generate(g, request); // warm-up

    long start = System.nanoTime();
    GeneratorResult result = generator.generate(g, request);
    long ms = (System.nanoTime() - start) / 1_000_000;
    System.out.println("generate (45 m edges): " + ms + " ms, " + result.diagnostics());
    assertTrue(!STRICT || ms < 2_000, "generate took " + ms + " ms");
  }
}
