package fr.pedalons.service.thumbnail;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.route.GpxTrack;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.awt.Color;
import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

@QuarkusTest
class MapThumbnailRendererTest extends AbstractBaseTest {

  @Inject MapThumbnailRenderer renderer;

  @TempDir Path tmp;

  private static List<io.github.glandais.engine.path.Path> paths() {
    return ThumbnailService.buildPaths(
        List.of(
            new ThumbnailService.ThumbnailTrack(
                "track",
                List.of(
                    new GpxTrack.TrackPoint(45.0, 6.0, 500.0, 0.0),
                    new GpxTrack.TrackPoint(45.1, 6.1, 510.0, 10000.0)))));
  }

  /** The tileserver answers an error body, not a tile: the render must fail, not come out black. */
  @Test
  void render_withTileErrors_failsAndLeavesNoImage() {
    File output = tmp.resolve("thumbnail.png").toFile();

    assertThrows(
        IOException.class,
        () -> renderer.render(output, paths(), "no-such-style", List.of(Color.RED)));

    assertFalse(output.exists());
  }
}
