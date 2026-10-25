package fr.pedalons.service.migration.live;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTimeoutPreemptively;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.sun.net.httpserver.HttpServer;
import fr.pedalons.service.migration.SourceFileUnavailableException;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import tools.jackson.databind.ObjectMapper;

/**
 * Which answers of biketeam's export end the job, are retried, or only cost one file. Only a 4xx
 * carrying biketeam's JSON {@code code} is a refusal; a bare 404 (export switched off, a proxy with
 * no route, biketeam restarting) is transient.
 */
class BiketeamExportClientTest {

  private HttpServer server;
  private BiketeamExportClient client;

  /** What the fake export answers next. */
  private int status;

  private @Nullable String body;

  /**
   * When set, the fake export sends the headers — announcing more than it sends — and {@link #body},
   * then either holds the connection open without a byte more ({@code trickle} false) or sends one
   * more byte every 200 ms ({@code trickle} true), until the test ends.
   */
  private boolean stall;

  private boolean trickle;

  private final CountDownLatch testDone = new CountDownLatch(1);
  private ExecutorService executor;

  @TempDir Path tempDir;

  @BeforeEach
  void start() throws IOException {
    server = HttpServer.create(new InetSocketAddress(InetAddress.getLoopbackAddress(), 0), 0);
    // A stalled exchange holds its thread: the others must not queue behind it.
    executor = Executors.newCachedThreadPool();
    server.setExecutor(executor);
    server.createContext(
        "/",
        exchange -> {
          if (stall) {
            byte[] head = body == null ? new byte[0] : body.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, head.length + 1_000_000L);
            OutputStream out = exchange.getResponseBody();
            out.write(head);
            out.flush();
            try {
              while (!testDone.await(200, TimeUnit.MILLISECONDS)) {
                if (trickle) {
                  out.write(' ');
                  out.flush();
                }
              }
            } catch (InterruptedException e) {
              Thread.currentThread().interrupt();
            } catch (IOException e) {
              // The client gave up and closed the connection: what the test expects.
            }
            exchange.close();
            return;
          }
          byte[] bytes = body == null ? new byte[0] : body.getBytes(StandardCharsets.UTF_8);
          if (body != null && body.startsWith("{")) {
            exchange.getResponseHeaders().add("Content-Type", "application/json");
          }
          exchange.sendResponseHeaders(status, bytes.length == 0 ? -1 : bytes.length);
          try (OutputStream out = exchange.getResponseBody()) {
            out.write(bytes);
          }
        });
    server.start();
    BiketeamLiveMigrationConfig config = new BiketeamLiveMigrationConfig();
    config.exportUrl = Optional.of("http://127.0.0.1:" + server.getAddress().getPort());
    config.exportSecret = Optional.of("test-export-secret");
    config.exportIdleTimeout = Duration.ofSeconds(1);
    config.exportTransferTimeout = Duration.ofSeconds(30);
    config.exportSnapshotTimeout = Duration.ofSeconds(30);
    client = new BiketeamExportClient();
    client.config = config;
    client.objectMapper = new ObjectMapper();
  }

  @AfterEach
  void stop() {
    testDone.countDown();
    server.stop(0);
    executor.shutdownNow();
  }

  private void answer(int status, @Nullable String body) {
    this.status = status;
    this.body = body;
  }

  private BiketeamExportException.Kind snapshotFailure() {
    return assertThrows(BiketeamExportException.class, () -> client.fetchSnapshot("n-peloton"))
        .kind();
  }

  @Test
  void describe_namesTheExceptionWhenItHasNoMessage() {
    assertEquals(
        "ConnectException", BiketeamExportClient.describe(new java.net.ConnectException()));
    assertEquals(
        "IOException: connection reset",
        BiketeamExportClient.describe(new IOException("connection reset")));
  }

  @Test
  void snapshot_aBare404_isUnavailable() {
    answer(404, null);
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, snapshotFailure());
  }

  @Test
  void snapshot_a4xxWithoutBiketeamsCode_isUnavailable() {
    answer(404, "<html>Not Found</html>");
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, snapshotFailure());
    answer(404, "{\"timestamp\":\"…\",\"status\":404,\"error\":\"Not Found\"}");
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, snapshotFailure());
  }

  @Test
  void snapshot_a4xxWithBiketeamsCode_isRefused() {
    answer(404, "{\"code\":\"TEAM_NOT_FOUND\"}");
    assertEquals(BiketeamExportException.Kind.REFUSED, snapshotFailure());
    answer(409, "{\"code\":\"NO_ACTIVE_MIGRATION\",\"message\":\"…\"}");
    assertEquals(BiketeamExportException.Kind.REFUSED, snapshotFailure());
    answer(401, "{\"code\":\"UNAUTHORIZED\",\"message\":\"…\"}");
    assertEquals(BiketeamExportException.Kind.REFUSED, snapshotFailure());
  }

  @Test
  void snapshot_a5xx_isUnavailable_evenWithACode() {
    answer(503, "{\"code\":\"INTERNAL_ERROR\"}");
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, snapshotFailure());
  }

  @Test
  void snapshot_anUnreadableBody_isInvalid() {
    answer(200, "not json");
    assertEquals(BiketeamExportException.Kind.INVALID, snapshotFailure());
  }

  private static final String FILE = "/internal/pedalons/teams/n-peloton/files/gpx/map-1";

  @Test
  void file_fileNotFound_onlyCostsThatFile() {
    answer(404, "{\"code\":\"FILE_NOT_FOUND\"}");
    assertThrows(
        SourceFileUnavailableException.class, () -> client.download(FILE, tempDir.resolve("f")));
  }

  @Test
  void file_aBare404_isTheExportUnavailable() {
    answer(404, null);
    BiketeamExportException e =
        assertThrows(
            BiketeamExportException.class, () -> client.download(FILE, tempDir.resolve("f")));
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, e.kind());
  }

  @Test
  void file_a5xx_isTheExportUnavailable() {
    answer(502, "Bad Gateway");
    BiketeamExportException e =
        assertThrows(
            BiketeamExportException.class, () -> client.download(FILE, tempDir.resolve("f")));
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, e.kind());
  }

  @Test
  void file_anotherBiketeamRefusal_isRefused() {
    answer(409, "{\"code\":\"NO_ACTIVE_MIGRATION\"}");
    BiketeamExportException e =
        assertThrows(
            BiketeamExportException.class, () -> client.download(FILE, tempDir.resolve("f")));
    assertEquals(BiketeamExportException.Kind.REFUSED, e.kind());
  }

  @Test
  void file_a200_isCopied() throws IOException {
    answer(200, "<gpx/>");
    Path target = tempDir.resolve("f");
    client.download(FILE, target);
    assertArrayEquals("<gpx/>".getBytes(StandardCharsets.UTF_8), Files.readAllBytes(target));
  }

  @Test
  void theExportUnreachable_isUnavailable() {
    server.stop(0);
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, snapshotFailure());
    BiketeamExportException e =
        assertThrows(
            BiketeamExportException.class, () -> client.download(FILE, tempDir.resolve("f")));
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, e.kind());
  }

  // ─── a body that stalls ───────────────────────────────────────────────────

  /** Well under a minute: the idle timeout of 1 s gave up, not some socket default. */
  private static final Duration GIVE_UP_WITHIN = Duration.ofSeconds(15);

  @Test
  void file_aBodyThatStallsAfterTheHeaders_isUnavailable_notABlockedWorker() {
    stall = true;
    answer(200, "<gpx>");
    Path target = tempDir.resolve("f");
    BiketeamExportException e =
        assertTimeoutPreemptively(
            GIVE_UP_WITHIN,
            () -> assertThrows(BiketeamExportException.class, () -> client.download(FILE, target)));
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, e.kind());
    assertTrue(e.getMessage().contains("stalled"), e.getMessage());
  }

  @Test
  void snapshot_aBodyThatStallsMidJson_isUnavailable_notInvalid() {
    stall = true;
    answer(200, "{\"schemaVersion\":1,\"team\":{");
    BiketeamExportException.Kind kind =
        assertTimeoutPreemptively(GIVE_UP_WITHIN, this::snapshotFailure);
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, kind, "retried, not refused as invalid");
  }

  @Test
  void file_aBodyTricklingPastTheTransferTimeout_isUnavailable() {
    stall = true;
    trickle = true;
    // Never idle for 1 s, but never done either.
    client.config.exportIdleTimeout = Duration.ofSeconds(5);
    client.config.exportTransferTimeout = Duration.ofSeconds(2);
    answer(200, "<gpx>");
    Path target = tempDir.resolve("f");
    BiketeamExportException e =
        assertTimeoutPreemptively(
            GIVE_UP_WITHIN,
            () -> assertThrows(BiketeamExportException.class, () -> client.download(FILE, target)));
    assertEquals(BiketeamExportException.Kind.UNAVAILABLE, e.kind());
    assertTrue(e.getMessage().contains("in time"), e.getMessage());
  }

  // ─── the heartbeat, while a body comes in ─────────────────────────────────

  @Test
  void file_callsTheHeartbeat_asTheBodyComesIn() throws IOException {
    answer(200, "<gpx/>");
    AtomicInteger beats = new AtomicInteger();
    client.withHeartbeat(beats::incrementAndGet).download(FILE, tempDir.resolve("f"));
    assertTrue(beats.get() >= 1, "beats: " + beats.get());
  }

  @Test
  void snapshot_callsTheHeartbeat_asTheBodyComesIn() {
    answer(200, "{\"schemaVersion\":1}");
    AtomicInteger beats = new AtomicInteger();
    client.fetchSnapshot("t", beats::incrementAndGet);
    assertTrue(beats.get() >= 1, "beats: " + beats.get());
  }

  @Test
  void aJobLostDuringADownload_stopsIt_asLost_notAsTheExportFailing() {
    stall = true;
    trickle = true;
    client.config.exportIdleTimeout = Duration.ofSeconds(5);
    answer(200, "<gpx>");
    Runnable lost =
        () -> {
          throw new BiketeamJobLostException("requeued meanwhile");
        };
    assertTimeoutPreemptively(
        GIVE_UP_WITHIN,
        () ->
            assertThrows(
                BiketeamJobLostException.class,
                () -> client.withHeartbeat(lost).download(FILE, tempDir.resolve("f"))));
    assertTimeoutPreemptively(
        GIVE_UP_WITHIN,
        () -> assertThrows(BiketeamJobLostException.class, () -> client.fetchSnapshot("t", lost)));
  }
}
