package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Edge;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.EdgeNode;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Meta;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.OutputPoint;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Quality;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Summary;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Surface;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.TerrainRange;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Warning;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.Response;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.BiFunction;
import java.util.function.DoubleFunction;
import java.util.function.DoubleUnaryOperator;
import org.jspecify.annotations.Nullable;

/**
 * osm-route-details in memory, behind {@link FakeRouteDetailsGateway} (plan §8, docs/LEDGER_*.md
 * API-150): no backend test may reach the service, nor IGN or Mapterhorn behind it.
 *
 * <p>The terrain is <b>flat</b> and differs by profile — {@link #FAST_ELEVATION} in {@code fast},
 * {@link #FULL_ELEVATION} in {@code full} — so a test can tell which profile computed a profile;
 * the gain is therefore zero, unless {@link #terrain} replaces it. One segment, paved asphalt on
 * the ground, covers the whole route, unless {@link #segmentsOf} replaces it; like the service, the
 * fake answers no {@code segments} when the {@code typology} section is left out. Every input point
 * comes back once (consecutive duplicates dropped, as the service does), with its own index; no
 * breakpoint is inserted, which only {@code RouteDetailsTrackTest} and the recorded fixture cover.
 *
 * <p><b>Edges</b> (api 1.7): the fake announces api {@link #apiVersion} (1.7 by default, with
 * {@code data.edges}). A request with {@code options.edges} gets one synthetic edge per run of
 * three answer points ({@code z14:<i>:<i>} nodes, a polyline6 of the points, the gains of the
 * terrain), unless {@link #edgesOf} replaces them or {@link #noEdges} drops them. Below 1.7 the
 * option is a 400, as the real service answers an unknown key.
 *
 * <p>The switches are static, as the gateway bean holds one instance; a test that sets one calls
 * {@link #reset()} afterwards.
 */
public class FakeRouteDetailsClient implements RouteDetailsClient {

  public static final double FAST_ELEVATION = 100.0;
  public static final double FULL_ELEVATION = 200.0;

  /** {@code meta.data_versions} of every answer. */
  public static final JsonNode DATA_VERSIONS =
      JsonNodeFactory.instance.objectNode().put("osm", "2026-11-01");

  /** While true a {@code full} call answers a 503 {@code data_unavailable}, as IGN down does. */
  public static volatile boolean failFull = false;

  /**
   * While true a {@code fast} call answers a 503 {@code overloaded}, as a saturated service does:
   * the only way a {@code fast} call fails, Mapterhorn being read on its own.
   */
  public static volatile boolean failFast = false;

  /**
   * When set, the elevation at {@code d_m} on both profiles, in place of the flat ones: {@code ele}
   * and {@code ele_smoothed} are its value, {@code gain_cum_m} and {@code loss_cum_m} the running
   * sums of its deltas between the returned points. {@code d_m} starts again in each slice: a test
   * that lowers {@link #limits} keeps the terrain flat.
   */
  public static volatile @Nullable DoubleUnaryOperator terrain = null;

  /**
   * While true the second half of the route has no elevation: {@code status: partial}, {@code ele}
   * null there, terrain {@code none} and an {@code elevation_missing} warning.
   */
  public static volatile boolean partial = false;

  /**
   * While true the terrain is Mapterhorn's after an error of the primary source ({@code
   * fallback_after_error}), as a {@code full} call during an IGN outage answers with {@code
   * accept_partial}.
   */
  public static volatile boolean fallbackAfterError = false;

  /**
   * When set, the typology of a route of the given length, in place of the paved one; see {@link
   * #segment}; null answers no {@code segments} at all. {@code from_m} and {@code to_m} start again
   * in each slice: a test that lowers {@link #limits} keeps the default.
   */
  public static volatile @Nullable DoubleFunction<List<Segment>> segmentsOf = null;

  /** The api version the fake announces; the edges need 1.7 or more. */
  public static volatile String apiVersion = "1.7";

  /** While true an answer to a request with {@code edges} carries none. */
  public static volatile boolean noEdges = false;

  /**
   * When set, the edges of an answer in place of the synthetic ones: given the request and the
   * answer's points.
   */
  public static volatile @Nullable BiFunction<RouteDetailsRequest, List<OutputPoint>, List<Edge>>
      edgesOf = null;

  /** The options of the last request received, null before any. */
  public static volatile @Nullable RouteDetailsOptions lastOptions = null;

  /** Every request received, in order. */
  public static final List<RouteDetailsRequest> REQUESTS = new CopyOnWriteArrayList<>();

  /**
   * The bounds {@link #capabilities()} publishes and {@link FakeRouteDetailsGateway#limits()}
   * answers without caching; a test may lower them to force slicing.
   */
  public static volatile RouteDetailsCapabilities.Limits limits =
      RouteDetailsCapabilities.FALLBACK_LIMITS;

