package fr.pedalons.infrastructure.gpx;

import static java.nio.charset.StandardCharsets.UTF_8;
import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.sun.net.httpserver.HttpServer;
import io.github.glandais.elevation.RawTile;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Stream;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * The DEM tile disk cache, exercised against a loopback HTTP server — never against
 * {@code tiles.mapterhorn.com}. The server counts its requests, which is how "reads from disk
 * without any outgoing request" is asserted rather than assumed.
 *
 * <p>Tiles are served as PNG. The fetcher decodes through {@code ImageIO}, which does not look at
 * the file name, so the stock PNG codec stands in for the WebP one and the test does not depend on
 * the TwelveMonkeys plugin being on the runtime classpath.
 */
class DemTileFetcherTest {

  /** The three last URL segments are what the gpx2web cache layout is derived from. */
  private static final String TILE_PATH = "/12/2048/1024.webp";

  private static final String CACHED_TILE = "mapterhorn/12/2048/1024.webp";

  @TempDir File cacheFolder;

  private HttpServer server;
  private ExecutorService serverPool;
  private final AtomicInteger requests = new AtomicInteger();
  private volatile byte[] responseBody = new byte[0];
  private volatile int responseStatus = 200;

  @BeforeEach
  void startServer() throws IOException {
    server = HttpServer.create(new InetSocketAddress(InetAddress.getLoopbackAddress(), 0), 0);
    serverPool = Executors.newFixedThreadPool(4);
    server.setExecutor(serverPool);
    server.createContext(
        "/",
        exchange -> {
          requests.incrementAndGet();
          byte[] body = responseBody;
          exchange.sendResponseHeaders(responseStatus, body.length == 0 ? -1 : body.length);
          try (OutputStream out = exchange.getResponseBody()) {
            out.write(body);
          }
        });
    server.start();
  }

  @AfterEach
  void stopServer() {
    server.stop(0);
    serverPool.shutdownNow();
  }

  // ==================== Disk hit ====================

  @Test
  void apply_shouldReadACachedTileWithoutAnyOutgoingRequest() throws IOException {
    byte[] png = pngBytes(4);
    writeCachedTile(png);

    RawTile tile = new DemTileFetcher(cacheFolder).apply(tileUrl());

    assertEquals(4, tile.getWidth());
    assertEquals(4, tile.getHeight());
    assertEquals(0, requests.get(), "a cached tile must not hit the network");
    assertArrayEquals(png, Files.readAllBytes(cachedTile()), "the cached file must be left alone");
  }

  @Test
  void apply_shouldIgnoreAnEmptyCachedFileAndRefetch() throws IOException {
    // gpx2web streamed straight into the final file, so a zero-length leftover can be sitting in
    // the production cache this fetcher inherits.
    byte[] png = pngBytes(4);
    writeCachedTile(new byte[0]);
    responseBody = png;

    RawTile tile = new DemTileFetcher(cacheFolder).apply(tileUrl());

    assertEquals(4, tile.getWidth());
    assertEquals(1, requests.get());
    assertArrayEquals(png, Files.readAllBytes(cachedTile()));
  }

  // ==================== Cache fill ====================

  @Test
  void apply_shouldStoreAFetchedTileUnderTheGpx2webLayout() throws IOException {
    byte[] png = pngBytes(8);
    responseBody = png;
    DemTileFetcher fetcher = new DemTileFetcher(cacheFolder);

    assertEquals(8, fetcher.apply(tileUrl()).getWidth());

    assertTrue(Files.isRegularFile(cachedTile()), "expected " + CACHED_TILE);
    assertArrayEquals(png, Files.readAllBytes(cachedTile()));
    assertEquals(
        List.of("1024.webp"), fileNamesIn(cachedTile().getParent()), "no temp file may survive");

    // Second call: served from the file just written, no second request.
    assertEquals(8, fetcher.apply(tileUrl()).getWidth());
    assertEquals(1, requests.get());
  }

