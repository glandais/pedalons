package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import io.quarkus.test.Mock;
import jakarta.enterprise.context.ApplicationScoped;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;
import org.jspecify.annotations.Nullable;

/**
 * Replaces {@link RouteGeneratorGateway} in every {@code @QuarkusTest} (lot 3b plan §1), so that no
 * backend test reaches osm-route-details. As {@link FakeRouteDetailsGateway} does for the altitude,
 * it overrides the seam {@link RouteGeneratorGateway#exchange} only: the JSON, the problems of RFC
 * 9457, the headers and the NDJSON framing run as in production, on an engine in memory at the
 * level of the HTTP message.
 *
 * <p>The engine in memory keeps a team's overlay under (key, team), answers a loop or a one-way
 * route that satisfies the sanity check, and refuses what the real one refuses (a missing
 * overlay below cursor 1, a deposit without its last line). The switches are static, the bean
 * being one; a test that sets one calls {@link #reset()} in its {@code @BeforeEach}.
 */
@Mock
@ApplicationScoped
public class FakeRouteGeneratorGateway extends RouteGeneratorGateway {

  private static final ObjectMapper JSON = new ObjectMapper();

  /** The api the fake announces: below 1.9 the generator is not served. */
  public static volatile String apiVersion = "1.9";

  public static volatile boolean generatorEnabled = true;
  public static volatile String graphId = "graph-test";

  /** The clock the stored overlays are dated with. */
  public static volatile java.time.Clock clock = java.time.Clock.systemUTC();

  /** Routes the engine proposes, 1 to 3. */
  public static volatile int routeCount = 2;

  /** The ride types the fake announces under {@code generator.offroad} (api 1.14); empty: none. */
  public static volatile List<String> offroadRideTypes = List.of("gravel", "mtb");

  /**
   * The ride types the cached capabilities still announce, when they differ from {@link
   * #offroadRideTypes} (an engine rolled back within the hour); null: the same.
   */
  public static volatile @Nullable List<String> cachedOffroadRideTypes = null;

  /** The {@code offroad.tolerance} the fake answers with. */
  public static volatile double offroadTolerance = 0.05;

  /** The {@code offroad_share} of every route; null leaves it out, as an engine of api 1.13. */
  public static volatile @Nullable Double offroadShare = null;

  /** True: the answer to a target carries no {@code offroad} object. */
  public static volatile boolean omitOffroadResult = false;

  /** True: {@code coverage = partial}. */
  public static volatile boolean partial = false;

  /** Changes each route as the engine would have built it (to forge a bad one). */
  public static volatile @Nullable Consumer<ObjectNode> tamper = null;

  /** An error answer the fake sends instead of the real one. */
  public record Problem(
      int status,
      String code,
      @Nullable String reason,
      @Nullable String state,
      @Nullable Integer retryAfter) {}

  /** The next answers of a generation, one per call, then the real ones. */
  public static final Queue<Problem> GENERATE_PROBLEMS = new ArrayDeque<>();

  /** The next answers of a deposit, one per call, then the real ones. */
  public static final Queue<Problem> DEPOSIT_PROBLEMS = new ArrayDeque<>();

  /** What the service holds: team reference to its overlay. */
  public static final Map<String, StoredOverlay> OVERLAYS = new ConcurrentHashMap<>();

  /** Every call received, in order (the body of a deposit is in {@link #DEPOSITS}). */
  public static final List<Call> CALLS = new CopyOnWriteArrayList<>();

  /** Every deposit received. */
  public static final List<Deposit> DEPOSITS = new CopyOnWriteArrayList<>();

  /** An overlay held by the engine. */
  public static final class StoredOverlay {
    public String state = "ready";
    public String digest;
    public Instant depositedAt;
    public Instant expiresAt;

    StoredOverlay(String digest, Instant depositedAt, Instant expiresAt) {
      this.digest = digest;
      this.depositedAt = depositedAt;
      this.expiresAt = expiresAt;
    }
  }

  /** A deposit: who, with which digest, and the lines of its body. */
  public record Deposit(String team, @Nullable String digest, List<String> lines) {}

