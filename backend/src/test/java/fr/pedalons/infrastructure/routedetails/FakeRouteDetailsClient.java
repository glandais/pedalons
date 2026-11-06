package fr.pedalons.infrastructure.routedetails;

import fr.pedalons.common.GeoDistance;
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

/**
 * osm-route-details in memory, behind {@link FakeRouteDetailsGateway} (plan §8, docs/LEDGER_*.md
 * API-150): no backend test may reach the service, nor IGN or Mapterhorn behind it.
 *
 * <p>The terrain is <b>flat</b> and differs by profile — {@link #FAST_ELEVATION} in {@code fast},
 * {@link #FULL_ELEVATION} in {@code full}, the values {@code FakeElevationProducer} gives its two
 * tiers — so a test can tell which profile computed a profile; the gain is therefore zero. One
 * segment, paved asphalt on the ground, covers the whole route. Every input point comes back once
 * (consecutive duplicates dropped, as the service does), with its own index.
 *
 * <p>The switches are static, as the gateway bean holds one instance; a test that sets one calls
 * {@link #reset()} afterwards.
 */
public class FakeRouteDetailsClient implements RouteDetailsClient {

  public static final double FAST_ELEVATION = 100.0;
  public static final double FULL_ELEVATION = 200.0;

  /** While true a {@code full} call answers a 503 {@code data_unavailable}, as IGN down does. */
  public static volatile boolean failFull = false;

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

  /** Every request received, in order. */
  public static final List<RouteDetailsRequest> REQUESTS = new CopyOnWriteArrayList<>();

  /**
   * The bounds {@link #capabilities()} publishes and {@link FakeRouteDetailsGateway#limits()}
   * answers without caching; a test may lower them to force slicing.
   */
  public static volatile RouteDetailsCapabilities.Limits limits =
      RouteDetailsCapabilities.FALLBACK_LIMITS;

  public static void reset() {
    failFull = false;
    partial = false;
    fallbackAfterError = false;
    limits = RouteDetailsCapabilities.FALLBACK_LIMITS;
    REQUESTS.clear();
  }

  @Override
  public RouteDetailsResponse routeDetails(RouteDetailsRequest request) {
    REQUESTS.add(request);
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
    List<double[]> latLon = latLon(request);
    double elevation = profile == RouteDetailsProfile.FAST ? FAST_ELEVATION : FULL_ELEVATION;
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
    for (int i = 0; i < latLon.size(); i++) {
      if (i > 0 && d[i] == d[i - 1]) {
        continue;
      }
      boolean missing = partial && d[i] > half;
      Double ele = missing ? null : elevation;
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
              0,
              0));
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

    Segment segment =
        new Segment(
            0,
            length,
            0,
            latLon.size() - 1,
            "ground",
            null,
            new Surface("paved", "asphalt", "tagged"),
            "minor_road",
            true);
    Summary summary =
        new Summary(
            length,
            0,
            0,
            elevation,
            elevation,
            List.of(),
            partial ? Map.of(origin, half, "none", length - half) : Map.of(origin, length));
    return new RouteDetailsResponse(
        new Meta("1.6", "test", profile.value(), null),
        partial ? RouteDetailsResponse.STATUS_PARTIAL : RouteDetailsResponse.STATUS_COMPLETE,
        points,
        List.of(segment),
        summary,
        new Quality(terrain, warnings, null));
  }

  @Override
  public RouteDetailsCapabilities capabilities() {
    return new RouteDetailsCapabilities(
        "1.6",
        limits,
        new RouteDetailsCapabilities.Enums(
            List.of("fast", "full"), List.of("asphalt", "concrete", "gravel")),
        new RouteDetailsCapabilities.Data(true));
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
      throw new WebApplicationException(
          Response.status(400)
              .type("application/problem+json")
              .entity("{\"status\":400,\"code\":\"invalid_input\"}")
              .build());
    }
    return out;
  }
}