  @Test
  void apply_shouldStillReturnTheTileWhenItCannotBeCached() throws IOException {
    // A regular file where the tile directory belongs: creating the directory fails, and caching
    // is best effort — the elevation lookup that already succeeded must not fail with it.
    responseBody = pngBytes(4);
    Path blocker = cacheFolder.toPath().resolve("mapterhorn/12/2048");
    Files.createDirectories(blocker.getParent());
    Files.write(blocker, new byte[] {1});

    RawTile tile = new DemTileFetcher(cacheFolder).apply(tileUrl());

    assertNotNull(tile);
    assertEquals(4, tile.getWidth());
  }

  // ==================== Nothing is stored unless it decodes ====================

  @Test
  void apply_shouldStoreNothingWhenTheBytesAreNotAnImage() throws IOException {
    // An error page served with a 200 — exactly what turned into a permanently cached "tile"
    // before decode-then-store.
    responseBody = "<html><body>502 Bad Gateway</body></html>".getBytes(UTF_8);
    DemTileFetcher fetcher = new DemTileFetcher(cacheFolder);

    assertThrows(IllegalStateException.class, () -> fetcher.apply(tileUrl()));

    assertEquals(List.of(), allFilesIn(cacheFolder.toPath()), "an error page is not a tile");
  }

  @Test
  void apply_shouldStoreNothingWhenTheServerFails() {
    responseStatus = 500;
    DemTileFetcher fetcher = new DemTileFetcher(cacheFolder);

    assertThrows(IllegalStateException.class, () -> fetcher.apply(tileUrl()));

    assertEquals(List.of(), allFilesIn(cacheFolder.toPath()));
  }

  // ==================== Atomic write ====================

  @Test
  void apply_shouldNeverExposeAPartiallyWrittenTileUnderConcurrency() throws Exception {
    // vcyclist calls the fetcher from Dispatchers.IO with up to 10 tiles in flight, so several
    // threads race on the same file. The write goes through a temp file in the target directory
    // followed by an atomic move: every caller gets a whole tile, the final bytes are exactly the
    // served ones, and no temp file is left behind.
    byte[] png = pngBytes(256);
    responseBody = png;
    DemTileFetcher fetcher = new DemTileFetcher(cacheFolder);

    int threads = 8;
    ExecutorService pool = Executors.newFixedThreadPool(threads);
    CountDownLatch go = new CountDownLatch(1);
    List<Future<RawTile>> results = new ArrayList<>();
    try {
      for (int i = 0; i < threads; i++) {
        results.add(
            pool.submit(
                () -> {
                  go.await();
                  return fetcher.apply(tileUrl());
                }));
      }
      go.countDown();
      for (Future<RawTile> result : results) {
        RawTile tile = result.get(60, TimeUnit.SECONDS);
        assertEquals(256, tile.getWidth());
        assertEquals(256 * 256 * 4, tile.getRgba().length);
      }
    } finally {
      pool.shutdownNow();
    }

    assertArrayEquals(png, Files.readAllBytes(cachedTile()), "the stored tile must be complete");
    assertEquals(List.of("1024.webp"), fileNamesIn(cachedTile().getParent()));
  }

  // ==================== Helpers ====================

  private String tileUrl() {
    return "http://127.0.0.1:" + server.getAddress().getPort() + TILE_PATH;
  }

  private Path cachedTile() {
    return cacheFolder.toPath().resolve(CACHED_TILE);
  }

  private void writeCachedTile(byte[] bytes) throws IOException {
    Path tile = cachedTile();
    Files.createDirectories(tile.getParent());
    Files.write(tile, bytes);
  }

  private static List<String> fileNamesIn(Path directory) {
    try (Stream<Path> files = Files.list(directory)) {
      return files.map(p -> p.getFileName().toString()).sorted().toList();
    } catch (IOException e) {
      throw new AssertionError("Cannot list " + directory, e);
    }
  }

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

  /** A square image with varying pixels, so the encoded bytes are not trivially small. */
  private static byte[] pngBytes(int size) throws IOException {
    BufferedImage image = new BufferedImage(size, size, BufferedImage.TYPE_INT_RGB);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        image.setRGB(x, y, (x * 7919 + y * 104729) & 0xFFFFFF);
      }
    }
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    ImageIO.write(image, "png", out);
    return out.toByteArray();
  }
}