  /** A stretch of {@link #segmentsOf}; a null {@code surfaceClass} has no surface at all. */
  public static Segment segment(
      double from,
      double to,
      @Nullable String surfaceClass,
      @Nullable String detail,
      @Nullable String wayKind) {
    return new Segment(
        from,
        to,
        0,
        0,
        "ground",
        null,
        surfaceClass == null ? null : new Surface(surfaceClass, detail, "tagged"),
        wayKind,
        true);
  }

  public static void reset() {
    failFull = false;
    failFast = false;
    terrain = null;
    partial = false;
    fallbackAfterError = false;
    segmentsOf = null;
    apiVersion = "1.7";
    noEdges = false;
    edgesOf = null;
    lastOptions = null;
    limits = RouteDetailsCapabilities.FALLBACK_LIMITS;
    REQUESTS.clear();
  }

  @Override
  public RouteDetailsResponse routeDetails(RouteDetailsRequest request) {
    REQUESTS.add(request);
    lastOptions = request.options();
    boolean edgesAsked = request.options() != null && request.options().wantsEdges();
    if (edgesAsked && !edgesSupported()) {
      throw invalidInput();
    }
    RouteDetailsProfile profile = request.effectiveProfile();
    if (failFull && profile == RouteDetailsProfile.FULL) {
      throw new WebApplicationException(
          Response.status(503)
              .header(HttpHeaders.RETRY_AFTER, "30")
              .type("application/problem+json")
              .entity(
                  "{\"type\":\"about:blank\",\"title\":\"Data unavailable\",\"status\":503,"
                      + "\"code\":\"data_unavailable\",\"detail\":\"IGN down (test)\"}")
              .build());
    }
    if (failFast && profile == RouteDetailsProfile.FAST) {
      throw new WebApplicationException(
          Response.status(503)
              .header(HttpHeaders.RETRY_AFTER, "5")
              .type("application/problem+json")
              .entity(
                  "{\"type\":\"about:blank\",\"title\":\"Overloaded\",\"status\":503,"
                      + "\"code\":\"overloaded\",\"detail\":\"saturated (test)\"}")
              .build());
    }
    List<double[]> latLon = latLon(request);
    double flat = profile == RouteDetailsProfile.FAST ? FAST_ELEVATION : FULL_ELEVATION;
    DoubleUnaryOperator relief = terrain;
    boolean smoothed =
        request.options() != null
            && request.options().elevation() != null
            && request.options().elevation().smoothingM() != null;

    double[] d = new double[latLon.size()];
    for (int i = 1; i < d.length; i++) {
      double[] a = latLon.get(i - 1);
      double[] b = latLon.get(i);
      d[i] = d[i - 1] + GeoDistance.haversineMeters(a[0], a[1], b[0], b[1]);
    }
    double length = d[d.length - 1];
    double half = length / 2;

    List<OutputPoint> points = new ArrayList<>(latLon.size());
    double gain = 0;
    double loss = 0;
    double lowest = Double.POSITIVE_INFINITY;
    double highest = Double.NEGATIVE_INFINITY;
    Double previous = null;
    for (int i = 0; i < latLon.size(); i++) {
      if (i > 0 && d[i] == d[i - 1]) {
        continue;
      }
      boolean missing = partial && d[i] > half;
      Double ele =
          missing ? null : Double.valueOf(relief == null ? flat : relief.applyAsDouble(d[i]));
      if (ele != null) {
        if (previous != null) {
          gain += Math.max(0, ele - previous);
          loss += Math.max(0, previous - ele);
        }
        previous = ele;
        lowest = Math.min(lowest, ele);
        highest = Math.max(highest, ele);
      }
      points.add(
          new OutputPoint(
              d[i],
              i,
              RouteDetailsResponse.ORIGIN_INPUT,
              null,
              null,
              null,
              ele,
              smoothed ? ele : null,
              missing ? "none" : "dem",
              gain,
              loss));
    }
    if (points.size() < 2) {
      // Contract §5.2: fewer than two distinct points once rounded to polyline6
      throw invalidInput();
    }

    String origin =
        profile == RouteDetailsProfile.FAST || fallbackAfterError ? "mapterhorn" : "ign_lidar_hd";
    List<TerrainRange> terrain = new ArrayList<>();
    List<Warning> warnings = new ArrayList<>();
    if (partial) {
      terrain.add(new TerrainRange(0, half, origin, true, fallbackAfterError));
      terrain.add(new TerrainRange(half, length, "none", false, false));
      warnings.add(new Warning("elevation_missing", "no elevation (test)", half, length));
    } else {
      terrain.add(new TerrainRange(0, length, origin, true, fallbackAfterError));
    }
    if (fallbackAfterError) {
      warnings.add(new Warning("terrain_fallback", "IGN failed (test)", 0.0, length));
    }

    Summary summary =
        new Summary(
            length,
            gain,
            loss,
            lowest,
            highest,
            List.of(),
            partial ? Map.of(origin, half, "none", length - half) : Map.of(origin, length));
    return new RouteDetailsResponse(
        new Meta(apiVersion, "test", profile.value(), DATA_VERSIONS),
        partial ? RouteDetailsResponse.STATUS_PARTIAL : RouteDetailsResponse.STATUS_COMPLETE,
        points,
        typology(request, d, length),
        summary,
        new Quality(terrain, warnings, null),
        edgesAsked && !noEdges ? edges(request, points, latLon) : null);
  }

