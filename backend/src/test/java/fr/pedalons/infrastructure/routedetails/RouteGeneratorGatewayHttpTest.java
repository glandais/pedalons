package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException.Kind;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.DepositReport;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.EditOperation;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.EditRequest;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.EditResponse;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GenerateRequest;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GenerateResponse;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GeoPoint;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@link RouteGeneratorGateway} against a local {@code com.sun.net.httpserver} (lot 3b plan §10.6):
 * what goes over the wire, as {@code OpenMeteoGatewayHttpTest} does for the weather. No Quarkus.
 */
class RouteGeneratorGatewayHttpTest {

  private static final String KEY = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8";
  private static final String TEAM = "0abcdefghijkl";

  private HttpServer server;

  /** What the last request carried. */
  private final AtomicReference<String> protocol = new AtomicReference<>();

  private final AtomicReference<com.sun.net.httpserver.Headers> headers = new AtomicReference<>();
  private final AtomicReference<String> method = new AtomicReference<>();
  private final AtomicReference<String> path = new AtomicReference<>();
  private final AtomicReference<byte[]> body = new AtomicReference<>();
  private final List<Integer> chunkSizes = new CopyOnWriteArrayList<>();

  @BeforeEach
  void start() throws IOException {
    server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
    server.setExecutor(java.util.concurrent.Executors.newCachedThreadPool());
  }

  @AfterEach
  void stop() {
    server.stop(0);
  }

  private RouteGeneratorGateway gateway(String url, Duration generateTimeout) {
    RouteGeneratorGateway g = new RouteGeneratorGateway();
    g.url = url;
    g.configuredKey = Optional.of(KEY);
    g.generateTimeout = generateTimeout;
    g.editTimeout = Duration.ofSeconds(5);
    g.depositTimeout = Duration.ofSeconds(30);
    g.mapper = new ObjectMapper();
    return g;
  }

  private RouteGeneratorGateway running(Duration generateTimeout) {
    server.start();
    return gateway("http://127.0.0.1:" + server.getAddress().getPort(), generateTimeout);
  }

  private void handle(String route, Handler handler) {
    server.createContext(
        route,
        exchange -> {
          protocol.set(exchange.getProtocol());
          headers.set(exchange.getRequestHeaders());
          method.set(exchange.getRequestMethod());
          path.set(exchange.getRequestURI().getPath());
          try {
            handler.handle(exchange);
          } finally {
            exchange.close();
          }
        });
  }

  private interface Handler {
    void handle(HttpExchange exchange) throws IOException;
  }

  private static void respond(HttpExchange e, int status, String type, String text)
      throws IOException {
    byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
    e.getResponseHeaders().add("Content-Type", type);
    e.sendResponseHeaders(status, bytes.length == 0 ? -1 : bytes.length);
    if (bytes.length > 0) {
      e.getResponseBody().write(bytes);
    }
  }

  private static GenerateRequest request() {
    return new GenerateRequest(new GeoPoint(47.2, -1.5), null, "NE", 50_000, "road", 0.25, 7);
  }

  private static final String ROUTES =
      "{\"graph_id\":\"g\",\"mode\":\"team_first\",\"coverage\":\"partial\",\"dropped\":1,"
          + "\"overlay\":{\"deposited_at\":\"2026-11-16T02:10:00Z\"},\"future\":1,\"routes\":[{"
          + "\"polyline\":\"abc\",\"distance_m\":50000.0,\"team_m\":1,\"bridged_m\":0,"
          + "\"team_share\":0.8,\"tail_m\":10,\"crossings\":0,\"unpaved_m\":0,"
          + "\"unpaved_share\":0.1,\"bearing_deviation_deg\":12.5,\"ascent_m\":null}]}";

