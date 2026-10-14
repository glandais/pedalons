package fr.pedalons.infrastructure.gpx;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import io.github.glandais.elevation.TileKey;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * The DEM tile disk store. Transport, decoding and "never store what does not decode" are
 * vcyclist's (its own {@code TileStoreTest}); what is ours is the layout — the production cache
 * gpx2web filled must still be found — and the atomic, best-effort write.
 */
class DemTileStoreTest {

  private static final TileKey MAPTERHORN = new TileKey(TileKey.MAPTERHORN, 12, 2048, 1024, "webp");

  private static final TileKey IGN_MNS =
      new TileKey(TileKey.IGN_LIDAR_HD_MNS, 15, 16590, 11520, "bil");

  @TempDir File cacheFolder;

  // ==================== Layout ====================

  @Test
  void get_shouldReadATileStoredUnderTheGpx2webLayout() throws IOException {
    // What the production cache holds since gpx2web: the raw WebP body at mapterhorn/{z}/{x}/{y}.
    byte[] bytes = {1, 2, 3, 4};
    Path file = cacheFolder.toPath().resolve("mapterhorn/12/2048/1024.webp");
    Files.createDirectories(file.getParent());
    Files.write(file, bytes);

    assertArrayEquals(bytes, new DemTileStore(cacheFolder).get(MAPTERHORN));
  }

  @Test
  void put_shouldFileEachLayerUnderItsOwnDirectory() throws IOException {
    DemTileStore store = new DemTileStore(cacheFolder);
    store.put(MAPTERHORN, new byte[] {1});
    store.put(IGN_MNS, new byte[] {2});

    assertEquals(
        List.of("ign-lidar-hd-mns/15/16590/11520.bil", "mapterhorn/12/2048/1024.webp"),
        allFilesIn(cacheFolder.toPath()));
    assertArrayEquals(new byte[] {2}, store.get(IGN_MNS));
  }

  // ==================== Misses ====================

  @Test
  void get_shouldMissWhenNothingIsStored() {
    assertNull(new DemTileStore(cacheFolder).get(MAPTERHORN));
  }

  @Test
  void get_shouldMissOnAnEmptyFile() throws IOException {
    // gpx2web streamed straight into the final file, so a zero-length leftover can be sitting in
    // the production cache this store inherits.
    Path file = cacheFolder.toPath().resolve(MAPTERHORN.relativePath());
    Files.createDirectories(file.getParent());
    Files.write(file, new byte[0]);

    assertNull(new DemTileStore(cacheFolder).get(MAPTERHORN));
  }

  // ==================== Best-effort write ====================

  @Test
  void put_shouldNotThrowWhenTheTileCannotBeCached() throws IOException {
    // A regular file where the tile directory belongs: creating the directory fails, and caching
    // is best effort — the elevation lookup that already succeeded must not fail with it.
    Path blocker = cacheFolder.toPath().resolve("mapterhorn/12/2048");
    Files.createDirectories(blocker.getParent());
    Files.write(blocker, new byte[] {1});

    assertDoesNotThrow(() -> new DemTileStore(cacheFolder).put(MAPTERHORN, new byte[] {1}));
  }

  // ==================== Atomic write ====================

  @Test
  void put_shouldNeverExposeAPartiallyWrittenTileUnderConcurrency() throws Exception {
    // vcyclist calls the store from Dispatchers.IO with up to 10 tiles in flight, so several
    // threads race on the same file. The write goes through a temp file in the target directory
    // followed by an atomic move: every reader gets nothing or a whole tile, the final bytes are
    // exactly the written ones, and no temp file is left behind.
    byte[] bytes = new byte[256 * 1024];
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = (byte) (i * 7919);
    }
    DemTileStore store = new DemTileStore(cacheFolder);

    int threads = 8;
    ExecutorService pool = Executors.newFixedThreadPool(threads);
    CountDownLatch go = new CountDownLatch(1);
    List<Future<byte[]>> results = new ArrayList<>();
    try {
      for (int i = 0; i < threads; i++) {
        results.add(
            pool.submit(
                () -> {
                  go.await();
                  store.put(MAPTERHORN, bytes);
                  return store.get(MAPTERHORN);
                }));
      }
      go.countDown();
      for (Future<byte[]> result : results) {
        assertArrayEquals(bytes, result.get(60, TimeUnit.SECONDS));
      }
    } finally {
      pool.shutdownNow();
    }

    assertEquals(List.of(MAPTERHORN.relativePath()), allFilesIn(cacheFolder.toPath()));
  }

  // ==================== Helpers ====================

  private static List<String> allFilesIn(Path root) {
    try (Stream<Path> files = Files.walk(root)) {
      return files
          .filter(Files::isRegularFile)
          .map(p -> root.relativize(p).toString())
          .sorted()
          .toList();
    } catch (IOException e) {
      throw new AssertionError("Cannot walk " + root, e);
    }
  }
}