  private static boolean edgesSupported() {
    return new RouteDetailsCapabilities(
            apiVersion,
            null,
            null,
            new RouteDetailsCapabilities.Data(
                true, new RouteDetailsCapabilities.EdgesFeature("z14", 14, 4096, 6)))
        .supportsEdges();
  }

  /** One edge per run of three answer points, or the test's own. */
  private static List<Edge> edges(
      RouteDetailsRequest request, List<OutputPoint> points, List<double[]> latLon) {
    BiFunction<RouteDetailsRequest, List<OutputPoint>, List<Edge>> custom = edgesOf;
    if (custom != null) {
      return custom.apply(request, points);
    }
    List<Edge> edges = new ArrayList<>();
    for (int i = 0; i + 2 < points.size(); i += 2) {
      OutputPoint a = points.get(i);
      OutputPoint b = points.get(i + 2);
      List<double[]> line = new ArrayList<>();
      for (int k = i; k <= i + 2; k++) {
        line.add(latLon.get(points.get(k).index()));
      }
      double length = b.dM() - a.dM();
      edges.add(
          new Edge(
              a.dM(),
              b.dM(),
              a.index(),
              b.index(),
              node(i, latLon.get(a.index())),
              node(i + 2, latLon.get(b.index())),
              false,
              length,
              length,
              0.0,
              length,
              "both",
              EdgePolylines.encode(line),
              a.gainCumM(),
              b.gainCumM(),
              a.lossCumM(),
              b.lossCumM(),
              "ground",
              new Surface("paved", "asphalt", "tagged"),
              "minor_road",
              null,
              null,
              null));
    }
    return edges;
  }

  private static EdgeNode node(int i, double[] latLon) {
    return new EdgeNode("z14:" + i + ":" + i, latLon[0], latLon[1], 3);
  }

  /** The {@code segments} of an answer, null when its section was not asked for. */
  private static @Nullable List<Segment> typology(
      RouteDetailsRequest request, double[] d, double length) {
    List<RouteDetailsSection> sections =
        request.options() == null ? null : request.options().sections();
    if (sections != null && !sections.contains(RouteDetailsSection.TYPOLOGY)) {
      return null;
    }
    DoubleFunction<List<Segment>> custom = segmentsOf;
    if (custom == null) {
      return List.of(
          new Segment(
              0,
              length,
              0,
              d.length - 1,
              "ground",
              null,
              new Surface("paved", "asphalt", "tagged"),
              "minor_road",
              true));
    }
    List<Segment> segments = custom.apply(length);
    if (segments == null) {
      return null;
    }
    return segments.stream()
        .map(s ->
            new Segment(
                s.fromM(),
                s.toM(),
                indexAt(d, s.fromM()),
                indexAt(d, s.toM()),
                s.structure(),
                s.structureSource(),
                s.surface(),
                s.wayKind(),
                s.matched()))
        .toList();
  }

  /** The last input point at or before {@code position}. */
  private static int indexAt(double[] d, double position) {
    int index = 0;
    while (index + 1 < d.length && d[index + 1] <= position) {
      index++;
    }
    return index;
  }

  @Override
  public RouteDetailsCapabilities capabilities() {
    return new RouteDetailsCapabilities(
        apiVersion,
        limits,
        new RouteDetailsCapabilities.Enums(
            List.of("fast", "full"), List.of("asphalt", "concrete", "gravel")),
        new RouteDetailsCapabilities.Data(
            true,
            edgesSupported()
                ? new RouteDetailsCapabilities.EdgesFeature("z14", 14, 4096, 6)
                : null));
  }

  /** The input as {@code [lat, lon]} pairs, from the polyline or the points. */
  private static List<double[]> latLon(RouteDetailsRequest request) {
    List<double[]> out = new ArrayList<>();
    if (request.polyline() != null) {
      if (request.polylinePrecision() == null
          || request.polylinePrecision() != RouteDetailsRequest.POLYLINE_PRECISION) {
        throw new WebApplicationException(Response.status(400).build());
      }
      for (double[] lonLat : Polyline6Decoder.decode(request.polyline())) {
        out.add(new double[] {lonLat[1], lonLat[0]});
      }
    } else if (request.points() != null) {
      for (RouteDetailsRequest.Point p : request.points()) {
        out.add(new double[] {p.lat(), p.lon()});
      }
    }
    if (out.size() < 2) {
      throw invalidInput();
    }
    return out;
  }

  private static WebApplicationException invalidInput() {
    return new WebApplicationException(
        Response.status(400)
            .type("application/problem+json")
            .entity("{\"status\":400,\"code\":\"invalid_input\"}")
            .build());
  }
}
