package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

/** The stop signal of {@link RouteGenerator} (API-198, lot 3 plan §3.6). */
class RouteGeneratorStopTest {
  private static final List<TrackInput> TRACKS =
      GridNetwork.tracks(10, 10, 1000, 0, 0, 0, 45, 5, 3);
  private static final NetworkGraph GRAPH =
      NetworkGraphBuilder.build(TRACKS, NetworkParameters.defaults());
  private static final RouteGenerator GENERATOR = new RouteGenerator();

  private static GeneratorRequest request(long seed) {
    return new GeneratorRequest(
        new LatLon(45.0, 5.0), null, null, 30_000, 0.5, RideType.ROAD, seed);
  }

  @Test
  void aSignalThatIsAlwaysOn_stopsTheRun() {
    assertThrows(
        GeneratorStoppedException.class, () -> GENERATOR.generate(GRAPH, request(1), () -> true));
  }

  @Test
  void aStopAfterSomePolls_stopsTheRun() {
    AtomicInteger polls = new AtomicInteger();
    assertThrows(
        GeneratorStoppedException.class,
        () -> GENERATOR.generate(GRAPH, request(1), () -> polls.incrementAndGet() > 3));
    assertTrue(polls.get() > 3);
  }

  @Test
  void aSignalThatNeverFires_givesTheSameResultAsTheDefault() {
    for (long seed : new long[] {1, 2, 3}) {
      GeneratorResult plain = GENERATOR.generate(GRAPH, request(seed));
      GeneratorResult withSignal = GENERATOR.generate(GRAPH, request(seed), () -> false);
      assertInstanceOf(GeneratorResult.Success.class, plain);
      List<GeneratedRoute> a = ((GeneratorResult.Success) plain).routes();
      List<GeneratedRoute> b = ((GeneratorResult.Success) withSignal).routes();
      assertEquals(a.size(), b.size());
      for (int i = 0; i < a.size(); i++) {
        assertEquals(a.get(i).points(), b.get(i).points());
        assertEquals(a.get(i).distanceM(), b.get(i).distanceM());
      }
    }
  }
}