  @Test
  void aGenerationIsAnHttp11PostWithTheTwoHeadersAndTheSnakeCaseBody() throws Exception {
    handle(
        "/v1/generator/routes",
        e -> {
          body.set(e.getRequestBody().readAllBytes());
          respond(e, 200, "application/json", ROUTES);
        });
    GenerateResponse answer = running(Duration.ofSeconds(5)).generate(TEAM, request());

    assertEquals("HTTP/1.1", protocol.get());
    assertEquals("POST", method.get());
    assertEquals(KEY, headers.get().getFirst("Ord-Namespace-Key"));
    assertEquals(TEAM, headers.get().getFirst("Ord-Team"));
    assertTrue(headers.get().getFirst("Content-Type").startsWith("application/json"));
    String sent = new String(body.get(), StandardCharsets.UTF_8);
    assertTrue(sent.contains("\"distance_m\":50000.0"), sent);
    assertTrue(sent.contains("\"ride_type\":\"road\""), sent);
    assertTrue(sent.contains("\"bearing\":\"NE\""), sent);
    assertTrue(sent.contains("\"seed\":7"), sent);
    assertTrue(!sent.contains("\"end\""), "a null end is left out: " + sent);

    assertEquals(1, answer.routes().size());
    assertEquals(0.8, answer.routes().get(0).teamShare(), 1e-9);
    assertEquals(12.5, answer.routes().get(0).bearingDeviationDeg(), 1e-9);
    assertTrue(answer.partialCoverage());
    assertNotNull(answer.overlay().depositedInstant());
  }

  @Test
  void theTargetOfUnpavedShareIsSentAndItsOutcomeRead() throws Exception {
    handle(
        "/v1/generator/routes",
        e -> {
          body.set(e.getRequestBody().readAllBytes());
          respond(
              e,
              200,
              "application/json",
              "{\"dropped\":0,\"offroad\":{\"target\":0.6,\"tolerance\":0.05,"
                  + "\"reached\":false,\"steps\":3},\"routes\":[{\"polyline\":\"abc\","
                  + "\"distance_m\":50000.0,\"team_m\":1,\"bridged_m\":0,\"team_share\":0.8,"
                  + "\"tail_m\":10,\"crossings\":0,\"unpaved_m\":0,\"unpaved_share\":0.1,"
                  + "\"offroad_m\":20000.0,\"offroad_share\":0.4}]}");
        });
    GenerateRequest asked =
        new GenerateRequest(new GeoPoint(47.2, -1.5), null, null, 50_000, "gravel", 0.25, 7, 0.6);
    GenerateResponse answer = running(Duration.ofSeconds(5)).generate(TEAM, asked);

    String sent = new String(body.get(), StandardCharsets.UTF_8);
    assertTrue(sent.contains("\"offroad_target\":0.6"), sent);
    assertEquals(0.4, answer.routes().get(0).offroadShare(), 1e-9);
    assertEquals(0.4, answer.routes().get(0).offpavementShare(), 1e-9);
    assertEquals(0.05, answer.offroad().tolerance(), 1e-9);
    assertEquals(false, answer.offroad().reached());
    assertEquals(3, answer.offroad().steps());
  }

  @Test
  void withoutATargetTheKeyIsLeftOutAndTheSurfaceTagShareIsTheFallback() throws Exception {
    handle(
        "/v1/generator/routes",
        e -> {
          body.set(e.getRequestBody().readAllBytes());
          respond(e, 200, "application/json", ROUTES);
        });
    GenerateResponse answer = running(Duration.ofSeconds(5)).generate(TEAM, request());
    assertTrue(
        !new String(body.get(), StandardCharsets.UTF_8).contains("offroad_target"),
        "a null target is left out");
    assertEquals(null, answer.offroad());
    assertEquals(null, answer.routes().get(0).offroadShare());
    assertEquals(0.1, answer.routes().get(0).offpavementShare(), 1e-9);
  }

  @Test
  void aProblemBecomesATypedException() {
    handle(
        "/v1/generator/routes",
        e -> {
          e.getResponseHeaders().add("Retry-After", "3");
          respond(
              e,
              503,
              "application/problem+json",
              "{\"type\":\"t\",\"title\":\"t\",\"status\":503,\"detail\":\"d\",\"code\":\"overloaded\"}");
        });
    RouteGeneratorGateway g = running(Duration.ofSeconds(5));
    RouteGeneratorException e =
        assertThrows(RouteGeneratorException.class, () -> g.generate(TEAM, request()));
    assertEquals(Kind.OVERLOADED, e.kind());
    assertEquals(Duration.ofSeconds(3), e.retryAfter());
  }

