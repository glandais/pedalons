package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.infrastructure.gpx.FakeElevationProducer;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The elevation tier is chosen per call; the test producer gives each tier its own flat relief. */
@QuarkusTest
class GpxPipelineTest {

  @Inject GpxPipeline gpxPipeline;

  @Test
  void process_fast_readsTheFastTier() {
    assertAllElevations(
        gpxPipeline.process(nantesLine(), "test", ElevationQuality.FAST),
        FakeElevationProducer.FAST_ELEVATION);
  }

  @Test
  void process_hd_readsTheHdTier() {
    assertAllElevations(
        gpxPipeline.process(nantesLine(), "test", ElevationQuality.HD),
        FakeElevationProducer.HD_ELEVATION);
  }

  private static void assertAllElevations(Path path, double expected) {
    assertTrue(path.getSize() >= 2);
    for (int i = 0; i < path.getSize(); i++) {
      assertEquals(expected, path.elevation(i), 1.0, "elevation of point " + i);
    }
  }

  /** About 2 km east of Nantes, with deliberately wrong elevations (0 m). */
  private static Path nantesLine() {
    List<CoordinatesElevation> coordinates = new ArrayList<>();
    for (int i = 0; i <= 20; i++) {
      coordinates.add(new LatLonElevation(47.2184, -1.5536 + i * 0.001, 0.0));
    }
    return PathJvm.fromCoordinates(coordinates);
  }
}
