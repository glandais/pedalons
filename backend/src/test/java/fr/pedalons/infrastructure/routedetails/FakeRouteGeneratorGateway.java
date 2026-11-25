package fr.pedalons.infrastructure.routedetails;

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
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

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

  /**
   * Whether {@code generator.edit} (api 1.17) is announced. Off by default: an engine in production
   * is 1.17.x and cannot edit.
   */
  public static volatile boolean editEnabled = false;

  /** Changes each edited route as the engine would have built it (to forge a bad one). */
  public static volatile @Nullable Consumer<ObjectNode> editTamper = null;

  /** The {@code generator.edit} the fake announces; a test may narrow it. */
  public static volatile RouteDetailsCapabilities.EditInfo editInfo =
      new RouteDetailsCapabilities.EditInfo(
          List.of("resize", "move_end"),
          List.of("road", "gravel", "mtb"),
          0.30,
          1000,
          0.05,
          500,
          3,
          50_000,
          4L * 1024 * 1024);

  /** An error answer the fake sends instead of the real one. */
  public record Problem(
      int status,
      String code,
      @Nullable String reason,
      @Nullable String state,
      @Nullable Integer retryAfter) {}

  /** The next answers of a generation, one per call, then the real ones. */
  public static final Queue<Problem> GENERATE_PROBLEMS = new ArrayDeque<>();

  /** The next answers of an edit, one per call, then the real ones. */
  public static final Queue<Problem> EDIT_PROBLEMS = new ArrayDeque<>();

  /** The body of every edit received, as text, in order. */
  public static final List<String> EDITS = new CopyOnWriteArrayList<>();

  /** The headers of every edit received, in order. */
  public static final List<Map<String, String>> EDIT_HEADERS = new CopyOnWriteArrayList<>();

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
    editEnabled = false;
    editTamper = null;
    editInfo =
        new RouteDetailsCapabilities.EditInfo(
            List.of("resize", "move_end"),
            List.of("road", "gravel", "mtb"),
            0.30,
            1000,
            0.05,
            500,
            3,
            50_000,
            4L * 1024 * 1024);
    EDIT_PROBLEMS.clear();
    EDITS.clear();
    EDIT_HEADERS.clear();
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
        } catch (JacksonException e) {
          throw new IllegalStateException(e);
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
        fresh || cached == null ? offroadRideTypes : cached,
        editEnabled ? editInfo : null);
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
    if (path.equals("/v1/generator/routes/edit") && method.equals("POST")) {
      return edit(call, team);
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
    } catch (JacksonException e) {
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
    } catch (JacksonException e) {
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
    if (!target.isMissingNode()
        && !offroadRideTypes.contains(request.path("ride_type").asString())) {
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

  // ------------------------------------------------------------------ the edit of a saved route

  /**
   * An edit: {@code resize} lengthens by an out and back in the middle, or shortens by cutting the
   * tip of the farthest point; {@code move_end} keeps the route up to its middle and goes straight
   * to the point. The proposals differ by the side of the detour. The saved route must be one that
   * comes back (an out and back) for a shortening to save anything.
   */
  private Exchange edit(Call call, String team) {
    String text = new String(call.body(), StandardCharsets.UTF_8);
    EDITS.add(text);
    EDIT_HEADERS.add(call.headers());
    Problem next = EDIT_PROBLEMS.poll();
    if (next != null) {
      return problem(next);
    }
    JsonNode request;
    try {
      request = JSON.readTree(call.body());
    } catch (JacksonException e) {
      return problem(new Problem(400, "invalid_input", null, null, null));
    }
    if (!request.path("network_edges").isObject()) {
      return problem(new Problem(400, "invalid_input", null, null, null));
    }
    List<double[]> original = new ArrayList<>();
    for (double[] p :
        fr.pedalons.infrastructure.valhalla.Polyline6Decoder.decode(
            request.path("polyline").asString())) {
      original.add(new double[] {p[1], p[0]}); // lat, lon
    }
    double length = 0;
    for (int i = 1; i < original.size(); i++) {
      length += step(original, i);
    }
    JsonNode operation = request.path("operation");
    ObjectNode response = JSON.createObjectNode();
    response.put("graph_id", graphId);
    response.put("mode", "team_first");
    response.putObject("overlay").put("deposited_at", clock.instant().toString());
    response.put("original_m", length);
    response.put("dropped", 0);
    ArrayNode routes = response.putArray("routes");
    if (operation.has("resize")) {
      double target = operation.path("resize").path("distance_m").asDouble();
      response.put("operation", "resize");
      response.put("target_m", target);
      for (int i = 0; i < routeCount; i++) {
        ObjectNode route =
            target >= length
                ? lengthen(original, length, target, i)
                : shorten(original, length, target);
        if (route == null) {
          return problem(new Problem(422, "generation_failed", "no_economy", null, null));
        }
        Consumer<ObjectNode> t = editTamper;
        if (t != null) {
          t.accept(route);
        }
        routes.add(route);
      }
    } else {
      JsonNode point = operation.path("move_end").path("point");
      response.put("operation", "move_end");
      response.putNull("target_m");
      for (int i = 0; i < routeCount; i++) {
        ObjectNode route =
            moveEnd(original, length, point.path("lat").asDouble(), point.path("lon").asDouble());
        Consumer<ObjectNode> t = editTamper;
        if (t != null) {
          t.accept(route);
        }
        routes.add(route);
      }
    }
    return json(200, response);
  }

  private static double step(List<double[]> p, int i) {
    return GeoDistance.haversineMeters(p.get(i - 1)[0], p.get(i - 1)[1], p.get(i)[0], p.get(i)[1]);
  }

  private static ObjectNode lengthen(
      List<double[]> original, double length, double target, int variant) {
    int m = original.size() / 2;
    double half = (target - length) / 2;
    double[] at = original.get(m);
    double cos = Math.cos(Math.toRadians(at[0]));
    double dLat = variant % 2 == 0 ? half / M_PER_DEGREE : 0;
    double dLon = variant % 2 == 1 ? half / M_PER_DEGREE / cos : 0;
    List<double[]> out = new ArrayList<>(original.subList(0, m + 1));
    out.add(new double[] {at[0] + dLat, at[1] + dLon});
    out.add(at);
    out.addAll(original.subList(m + 1, original.size()));
    double from = 0;
    for (int i = 1; i <= m; i++) {
      from += step(original, i);
    }
    return edited(out, "lengthen", null, from, from, target - length, m, m + 2, length, null);
  }

  private static @Nullable ObjectNode shorten(
      List<double[]> original, double length, double target) {
    int apex = 0;
    double far = 0;
    for (int i = 0; i < original.size(); i++) {
      double d =
          GeoDistance.haversineMeters(
              original.get(0)[0], original.get(0)[1], original.get(i)[0], original.get(i)[1]);
      if (d > far) {
        far = d;
        apex = i;
      }
    }
    for (int k = 1; apex - k >= 0 && apex + k < original.size(); k++) {
      List<double[]> out = new ArrayList<>(original.subList(0, apex - k + 1));
      out.addAll(original.subList(apex + k, original.size()));
      double len = 0;
      for (int i = 1; i < out.size(); i++) {
        len += step(out, i);
      }
      if (len <= target) {
        double from = 0;
        for (int i = 1; i <= apex - k; i++) {
          from += step(original, i);
        }
        double to = 0;
        for (int i = 1; i <= apex + k; i++) {
          to += step(original, i);
        }
        double chord = step(out, apex - k + 1);
        return edited(out, "shorten", null, from, to, chord, apex - k, apex - k + 1, length, null);
      }
    }
    return null;
  }

  private static ObjectNode moveEnd(
      List<double[]> original, double length, double lat, double lon) {
    int m = original.size() / 2;
    List<double[]> out = new ArrayList<>(original.subList(0, m + 1));
    double[] from = original.get(m);
    double leg = GeoDistance.haversineMeters(from[0], from[1], lat, lon);
    int steps = Math.max(1, (int) Math.ceil(leg / 1000));
    for (int i = 1; i <= steps; i++) {
      double f = (double) i / steps;
      out.add(new double[] {from[0] + (lat - from[0]) * f, from[1] + (lon - from[1]) * f});
    }
    double at = 0;
    for (int i = 1; i <= m; i++) {
      at += step(original, i);
    }
    return edited(out, "move_end", "best", at, length, leg, m, out.size() - 1, length, 5.0);
  }

  private static ObjectNode edited(
      List<double[]> points,
      String kind,
      @Nullable String variant,
      double fromM,
      double toM,
      double newM,
      int startIndex,
      int endIndex,
      double originalM,
      @Nullable Double endSnap) {
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
    r.put("kind", kind);
    if (variant == null) {
      r.putNull("variant");
    } else {
      r.put("variant", variant);
    }
    r.put("polyline", Polyline6Encoder.encode(lat, lon, 0, lat.length - 1));
    r.put("distance_m", length);
    r.putNull("error_share");
    double kept = Math.max(0, originalM - (toM - fromM));
    r.put("kept_m", kept);
    r.put("kept_share", originalM == 0 ? 0 : kept / originalM);
    r.putNull("abandoned_m");
    if (endSnap == null) {
      r.putNull("end_snap_m");
    } else {
      r.put("end_snap_m", endSnap);
    }
    r.put("unmatched_m", 0);
    ObjectNode c = r.putObject("changed");
    c.put("from_m", fromM);
    c.put("to_m", toM);
    c.put("new_m", newM);
    c.putArray("points").add(startIndex).add(endIndex);
    c.put("team_m", newM * 0.5);
    c.put("bridged_m", 0);
    c.put("team_share", 0.5);
    c.put("offroad_m", 0);
    c.put("offroad_share", 0.0);
    c.putArray("unpaved");
    c.put("crossings", 0);
    return r;
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
    } catch (JacksonException e) {
      throw new IllegalStateException(e);
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
    } catch (JacksonException e) {
      throw new IllegalStateException(e);
    }
  }
}