  public static void reset() {
    apiVersion = "1.9";
    generatorEnabled = true;
    graphId = "graph-test";
    clock = java.time.Clock.systemUTC();
    routeCount = 2;
    partial = false;
    offroadRideTypes = List.of("gravel", "mtb");
    cachedOffroadRideTypes = null;
    offroadTolerance = 0.05;
    offroadShare = null;
    omitOffroadResult = false;
    tamper = null;
    GENERATE_PROBLEMS.clear();
    DEPOSIT_PROBLEMS.clear();
    OVERLAYS.clear();
    CALLS.clear();
    DEPOSITS.clear();
  }

  /** The key of the test profile, as {@code application.properties} sets it. */
  public static final String TEST_KEY = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8";

  /** The engine holds a ready overlay of the team (its TSID) under the test key. */
  public static void markReady(String team, String digest) {
    Instant now = clock.instant();
    OVERLAYS.put(
        TEST_KEY + "/" + team, new StoredOverlay(digest, now, now.plus(Duration.ofDays(14))));
  }

  /** The overlay of the team, or null. */
  public static @Nullable StoredOverlay overlayOf(String team) {
    return OVERLAYS.get(TEST_KEY + "/" + team);
  }

  /** Calls that reached the engine for this method and path. */
  public static long calls(String method, String path) {
    return CALLS.stream().filter(c -> c.method().equals(method) && c.path().equals(path)).count();
  }

  /** What a generation call carried: its headers and its JSON body. */
  public record Seen(Map<String, String> headers, JsonNode body) {}

  /** The last generation the engine received, or null. */
  public static @Nullable Seen lastGenerate() {
    for (int i = CALLS.size() - 1; i >= 0; i--) {
      Call c = CALLS.get(i);
      if (c.path().equals("/v1/generator/routes")) {
        try {
          return new Seen(c.headers(), JSON.readTree(c.body()));
        } catch (IOException e) {
          throw new UncheckedIOException(e);
        }
      }
    }
    return null;
  }

  @Override
  public Availability availability(boolean fresh) {
    boolean recent = apiVersion.compareTo("1.9") >= 0;
    if (!recent || !generatorEnabled) {
      return Availability.unavailable();
    }
    List<String> cached = cachedOffroadRideTypes;
    return new Availability(
        true,
        graphId,
        16L * 1024 * 1024,
        10_000,
        14,
        200_000,
        fresh || cached == null ? offroadRideTypes : cached);
  }

  @Override
  Exchange exchange(Call call) {
    CALLS.add(call);
    String key = call.headers().get(KEY_HEADER);
    String team = call.headers().get(TEAM_HEADER);
    if (key == null || key.length() != NamespaceKey.LENGTH || team == null) {
      return problem(new Problem(400, "invalid_input", null, null, null));
    }
    String path = call.path();
    String method = call.method();
    if (path.equals("/v1/generator/overlay")) {
      return switch (method) {
        case "GET" -> status(key, team);
        case "DELETE" -> {
          OVERLAYS.remove(key + "/" + team);
          yield new Exchange(204, null, null, new byte[0]);
        }
        case "PUT" -> deposit(call, key, team);
        default -> problem(new Problem(405, "method_not_allowed", null, null, null));
      };
    }
    if (path.equals("/v1/generator/routes") && method.equals("POST")) {
      return generate(call, key, team);
    }
    return problem(new Problem(404, "not_found", null, null, null));
  }

  private Exchange status(String key, String team) {
    StoredOverlay o = OVERLAYS.get(key + "/" + team);
    ObjectNode n = JSON.createObjectNode();
    n.put("graph_id", graphId);
    if (o == null) {
      n.put("state", "absent");
    } else {
      n.put("state", o.state);
      n.put("deposited_at", o.depositedAt.toString());
      n.put("expires_at", o.expiresAt.toString());
      n.put("source_digest", o.digest);
      n.put("edges", 10);
    }
    return json(200, n);
  }