  @Test
  void aReadTimeoutIsNotAConnectionFailure() {
    handle(
        "/v1/generator/routes",
        e -> {
          try {
            Thread.sleep(2_000);
          } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
          }
          respond(e, 200, "application/json", ROUTES);
        });
    RouteGeneratorGateway g = running(Duration.ofMillis(300));
    RouteGeneratorException e =
        assertThrows(RouteGeneratorException.class, () -> g.generate(TEAM, request()));
    assertEquals(Kind.READ_TIMEOUT, e.kind());
  }

  @Test
  void aRefusedConnectionIsNoAnswer() throws IOException {
    int port;
    try (java.net.ServerSocket s = new java.net.ServerSocket(0)) {
      port = s.getLocalPort();
    }
    RouteGeneratorGateway g = gateway("http://127.0.0.1:" + port, Duration.ofSeconds(2));
    RouteGeneratorException e = assertThrows(RouteGeneratorException.class, () -> g.status(TEAM));
    assertEquals(Kind.NO_ANSWER, e.kind());
  }

  @Test
  void withoutAKeyNothingIsSent() {
    handle("/v1/generator/overlay", e -> respond(e, 204, "application/json", ""));
    RouteGeneratorGateway g = running(Duration.ofSeconds(5));
    g.configuredKey = Optional.empty();
    RouteGeneratorException e = assertThrows(RouteGeneratorException.class, () -> g.delete(TEAM));
    assertEquals(Kind.NOT_CONFIGURED, e.kind());
    assertEquals(null, method.get());
  }

  @Test
  void statusAndDeleteGoToTheOverlayRoute() throws Exception {
    handle(
        "/v1/generator/overlay",
        e -> {
          if (e.getRequestMethod().equals("DELETE")) {
            respond(e, 204, "application/json", "");
          } else {
            respond(
                e,
                200,
                "application/json",
                "{\"state\":\"ready\",\"graph_id\":\"g\",\"deposited_at\":\"2026-11-16T02:10:00Z\","
                    + "\"expires_at\":\"2026-11-30T02:10:00Z\",\"source_digest\":\"p1-ab\"}");
          }
        });
    RouteGeneratorGateway g = running(Duration.ofSeconds(5));
    var status = g.status(TEAM);
    assertTrue(status.ready());
    assertEquals("p1-ab", status.sourceDigest());
    assertEquals(
        Duration.ofDays(14), Duration.between(status.depositedInstant(), status.expiresInstant()));
    assertEquals("GET", method.get());
    g.delete(TEAM);
    assertEquals("DELETE", method.get());
    assertEquals(TEAM, headers.get().getFirst("Ord-Team"));
  }

  @Test
  void aDepositIsStreamedAsNdjsonWithItsDigest() throws Exception {
    handle(
        "/v1/generator/overlay",
        e -> {
          ByteArrayOutputStream all = new ByteArrayOutputStream();
          try (InputStream in = e.getRequestBody()) {
            byte[] buffer = new byte[8192];
            int n;
            while ((n = in.read(buffer)) > 0) {
              all.write(buffer, 0, n);
            }
          }
          body.set(all.toByteArray());
          respond(
              e,
              200,
              "application/json",
              "{\"graph_id\":\"g\",\"deposited_at\":\"2026-11-16T02:10:00Z\","
                  + "\"expires_at\":\"2026-11-30T02:10:00Z\",\"tracks\":3000,\"tracks_excluded\":1,"
                  + "\"tracks_unreadable\":2,\"edges\":42,\"team_km\":12.5,\"stored_bytes\":10,"
                  + "\"km\":{\"total\":13,\"outside\":0.5,\"matched\":12.5}}");
        });
    RouteGeneratorGateway g = running(Duration.ofSeconds(5));
    // 3000 lines of ~1 KiB: 3 MB, many blocks of the pipe
    String line =
        "{\"type\":\"ROAD\",\"excluded\":false,\"network_edges\":\"" + "x".repeat(1000) + "\"}\n";
    DepositReport report =
        g.deposit(
            TEAM,
            "p1-digest",
            out -> {
              for (int i = 0; i < 3000; i++) {
                out.write(line.getBytes(StandardCharsets.UTF_8));
              }
              out.write("{\"end\":{\"tracks\":3000}}\n".getBytes(StandardCharsets.UTF_8));
            });
    assertEquals("PUT", method.get());
    assertEquals("p1-digest", headers.get().getFirst("Ord-Source-Digest"));
    assertTrue(headers.get().getFirst("Content-Type").startsWith("application/x-ndjson"));
    assertEquals("HTTP/1.1", protocol.get());
    String received = new String(body.get(), StandardCharsets.UTF_8);
    assertEquals(3001, received.split("\n").length);
    assertTrue(received.endsWith("{\"end\":{\"tracks\":3000}}\n"));
    assertEquals(42, report.edges());
    assertEquals(2, report.tracksUnreadable());
  }

  /**
   * The engine refuses a deposit before reading its body (slot taken, bad header): it answers at
   * once and never sends {@code 100 Continue}. The JDK's {@code HttpServer} cannot play that part:
   * it sends the interim {@code 100} by itself before the handler runs, so the client streams the
   * whole body and reads a reset instead of the answer. Hence a raw socket here.
   */
  @Test
  void anEarlyAnswerStopsTheWriting() throws Exception {
    String problem =
        "{\"type\":\"t\",\"title\":\"t\",\"status\":503,\"detail\":\"d\",\"code\":\"overloaded\"}";
    try (java.net.ServerSocket raw =
        new java.net.ServerSocket(0, 1, java.net.InetAddress.getByName("127.0.0.1"))) {
      Thread refusing =
          new Thread(() -> {
            try (java.net.Socket socket = raw.accept()) {
              InputStream in = socket.getInputStream();
              int matched = 0; // reads the request head only, up to its blank line
              while (matched < 4) {
                int b = in.read();
                if (b < 0) {
                  return;
                }
                matched = b == "\r\n\r\n".charAt(matched) ? matched + 1 : (b == '\r' ? 1 : 0);
              }
              byte[] bytes = problem.getBytes(StandardCharsets.UTF_8);
              socket
                  .getOutputStream()
                  .write(
                      ("HTTP/1.1 503 Service Unavailable\r\n"
                              + "Retry-After: 5\r\n"
                              + "Content-Type: application/problem+json\r\n"
                              + "Content-Length: "
                              + bytes.length
                              + "\r\nConnection: close\r\n\r\n")
                          .getBytes(StandardCharsets.UTF_8));
              socket.getOutputStream().write(bytes);
              socket.getOutputStream().flush();
            } catch (IOException ignored) {
              // the client went away: the assertions below say what it saw
            }
          });
      refusing.setDaemon(true);
      refusing.start();
      RouteGeneratorGateway g =
          gateway("http://127.0.0.1:" + raw.getLocalPort(), Duration.ofSeconds(5));
      AtomicLong written = new AtomicLong();
      byte[] chunk = new byte[1024];
      long total = 200L * 1024 * 1024;
      RouteGeneratorException e =
          assertThrows(
              RouteGeneratorException.class,
              () ->
                  g.deposit(
                      TEAM,
                      "p1-digest",
                      out -> {
                        for (long i = 0; i < total / chunk.length; i++) {
                          out.write(chunk);
                          written.addAndGet(chunk.length);
                        }
                      }));
      assertEquals(Kind.OVERLOADED, e.kind());
      assertEquals(Duration.ofSeconds(5), e.retryAfter());
      assertTrue(written.get() < total / 2, "wrote " + written.get() + " bytes");
    }
  }

  @Test
  void aFailureOfTheWriterIsNotTakenForTheServiceAnswering() {
    handle(
        "/v1/generator/overlay",
        e -> {
          e.getRequestBody().readAllBytes();
          respond(e, 200, "application/json", "{}");
        });
    RouteGeneratorGateway g = running(Duration.ofSeconds(5));
    IllegalStateException boom =
        assertThrows(
            IllegalStateException.class,
            () ->
                g.deposit(
                    TEAM,
                    "d",
                    out -> {
                      out.write(1);
                      throw new IllegalStateException("database down");
                    }));
    assertEquals("database down", boom.getMessage());
  }

  private static final String DOCUMENT =
      "{\"v\":1,\"rev\":5,\"status\":\"ok\",\"edges\":[{\"a\":1},  {\"b\":2}]}";

  @Test
  void anEditCarriesTheStoredDocumentAsItIsAndOneKeyOfOperation() throws Exception {
    handle(
        "/v1/generator/routes/edit",
        e -> {
          body.set(e.getRequestBody().readAllBytes());
          respond(
              e,
              200,
              "application/json",
              "{\"graph_id\":\"g\",\"mode\":\"discovery\",\"operation\":\"resize\","
                  + "\"original_m\":1000.5,\"target_m\":1200,\"dropped\":2,\"overlay\":null,"
                  + "\"future\":1,\"routes\":[{\"kind\":\"lengthen\",\"polyline\":\"abc\","
                  + "\"distance_m\":1200,\"kept_m\":900,\"kept_share\":0.9,\"unmatched_m\":0,"
                  + "\"changed\":{\"from_m\":10,\"to_m\":20,\"new_m\":30,\"points\":[3,5],"
                  + "\"team_m\":1,\"bridged_m\":0,\"team_share\":0.5,\"offroad_m\":0,"
                  + "\"offroad_share\":0.1,\"unpaved\":[],\"crossings\":1}}]}");
        });
    RouteGeneratorGateway g = running(Duration.ofSeconds(5));
    byte[] sent =
        g.bodyOf(new EditRequest("abc", DOCUMENT, "road", 0.25, 3, EditOperation.resize(1200)));
    EditResponse answer = g.edit(TEAM, sent);

    assertEquals("POST", method.get());
    assertEquals("/v1/generator/routes/edit", path.get());
    assertEquals(KEY, headers.get().getFirst("Ord-Namespace-Key"));
    assertEquals(TEAM, headers.get().getFirst("Ord-Team"));
    String text = new String(body.get(), StandardCharsets.UTF_8);
    assertTrue(text.contains("\"network_edges\":" + DOCUMENT), text);
    assertTrue(text.contains("\"operation\":{\"resize\":{\"distance_m\":1200.0}}"), text);
    assertTrue(!text.contains("move_end"), text);
    assertEquals(1000.5, answer.originalM(), 1e-9);
    assertEquals(2, answer.dropped());
    assertEquals(List.of(3, 5), answer.routes().get(0).changed().points());
    assertEquals(1, answer.routes().get(0).changed().crossings());
  }

  @Test
  void aMoveOfTheEndSendsTheMoveEndKeyAlone() {
    byte[] sent =
        gateway("http://127.0.0.1:1", Duration.ofSeconds(1))
            .bodyOf(
                new EditRequest(
                    "abc",
                    DOCUMENT,
                    "gravel",
                    1,
                    0,
                    EditOperation.moveEnd(new GeoPoint(47.1, -1.2))));
    String text = new String(sent, StandardCharsets.UTF_8);
    assertTrue(
        text.contains("\"operation\":{\"move_end\":{\"point\":{\"lat\":47.1,\"lon\":-1.2}}}"),
        text);
    assertTrue(!text.contains("resize"), text);
  }

  @Test
  void aRefusalOfAnEditIsReadWithItsReason() {
    handle(
        "/v1/generator/routes/edit",
        e -> {
          e.getRequestBody().readAllBytes();
          respond(
              e,
              422,
              "application/problem+json",
              "{\"status\":422,\"code\":\"generation_failed\",\"details\":{\"reason\":\"no_economy\"}}");
        });
    RouteGeneratorGateway g = running(Duration.ofSeconds(5));
    RouteGeneratorException e =
        assertThrows(
            RouteGeneratorException.class,
            () -> g.edit(TEAM, "{}".getBytes(StandardCharsets.UTF_8)));
    assertEquals(Kind.GENERATION_FAILED, e.kind());
    assertEquals("no_economy", e.reason());
  }

  @Test
  void aTooLargeBodyIsUnexpected() {
    handle(
        "/v1/generator/routes/edit",
        e -> {
          e.getRequestBody().readAllBytes();
          respond(
              e, 413, "application/problem+json", "{\"status\":413,\"code\":\"route_too_large\"}");
        });
    RouteGeneratorGateway g = running(Duration.ofSeconds(5));
    RouteGeneratorException e =
        assertThrows(
            RouteGeneratorException.class,
            () -> g.edit(TEAM, "{}".getBytes(StandardCharsets.UTF_8)));
    assertEquals(Kind.UNEXPECTED, e.kind());
  }
}
