package fr.pedalons.infrastructure.gpx;

import io.github.glandais.elevation.RawTile;
import io.github.glandais.elevation.TileFetcherJvm;
import java.io.File;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.function.Function;
import org.jboss.logging.Logger;

/**
 * Disk cache for the DEM (elevation) tiles vcyclist downloads, plugged into
 * {@code ElevationProviderJvm.newElevationProvider(config, fetcher)}.
 *
 * <p>The layout is <b>identical to gpx2web's</b> — {@code {cache}/mapterhorn/{z}/{x}/{y}.webp},
 * where {@code z}/{x}/{y} come from the last three segments of the tile URL — so the production
 * cache is reused as is, with no refill.
 *
 * <p>Two properties this class owes its callers:
 *
 * <ul>
 *   <li><b>Thread safety.</b> vcyclist invokes the fetcher under {@code Dispatchers.IO} with up to
 *       10 tiles in flight, so two threads may race on the same tile. Bytes are written to a temp
 *       file <em>in the target directory</em> and then moved with {@code ATOMIC_MOVE} +
 *       {@code REPLACE_EXISTING}: a reader never observes a partial file, and the loser of a race
 *       simply overwrites identical bytes.
 *   <li><b>Decode before store.</b> gpx2web streamed the response straight into the final file
 *       ({@code BodyHandlers.ofFile}), so a crash — or an error page served with a 200 — cached
 *       garbage forever. Here the bytes are decoded first and only stored once decoding succeeded.
 * </ul>
 *
 * <p>The in-memory LRU of vcyclist's tile manager stays in front of this disk cache; the two
 * layers are meant to stack.
 */
public class DemTileFetcher implements Function<String, RawTile> {

  private static final Logger LOG = Logger.getLogger(DemTileFetcher.class);

  /** Kept from gpx2web so the existing production cache is picked up untouched. */
  private static final String SUBFOLDER = "mapterhorn";

  private final File cacheFolder;

  public DemTileFetcher(File cacheFolder) {
    this.cacheFolder = cacheFolder;
  }

  @Override
  public RawTile apply(String url) {
    File file = cacheFile(url);
    boolean cached = file.isFile() && file.length() > 0;

    byte[] bytes = cached ? readAll(file) : TileFetcherJvm.fetchTileBytesBlocking(url);
    RawTile tile = TileFetcherJvm.decodeTileBytesBlocking(bytes, url);

    if (!cached) {
      storeAtomically(file, bytes);
    }
    return tile;
  }

  /** {@code {cache}/mapterhorn/{z}/{x}/{y}.webp}, from the last three segments of the URL. */
  private File cacheFile(String url) {
    String path = url;
    int query = path.indexOf('?');
    if (query >= 0) {
      path = path.substring(0, query);
    }
    String[] segments = path.split("/");
    if (segments.length < 3) {
      throw new IllegalArgumentException("Cannot derive a tile cache path from URL " + url);
    }
    File dir =
        new File(
            new File(new File(cacheFolder, SUBFOLDER), segments[segments.length - 3]),
            segments[segments.length - 2]);
    return new File(dir, segments[segments.length - 1]);
  }

  private static byte[] readAll(File file) {
    try {
      return Files.readAllBytes(file.toPath());
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  /**
   * Writes {@code bytes} to {@code target} so that no reader — in this JVM or another — ever sees a
   * half-written tile: temp file in the same directory (so the move stays on one filesystem), then
   * an atomic move over the target.
   *
   * <p>Best effort: a caching failure must not fail the elevation lookup that already succeeded.
   */
  private static void storeAtomically(File target, byte[] bytes) {
    Path dir = target.toPath().getParent();
    Path tmp = null;
    try {
      Files.createDirectories(dir);
      tmp = Files.createTempFile(dir, "tile-", ".tmp");
      Files.write(tmp, bytes);
      Files.move(
          tmp,
          target.toPath(),
          StandardCopyOption.ATOMIC_MOVE,
          StandardCopyOption.REPLACE_EXISTING);
      tmp = null;
    } catch (IOException e) {
      LOG.warnf(e, "Failed to cache DEM tile %s", target.getAbsolutePath());
    } finally {
      if (tmp != null) {
        try {
          Files.deleteIfExists(tmp);
        } catch (IOException e) {
          LOG.warnf(e, "Failed to delete temp tile %s", tmp);
        }
      }
    }
  }
}
