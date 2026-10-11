package fr.pedalons.service.thumbnail;

import io.github.glandais.engine.path.Path;
import io.github.glandais.map.TileMapProducer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.awt.Color;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/**
 * The one way to draw a track on the tileserver's map: every thumbnail (route, ride, trip, GPX
 * preview) goes through here.
 *
 * <p>A tile the tileserver fails to serve fails the whole render (the {@link TileMapProducer} is
 * built with {@code MissingTilePolicy.FAIL}, see {@code VcyclistProducer}): a thumbnail is either
 * a full map or nothing, never a track over holes in the background.
 */
@ApplicationScoped
public class MapThumbnailRenderer {

  public static final String LIGHT_STYLE = "colorful";
  public static final String DARK_STYLE = "eclipse";

  private static final int SIZE = 512;
  private static final double MARGIN = 0.1;

  @Inject TileMapProducer tileMapProducer;

  @ConfigProperty(name = "tileserver.url")
  String tileserverUrl;

  /**
   * Renders {@code paths} over the {@code style} map into a 512×512 PNG at {@code output}, one
   * colour per path (cycling through {@code colors}).
   *
   * @throws IOException when the map could not be drawn in full; {@code output} is then deleted.
   */
  public void render(File output, List<Path> paths, String style, List<Color> colors)
      throws IOException {
    String urlPattern = tileserverUrl + "/styles/" + style + "/256/{z}/{x}/{y}.png";
    try {
      // Exactly one framing mode may be non-null (maxSize | width+height | zoom): here
      // width+height. A second one raises IllegalArgumentException.
      tileMapProducer.createTileMap(
          output, paths, urlPattern, MARGIN, null, SIZE, SIZE, null, colors);
    } catch (IOException | RuntimeException e) {
      Files.deleteIfExists(output.toPath());
      throw e;
    }
  }
}
