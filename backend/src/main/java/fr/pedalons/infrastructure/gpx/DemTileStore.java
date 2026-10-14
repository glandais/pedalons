package fr.pedalons.infrastructure.gpx;

import io.github.glandais.elevation.TileKey;
import io.github.glandais.elevation.TileStore;
import java.io.File;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import org.jboss.logging.Logger;

/**
 * Disk storage for the DEM (elevation) tiles vcyclist downloads, plugged into {@code
 * ElevationProviderJvm.newElevationProvider(source, store)}.
 *
 * <p>The layout is vcyclist's {@link TileKey#relativePath()}, {@code
 * {cache}/{layer}/{z}/{x}/{y}.{extension}}: {@code mapterhorn/…/{y}.webp} — <b>identical to
 * gpx2web's</b>, so the production cache is reused as is — and {@code ign-lidar-hd-mnt/…/{y}.bil},
 * {@code ign-lidar-hd-mns/…/{y}.bil} for IGN LiDAR HD. The key comes from the tile coordinates, not
 * from the URL: IGN's tiles are WMS requests, and no segment of their URL names the tile.
 *
 * <p>Only storage lives here. vcyclist keeps the transport — the pacing IGN needs (it answers 429
 * past 40 requests a second), the retries, the decoding — and calls {@link #put} only with bytes
 * that decoded as a tile, so an error page served with a 200 never becomes a tile. A stored entry
 * that no longer decodes is read as a miss and overwritten; an empty file, which gpx2web could
 * leave behind, is a miss here already.
 *
 * <p><b>Thread safety.</b> vcyclist calls the store under {@code Dispatchers.IO} with up to 10
 * tiles in flight, so two threads may race on the same tile. Bytes are written to a temp file
 * <em>in the target directory</em> and then moved with {@code ATOMIC_MOVE} + {@code
 * REPLACE_EXISTING}: a reader never observes a partial file, and the loser of a race simply
 * overwrites identical bytes.
 *
 * <p>The in-memory LRU of vcyclist's tile manager stays in front of this disk cache; the two layers
 * are meant to stack.
 */
public class DemTileStore implements TileStore {

  private static final Logger LOG = Logger.getLogger(DemTileStore.class);

  private final File cacheFolder;

  public DemTileStore(File cacheFolder) {
    this.cacheFolder = cacheFolder;
  }

  @Override
  public byte[] get(TileKey key) {
    File file = file(key);
    if (!file.isFile() || file.length() == 0) {
      return null;
    }
    try {
      return Files.readAllBytes(file.toPath());
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  /**
   * Writes {@code bytes} so that no reader — in this JVM or another — ever sees a half-written
   * tile: temp file in the same directory (so the move stays on one filesystem), then an atomic
   * move over the target.
   *
   * <p>Best effort: a caching failure must not fail the elevation lookup that already succeeded.
   */
  @Override
  public void put(TileKey key, byte[] bytes) {
    File target = file(key);
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

  private File file(TileKey key) {
    return new File(cacheFolder, key.relativePath());
  }
}
