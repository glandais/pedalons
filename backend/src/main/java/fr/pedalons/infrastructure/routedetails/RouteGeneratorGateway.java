package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException.Kind;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.DepositReport;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GenerateRequest;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GenerateResponse;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.OverlayStatus;
import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import java.io.IOException;
import java.io.OutputStream;
import java.net.ConnectException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpConnectTimeoutException;
import java.net.http.HttpRequest;
import java.net.http.HttpRequest.BodyPublisher;
import java.net.http.HttpRequest.BodyPublishers;
import java.net.http.HttpResponse;
import java.net.http.HttpResponse.BodyHandlers;
import java.net.http.HttpTimeoutException;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The route generator of osm-route-details (api 1.9) over HTTP, on the url of the {@code
 * osm-route-details} REST client (lot 3b plan §1). Plain {@code java.net.http}, HTTP/1.1, no
 * redirect: headers per call, a streamed body for the deposit and timeouts of their own (the same
 * choice as {@code BiketeamExportClient}). {@code Ord-Namespace-Key} and {@code Ord-Team} (the
 * team's TSID) go with every call, the cursor 1 included.
 *
 * <p><b>Faked in tests by overriding {@link #exchange}</b>, the one place where bytes meet the
 * network, as {@code FakeRouteDetailsGateway} does for the altitude: the JSON, the problems of RFC
 * 9457, the headers and the NDJSON framing still run in a test.
 *
 * <p>Never logs the key, a team's reference, a digest or a coordinate.
 */
@ApplicationScoped
public class RouteGeneratorGateway {

  private static final Logger LOG = Logger.getLogger(RouteGeneratorGateway.class);

  static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(3);
  static final String KEY_HEADER = "Ord-Namespace-Key";
  static final String TEAM_HEADER = "Ord-Team";
  static final String DIGEST_HEADER = "Ord-Source-Digest";

  @ConfigProperty(name = "quarkus.rest-client.osm-route-details.url")
  String url;

  @ConfigProperty(name = "pedalons.route-generator.namespace-key")
  Optional<String> configuredKey;

  @ConfigProperty(name = "pedalons.route-generator.generate-timeout", defaultValue = "PT35S")
  Duration generateTimeout;

  @ConfigProperty(name = "pedalons.route-generator.overlay.deposit-timeout", defaultValue = "PT16M")
  Duration depositTimeout;

  @Inject ObjectMapper mapper;
  @Inject RouteDetailsGateway routeDetails;

  private volatile @Nullable HttpClient http;
  private volatile @Nullable NamespaceKey key;

  /** Writes the body of a request to the stream it is given. */
  @FunctionalInterface
  public interface BodyWriter {
    void write(OutputStream out) throws IOException;
  }

  /** One call, as {@link #exchange} receives it. */
  record Call(
      String method,
      String path,
      Map<String, String> headers,
      byte @Nullable [] body,
      @Nullable BodyWriter writer,
      Duration timeout) {}

  /** The answer to a call. */
  record Exchange(
      int status, @Nullable String contentType, @Nullable String retryAfter, byte[] body) {}

  /** What the capabilities say of the generator, read on the cache or fresh. */
  public record Availability(
      boolean usable,
      @Nullable String graphId,
      long maxDocumentBytes,
      long maxTracks,
      long overlayTtlDays,
      double distanceMMax,
      List<String> offroadRideTypes) {

    /** Without the ride types that take a target of unpaved share: none does. */
    public Availability(
        boolean usable,
        @Nullable String graphId,
        long maxDocumentBytes,
        long maxTracks,
        long overlayTtlDays,
        double distanceMMax) {
      this(usable, graphId, maxDocumentBytes, maxTracks, overlayTtlDays, distanceMMax, List.of());
    }

    /** Whether the engine steers the unpaved share of a ride of this type ({@code gravel}). */
    public boolean steersUnpaved(String rideType) {
      return offroadRideTypes.contains(rideType);
    }

    public static Availability unavailable() {
      return new Availability(false, null, 0, 0, 14, 200_000);
    }
  }

  /**
   * In {@code %prod} an empty key, or one that is not 43 base64url characters, stops the start (the start-first
   * deploy keeps the old backend); elsewhere a missing key is a warning and every call answers
   * {@code NOT_CONFIGURED}.
   */
  void onStart(@Observes StartupEvent event) {
    String text = configuredKey.map(String::trim).orElse("");
    if (text.isEmpty()) {
      if (io.quarkus.runtime.LaunchMode.current() == io.quarkus.runtime.LaunchMode.NORMAL) {
        // The compose file's :? lets a blank value through: the start-first deploy keeps the old
        // backend instead of running one that answers GENERATOR_UNAVAILABLE for ever
        throw new IllegalStateException(
            "pedalons.route-generator.namespace-key is empty (ROUTE_GENERATOR_NAMESPACE_KEY)");
      }
      LOG.warn("Route generator: no namespace key configured, the generator is unavailable");
      return;
    }
    key = NamespaceKey.parse(text);
  }

  /** Whether a key is configured (and well formed). */
  public boolean configured() {
    return key() != null;
  }

  private @Nullable NamespaceKey key() {
    NamespaceKey k = key;
    if (k != null) {
      return k;
    }
    String text = configuredKey.map(String::trim).orElse("");
    if (text.isEmpty()) {
      return null;
    }
    try {
      k = NamespaceKey.parse(text);
    } catch (IllegalArgumentException e) {
      return null;
    }
    key = k;
    return k;
  }

  /**
   * Whether the service serves the generator (api at least 1.9, {@code generator.enabled}) and
   * its bounds; {@code fresh} reads the capabilities again, past the cache. Never throws.
   */
  public Availability availability(boolean fresh) {
    Optional<RouteDetailsCapabilities> capabilities =
        fresh ? routeDetails.freshCapabilities() : routeDetails.capabilities();
    if (capabilities.isEmpty() || !capabilities.get().generatorEnabled()) {
      return Availability.unavailable();
    }
    RouteDetailsCapabilities.GeneratorSection g = capabilities.get().generator();
    RouteDetailsCapabilities.DepositLimits deposit =
        g.limits() == null ? null : g.limits().deposit();
    return new Availability(
        true,
        g.graph() == null ? null : g.graph().id(),
        deposit == null ? 16L * 1024 * 1024 : deposit.maxDocumentBytes(),
        deposit == null ? 10_000 : deposit.maxTracks(),
        g.overlayTtlDays() == null ? 14 : g.overlayTtlDays(),
        g.limits() == null ? 200_000 : g.limits().distanceMMax(),
        g.offroad() == null || g.offroad().rideTypes() == null
            ? List.of()
            : g.offroad().rideTypes());
  }

  /** {@code POST /v1/generator/routes}. */
  public GenerateResponse generate(String team, GenerateRequest request) {
    byte[] body;
    try {
      body = mapper.writeValueAsBytes(request);
    } catch (IOException e) {
      throw RouteGeneratorException.of(Kind.UNEXPECTED, e);
    }
    Exchange answer =
        call(
            new Call(
                "POST",
                "/v1/generator/routes",
                headers(team, "application/json"),
                body,
                null,
                generateTimeout));
    return read(answer, GenerateResponse.class);
  }

  /** {@code GET /v1/generator/overlay}. */
  public OverlayStatus status(String team) {
    Exchange answer =
        call(
            new Call(
                "GET",
                "/v1/generator/overlay",
                headers(team, null),
                null,
                null,
                Duration.ofSeconds(10)));
    return read(answer, OverlayStatus.class);
  }

  /** {@code DELETE /v1/generator/overlay}: 204 whether or not there was one. */
  public void delete(String team) {
    call(
        new Call(
            "DELETE",
            "/v1/generator/overlay",
            headers(team, null),
            null,
            null,
            Duration.ofSeconds(10)));
  }

  /**
   * {@code PUT /v1/generator/overlay}: streams {@code writer}'s NDJSON. The thread that calls
   * writes, the HTTP client reads through a bounded pipe. The request asks for {@code Expect:
   * 100-continue}: a service that refuses before reading the body (409, 503) answers before any
   * byte of it is written. A service that answers during the body and keeps the connection open is
   * not seen until the whole body is sent (a limit of the JDK client), and the writer then runs to
   * its end.
   *
   * @throws RouteGeneratorException the service's refusal or no answer
   * @throws RuntimeException what {@code writer} throws, when the pipe did not stop it
   */
  public DepositReport deposit(String team, String digest, BodyWriter writer) {
    Map<String, String> headers = headers(team, "application/x-ndjson");
    headers.put(DIGEST_HEADER, digest);
    Exchange answer =
        call(new Call("PUT", "/v1/generator/overlay", headers, null, writer, depositTimeout));
    return read(answer, DepositReport.class);
  }

  private Map<String, String> headers(String team, @Nullable String contentType) {
    NamespaceKey k = key();
    if (k == null) {
      throw RouteGeneratorException.of(Kind.NOT_CONFIGURED, null);
    }
    Map<String, String> h = new LinkedHashMap<>();
    h.put(KEY_HEADER, k.reveal());
    h.put(TEAM_HEADER, team);
    h.put("Accept", "application/json, application/problem+json");
    if (contentType != null) {
      h.put("Content-Type", contentType);
    }
    return h;
  }

  private Exchange call(Call call) {
    Exchange answer = exchange(call);
    if (answer.status() >= 200 && answer.status() < 300) {
      return answer;
    }
    throw RouteGeneratorProblems.classify(
        answer.status(), answer.body(), answer.retryAfter(), mapper);
  }

  private <T> T read(Exchange answer, Class<T> type) {
    try {
      T value = mapper.readValue(answer.body(), type);
      if (value == null) {
        throw RouteGeneratorException.of(Kind.UNEXPECTED, null);
      }
      return value;
    } catch (IOException e) {
      throw RouteGeneratorException.of(Kind.UNEXPECTED, e);
    }
  }

  /**
   * The only place where bytes meet the network; the seam the test fake overrides.
   *
   * @throws RouteGeneratorException {@code NO_ANSWER} or {@code READ_TIMEOUT}
   */
  Exchange exchange(Call call) {
    HttpRequest.Builder builder =
        HttpRequest.newBuilder(URI.create(url + call.path())).timeout(call.timeout());
    call.headers().forEach(builder::header);
    HttpClient client = client();
    if (call.writer() == null) {
      BodyPublisher body =
          call.body() == null ? BodyPublishers.noBody() : BodyPublishers.ofByteArray(call.body());
      HttpRequest request = builder.method(call.method(), body).build();
      try {
        return toExchange(client.send(request, BodyHandlers.ofByteArray()));
      } catch (IOException e) {
        throw noAnswer(e);
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        throw RouteGeneratorException.of(Kind.NO_ANSWER, e);
      }
    }
    return stream(client, builder, call);
  }

  private Exchange stream(HttpClient client, HttpRequest.Builder builder, Call call) {
    long deadline = System.nanoTime() + call.timeout().toNanos();
    // The JDK client hands the response over only once the whole body is sent, unless the server
    // closes the connection. With Expect: 100-continue a refusal given before the body is read
    // (409 deposit_in_progress, 503 overloaded) comes back before the first byte of it.
    builder.expectContinue(true);
    CompletableFuture<HttpResponse<byte[]>> future = new CompletableFuture<>();
    DepositBodyPipe pipe = new DepositBodyPipe(future::isDone, deadline);
    HttpRequest request =
        builder.method(call.method(), BodyPublishers.ofInputStream(pipe::reader)).build();
    client
        .sendAsync(request, BodyHandlers.ofByteArray())
        .whenComplete((response, failure) -> {
          if (failure != null) {
            future.completeExceptionally(failure);
          } else {
            future.complete(response);
          }
        });
    OutputStream out = pipe.writer();
    try {
      call.writer().write(out);
      out.close();
    } catch (IOException | RuntimeException e) {
      if (!pipe.stopped()) {
        pipe.fail();
        future.cancel(true);
        throw e instanceof RuntimeException r
            ? r
            : new java.io.UncheckedIOException((IOException) e);
      }
    }
    try {
      return toExchange(
          future.get(call.timeout().toNanos() + 5_000_000_000L, TimeUnit.NANOSECONDS));
    } catch (ExecutionException e) {
      Throwable cause = e.getCause();
      if (cause instanceof java.util.concurrent.CompletionException c && c.getCause() != null) {
        cause = c.getCause();
      }
      throw cause instanceof IOException io
          ? noAnswer(io)
          : RouteGeneratorException.of(Kind.NO_ANSWER, cause);
    } catch (TimeoutException e) {
      throw RouteGeneratorException.of(Kind.READ_TIMEOUT, e);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw RouteGeneratorException.of(Kind.NO_ANSWER, e);
    }
  }

  private static Exchange toExchange(HttpResponse<byte[]> response) {
    return new Exchange(
        response.statusCode(),
        response.headers().firstValue("Content-Type").orElse(null),
        response.headers().firstValue("Retry-After").orElse(null),
        response.body());
  }

  /** A connect failure is no answer; a timeout after the connection is a read timeout. */
  private static RouteGeneratorException noAnswer(IOException e) {
    boolean connect = e instanceof ConnectException || e instanceof HttpConnectTimeoutException;
    if (!connect && e instanceof HttpTimeoutException) {
      return RouteGeneratorException.of(Kind.READ_TIMEOUT, e);
    }
    return RouteGeneratorException.of(Kind.NO_ANSWER, e);
  }

  private HttpClient client() {
    HttpClient c = http;
    if (c == null) {
      synchronized (this) {
        c = http;
        if (c == null) {
          c =
              HttpClient.newBuilder()
                  .version(HttpClient.Version.HTTP_1_1)
                  .connectTimeout(CONNECT_TIMEOUT)
                  .followRedirects(HttpClient.Redirect.NEVER)
                  .build();
          http = c;
        }
      }
    }
    return c;
  }
}