  private Exchange deposit(Call call, String key, String team) {
    Problem next = DEPOSIT_PROBLEMS.poll();
    ByteArrayOutputStream body = new ByteArrayOutputStream();
    if (next != null) {
      return problem(next);
    }
    try {
      call.writer().write(body);
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
    String text = body.toString(StandardCharsets.UTF_8);
    List<String> lines = new ArrayList<>(List.of(text.split("\n")));
    String digest = call.headers().get(DIGEST_HEADER);
    DEPOSITS.add(new Deposit(team, digest, lines));
    if (!text.endsWith("\n") || lines.isEmpty()) {
      return problem(new Problem(400, "invalid_input", null, null, null));
    }
    String last = lines.get(lines.size() - 1);
    try {
      JsonNode end = JSON.readTree(last).path("end");
      if (!end.has("tracks") || end.get("tracks").asInt() != lines.size() - 1) {
        return problem(new Problem(400, "invalid_input", null, null, null));
      }
    } catch (IOException e) {
      return problem(new Problem(400, "invalid_input", null, null, null));
    }
    Instant now = clock.instant();
    OVERLAYS.put(key + "/" + team, new StoredOverlay(digest, now, now.plus(Duration.ofDays(14))));
    ObjectNode report = JSON.createObjectNode();
    report.put("graph_id", graphId);
    report.put("deposited_at", now.toString());
    report.put("expires_at", now.plus(Duration.ofDays(14)).toString());
    report.put("tracks", lines.size() - 1);
    report.put("tracks_excluded", 0);
    report.put("tracks_unreadable", 0);
    report.put("edges", 10);
    report.put("team_km", 12.5);
    report.put("stored_bytes", text.length());
    ObjectNode km = report.putObject("km");
    km.put("total", 12.5).put("outside", 0).put("matched", 12.5);
    return json(200, report);
  }

  private Exchange generate(Call call, String key, String team) {
    Problem next = GENERATE_PROBLEMS.poll();
    if (next != null) {
      return problem(next);
    }
    JsonNode request;
    try {
      request = JSON.readTree(call.body());
    } catch (IOException e) {
      return problem(new Problem(400, "invalid_input", null, null, null));
    }
    double cursor = request.path("cursor").asDouble(-1);
    StoredOverlay overlay = OVERLAYS.get(key + "/" + team);
    if (cursor < 1 && (overlay == null || !overlay.state.equals("ready"))) {
      return problem(
          new Problem(409, "overlay_required", null, overlay == null ? "absent" : "stale", null));
    }
    double lat = request.path("start").path("lat").asDouble();
    double lon = request.path("start").path("lon").asDouble();
    double distance = request.path("distance_m").asDouble();
    JsonNode end = request.path("end");
    ObjectNode response = JSON.createObjectNode();
    response.put("graph_id", graphId);
    response.put("mode", cursor >= 1 ? "discovery" : cursor <= 0 ? "strict" : "team_first");
    response.put("coverage", partial ? "partial" : "inside");
    response.put("dropped", 0);
    if (overlay != null && cursor < 1) {
      response.putObject("overlay").put("deposited_at", overlay.depositedAt.toString());
    } else {
      response.putNull("overlay");
    }
    JsonNode target = request.path("offroad_target");
    if (!target.isMissingNode() && !offroadRideTypes.contains(request.path("ride_type").asText())) {
      // the strict JSON of an engine that does not steer this ride type (api 1.13, or a road ride)
      return problem(new Problem(400, "invalid_input", null, null, null));
    }
    if (target.isNumber() && !omitOffroadResult) {
      // the engine steers: the outcome is about the first route
      Double share = offroadShare;
      ObjectNode result = response.putObject("offroad");
      result.put("target", target.asDouble());
      result.put("tolerance", offroadTolerance);
      result.put(
          "reached",
          Math.abs((share == null ? 0.1 : share) - target.asDouble()) <= offroadTolerance);
      result.put("steps", 1);
    } else {
      response.putNull("offroad");
    }
    ArrayNode routes = response.putArray("routes");
    for (int i = 0; i < routeCount; i++) {
      ObjectNode route =
          end.isMissingNode() || end.isNull()
              ? loop(lat, lon, distance, i)
              : trip(lat, lon, end.path("lat").asDouble(), end.path("lon").asDouble(), distance);
      Consumer<ObjectNode> t = tamper;
      if (t != null) {
        t.accept(route);
      }
      routes.add(route);
    }
    return json(200, response);
  }

  private static final double M_PER_DEGREE = Math.toRadians(1) * GeoDistance.EARTH_RADIUS_METERS;

  /** Out and back from the start, towards north, east or south by turn: a loop of {@code d}. */
  private static ObjectNode loop(double lat, double lon, double d, int variant) {
    double dLat = variant % 3 == 0 ? 1 : variant % 3 == 2 ? -1 : 0;
    double dLon = variant % 3 == 1 ? 1 : 0;
    double cos = Math.cos(Math.toRadians(lat));
    List<double[]> out = new ArrayList<>();
    int steps = Math.max(2, (int) Math.ceil(d / 2 / 1000));
    for (int i = 0; i <= steps; i++) {
      double m = d / 2 * i / steps;
      out.add(new double[] {lat + dLat * m / M_PER_DEGREE, lon + dLon * m / M_PER_DEGREE / cos});
    }
    List<double[]> all = new ArrayList<>(out);
    for (int i = out.size() - 2; i >= 0; i--) {
      all.add(out.get(i));
    }
    return route(all, d);
  }

  /** From the start to the end through a detour to the north that makes the distance {@code d}. */
  private static ObjectNode trip(double lat, double lon, double endLat, double endLon, double d) {
    double direct = GeoDistance.haversineMeters(lat, lon, endLat, endLon);
    double half = d / 2;
    double h = half > direct / 2 ? Math.sqrt(half * half - direct * direct / 4) : 0;
    double midLat = (lat + endLat) / 2 + h / M_PER_DEGREE;
    double midLon = (lon + endLon) / 2;
    List<double[]> all = new ArrayList<>();
    addLeg(all, lat, lon, midLat, midLon);
    addLeg(all, midLat, midLon, endLat, endLon);
    return route(all, d);
  }

  private static void addLeg(List<double[]> all, double la, double lo, double lb, double lob) {
    double len = GeoDistance.haversineMeters(la, lo, lb, lob);
    int steps = Math.max(1, (int) Math.ceil(len / 1000));
    for (int i = all.isEmpty() ? 0 : 1; i <= steps; i++) {
      double f = (double) i / steps;
      all.add(new double[] {la + (lb - la) * f, lo + (lob - lo) * f});
    }
  }

  private static ObjectNode route(List<double[]> points, double asked) {
    double[] lat = new double[points.size()];
    double[] lon = new double[points.size()];
    double length = 0;
    for (int i = 0; i < lat.length; i++) {
      lat[i] = points.get(i)[0];
      lon[i] = points.get(i)[1];
      if (i > 0) {
        length += GeoDistance.haversineMeters(lat[i - 1], lon[i - 1], lat[i], lon[i]);
      }
    }
    ObjectNode r = JSON.createObjectNode();
    r.put("polyline", Polyline6Encoder.encode(lat, lon, 0, lat.length - 1));
    r.put("distance_m", length);
    r.put("team_m", length * 0.75);
    r.put("bridged_m", length * 0.05);
    r.put("team_share", 0.8);
    r.put("tail_m", asked / 2);
    r.put("crossings", 0);
    r.put("unpaved_m", length * 0.1);
    r.put("unpaved_share", 0.1);
    Double offroad = offroadShare;
    if (offroad != null) {
      r.put("offroad_m", length * offroad);
      r.put("offroad_share", offroad);
    }
    r.put("presumed_surface_m", 0);
    r.put("family", "turnaround");
    r.put("start_snap_m", 5);
    r.put("end_snap_m", 5);
    r.putNull("bearing_deviation_deg");
    r.putNull("ascent_m");
    r.putNull("descent_m");
    return r;
  }

  private static Exchange json(int status, JsonNode body) {
    try {
      return new Exchange(status, "application/json", null, JSON.writeValueAsBytes(body));
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  private static Exchange problem(Problem p) {
    ObjectNode n = JSON.createObjectNode();
    n.put("type", "urn:osm-route-details:problem:" + p.code());
    n.put("title", p.code());
    n.put("status", p.status());
    n.put("detail", p.code());
    n.put("code", p.code());
    if (p.reason() != null || p.state() != null) {
      ObjectNode details = n.putObject("details");
      if (p.reason() != null) {
        details.put("reason", p.reason());
      }
      if (p.state() != null) {
        details.put("state", p.state());
      }
    }
    try {
      return new Exchange(
          p.status(),
          "application/problem+json",
          p.retryAfter() == null ? null : String.valueOf(p.retryAfter()),
          JSON.writeValueAsBytes(n));
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }
}
