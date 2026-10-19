package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.infrastructure.gpx.FakeElevationProducer;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.ElevationProvider;
import io.github.glandais.elevation.ElevationProviderConfig;
import io.github.glandais.elevation.ElevationProviderJvm;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.elevation.RawTile;
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

  @Test
  void processWithClimb_keepsTheSamePointsAndTheReportedAscent() {
    Path source = nantesLine();
    GpxPipeline.Processed reported =
        gpxPipeline.processReported(source, "test", ElevationQuality.FAST);
    GpxPipeline.ProcessedWithClimb withClimb =
        gpxPipeline.processWithClimb(source, "test", ElevationQuality.FAST);

    Path path = withClimb.processed().path();
    assertEquals(reported.path().getSize(), path.getSize());
    for (int i = 0; i < path.getSize(); i++) {
      assertEquals(reported.path().latitudeDeg(i), path.latitudeDeg(i), 1e-9);
      assertEquals(reported.path().longitudeDeg(i), path.longitudeDeg(i), 1e-9);
      assertEquals(reported.path().elevation(i), path.elevation(i), 1e-9);
    }
    assertEquals(reported.path().getReportedElevationGain(), path.getReportedElevationGain(), 1e-9);
    assertEquals(reported.fallbackAfterErrorKm(), withClimb.processed().fallbackAfterErrorKm());

    double[] climb = withClimb.climb();
    assertEquals(path.getSize(), climb.length);
    assertEquals(0.0, climb[0], 1e-9);
    for (int i = 1; i < climb.length; i++) {
      assertTrue(climb[i] >= climb[i - 1], "climb is non-decreasing at " + i);
    }
    assertEquals(path.getReportedElevationGain(), climb[climb.length - 1], 1e-6);
    assertAllElevations(path, FakeElevationProducer.FAST_ELEVATION);
  }

  @Test
  void processWithClimb_onARealClimb_mapsTheDenseAscentToTheRetainedPoints() {
    // The fake tiers are flat (ascent 0), which cannot tell a wrong index mapping from a right
    // one: this pipeline reads a tile that rises 100 m a pixel eastwards instead.
    GpxPipeline sloped = new GpxPipeline();
    sloped.fastElevationProvider = slopedProvider();
    sloped.hdElevationProvider = sloped.fastElevationProvider;

    GpxPipeline.ProcessedWithClimb withClimb =
        sloped.processWithClimb(nantesLine(), "test", ElevationQuality.FAST);
    Path path = withClimb.processed().path();
    double[] climb = withClimb.climb();
    int last = climb.length - 1;

    assertEquals(path.getSize(), climb.length);
    assertTrue(path.getReportedElevationGain() > 0.0, "the profile really climbs");
    assertEquals(path.getReportedElevationGain(), climb[last], 1e-6);
    assertEquals(0.0, climb[0], 1e-9);
    assertTrue(path.getSize() >= 3, "a point inside the path to check");
    // The slope only goes up, so the ascent accumulated up to a point is the rise up to it (give
    // or take the dead-band): climb[k] = cumulativeGain(dense)[indices[k]], not cumulative[k].
    boolean inside = false;
    for (int k = 0; k <= last; k++) {
      double rise = path.elevation(k) - path.elevation(0);
      assertEquals(rise, climb[k], 50.0, "climb at retained point " + k);
      if (k > 0 && k < last && climb[k] > 0.0 && climb[k] < climb[last]) {
        inside = true;
      }
    }
    assertTrue(inside, "an interior point with a partial ascent");
  }

  /** Terrarium tiles whose elevation rises by 100 m with every pixel column, eastwards. */
  private static ElevationProvider slopedProvider() {
    int size = 16;
    ElevationProviderConfig config =
        ElevationProviderJvm.elevationProviderConfig(
            12, 100, "http://fake-elevation.invalid/{z}/{x}/{y}.png", size);
    byte[] rgba = new byte[size * size * 4];
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        int raw = (int) Math.round((100.0 + 100.0 * x + 32768.0) * 256.0);
        int i = (y * size + x) * 4;
        rgba[i] = (byte) (raw >> 16);
        rgba[i + 1] = (byte) (raw >> 8);
        rgba[i + 2] = (byte) raw;
        rgba[i + 3] = (byte) 0xFF;
      }
    }
    RawTile tile = new RawTile(size, size, rgba);
    return ElevationProviderJvm.newElevationProvider(config, url -> tile);
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
