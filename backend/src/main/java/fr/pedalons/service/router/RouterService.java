package fr.pedalons.service.router;

import static org.geolatte.geom.builder.DSL.*;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.addVerticalSystem;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.common.planner.UnpavedSpan;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.router.request.RouterEngine;
import fr.pedalons.dto.router.request.RouterEngineOption;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.dto.router.request.RouterRequest;
import fr.pedalons.dto.router.response.RouterEnginesResponse;
import fr.pedalons.dto.router.response.RouterEnginesResponse.RouterEngineOffer;
import fr.pedalons.dto.router.response.RouterResponse;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import fr.pedalons.infrastructure.routedetails.RouterEngineGateway;
import fr.pedalons.infrastructure.routedetails.RouterEngineV1;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import fr.pedalons.infrastructure.valhalla.StadiaMapsClient;
import fr.pedalons.infrastructure.valhalla.ValhallaErrors;
import fr.pedalons.infrastructure.valhalla.ValhallaLocation;
import fr.pedalons.infrastructure.valhalla.ValhallaRequest;
import fr.pedalons.infrastructure.valhalla.ValhallaResponse;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.route.planner.PolylineCodec;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.team.TeamService;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.geolatte.geom.G3D;
import org.geolatte.geom.LineString;
import org.geolatte.geom.crs.CoordinateReferenceSystem;
import org.geolatte.geom.crs.LinearUnit;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class RouterService {

  private static final Logger LOG = Logger.getLogger(RouterService.class);
  private static final CoordinateReferenceSystem<G3D> WGS84_3D =
      addVerticalSystem(WGS84, G3D.class, LinearUnit.METER);

  /** Valhalla "Path distance exceeds the max distance limit". */
  private static final int ERROR_PATH_DISTANCE_EXCEEDED = 154;

  /** Valhalla 170, 171, 441, 442: see {@link #toRoutingException}. */
  private static final Set<Integer> NO_ROUTE_CODES = Set.of(170, 171, 441, 442);

  @Inject @RestClient StadiaMapsClient stadiaMapsClient;

  @Inject GpxPipeline gpxPipeline;

  @Inject PlannerAccess plannerAccess;

  @Inject RouterEngineGateway routerEngine;

  @Inject TeamService teamService;

  @Inject MeterRegistry registry;

  /** The bicycle profiles the engine of osm-route-details calculates, with its ride type. */
  private static final Map<RouterProfile, String> ENGINE_RIDE_TYPES =
      Map.of(
          RouterProfile.BIKE, "road",
          RouterProfile.FASTBIKE, "road",
          RouterProfile.GRAVEL, "gravel",
          RouterProfile.MTB, "mtb");

  /** The geometry of a leg as an engine answered it, before the pipeline that both share. */
  private record RawLeg(List<double[]> coords, @Nullable List<int[]> rough) {}

  /**
   * The engines on offer: Stadia always, with its six profiles; the engine of osm-route-details
   * for the four bicycle profiles when it is configured and its cached capabilities announce it.
   * Same rights as the planner, no daily point: the call bills nothing.
   */
  @Logged
  public RouterEnginesResponse engines(@Nullable String teamSlug) {
    plannerAccess.check(teamSlug);
    List<RouterEngineOffer> offers = new ArrayList<>();
    offers.add(
        new RouterEngineOffer(RouterEngine.STADIA, List.of(RouterProfile.values()), List.of()));
    if (routerEngine.offered()) {
      offers.add(
          new RouterEngineOffer(
              RouterEngine.PEDALONS,
              List.of(
                  RouterProfile.BIKE,
                  RouterProfile.FASTBIKE,
                  RouterProfile.GRAVEL,
                  RouterProfile.MTB),
              engineOptions()));
    }
    return new RouterEnginesResponse(offers);
  }

  @Logged
  public RouterResponse getRoute(RouterRequest routerRequest) {
    // Every check comes before the call to an engine, whichever it is, and one point of the daily
    // counter pays for the leg even when the engine of osm-route-details fails and Stadia Maps
    // (billed
    // against a monthly quota) answers instead: the rights, the planner flag, the free plan's quota
    // and the caller's daily cap.
    plannerAccess.checkRouting(routerRequest.teamSlug());

    if (routerRequest.engine() == RouterEngine.PEDALONS) {
      String rideType = ENGINE_RIDE_TYPES.get(routerRequest.profile());
      if (rideType == null) {
        countEngine("stadia", "fallback_profile");
      } else {
        RawLeg leg = tryEngine(routerRequest, rideType);
        if (leg != null) {
          return finish(leg.coords(), leg.rough());
        }
      }
    } else {
      countEngine("stadia", "requested");
    }
    return routeWithStadia(routerRequest);
  }

  /**
   * The leg by the engine of osm-route-details, or null for any failure of it: the caller falls back
   * on Stadia Maps and the response says nothing. Only the cause, a fixed word, is counted and
   * logged: no coordinate, no team.
   */
  private @Nullable RawLeg tryEngine(RouterRequest routerRequest, String rideType) {
    if (!routerEngine.offered()) {
      return fallback("disabled");
    }
    // A leg past the engine's bound is refused by it as an invalid input: asked here instead, the
    // fallback costs no round trip and is counted under its own cause.
    double crowM =
        GeoDistance.haversineMeters(
            routerRequest.from().lat(),
            routerRequest.from().lng(),
            routerRequest.to().lat(),
            routerRequest.to().lng());
    if (routerEngine.crowMaxM().filter(max -> crowM > max).isPresent()) {
      return fallback("too_long");
    }
    try {
      String team = null;
      if (routerRequest.teamSlug() != null && !routerRequest.teamSlug().isBlank()) {
        team = TsidUtils.toString(teamService.getTeam(routerRequest.teamSlug()).getId());
      }
      // use_roads only reaches an engine that announces it (an older one refuses unknown fields).
      // The neutral is the profile's own value, the one Stadia is sent when the request has none.
      Double useRoads = null;
      Double useRoadsNeutral = null;
      if (routerEngine.acceptsUseRoads()) {
        useRoadsNeutral = profileUseRoads(routerRequest.profile());
        useRoads = routerRequest.useRoads() != null ? routerRequest.useRoads() : useRoadsNeutral;
      }
      Boolean avoidMainRoads =
          Boolean.TRUE.equals(routerRequest.avoidMainRoads())
                  && routerEngine.acceptsAvoidMainRoads()
              ? Boolean.TRUE
              : null;
      RouterEngineV1.Response answer =
          routerEngine.route(
              team,
              routerRequest.from().lat(),
              routerRequest.from().lng(),
              routerRequest.to().lat(),
              routerRequest.to().lng(),
              rideType,
              useRoads,
              useRoadsNeutral,
              avoidMainRoads);
      List<double[]> coords = Polyline6Decoder.decode(answer.polyline());
      if (coords.size() < 2) {
        return fallback("empty");
      }
      countEngine("pedalons", "ok");
      return new RawLeg(coords, engineRough(answer.unpaved(), coords.size()));
    } catch (RouteGeneratorException e) {
      return fallback(causeOf(e));
    } catch (RuntimeException e) {
      // An answer that does not decode (a polyline cut short) or a transport surprise
      return fallback("bad_response");
    }
  }

  private @Nullable RawLeg fallback(String cause) {
    countEngine("stadia", "fallback_" + cause);
    LOG.debugv("Router engine fell back on Stadia Maps: {0}", cause);
    return null;
  }

  private void countEngine(String engine, String outcome) {
    registry.counter("pedalons.router_engine", "engine", engine, "outcome", outcome).increment();
  }

  /** A fixed word for what the engine said: the cardinality of the counter stays low. */
  static String causeOf(RouteGeneratorException e) {
    if ("too_long".equals(e.code())) {
      return "too_long";
    }
    return switch (e.kind()) {
      case OUT_OF_COVERAGE -> "out_of_coverage";
      case GENERATION_FAILED ->
          switch (e.reason() == null ? "" : e.reason()) {
            case "start_too_far", "end_too_far" -> "too_far";
            default -> "no_route";
          };
      case OVERLOADED -> "overloaded";
      case TIMEOUT, READ_TIMEOUT -> "timeout";
      case DATA_UNAVAILABLE, NO_ANSWER, INSUFFICIENT_STORAGE -> "unavailable";
      case NOT_CONFIGURED -> "disabled";
      case OVERLAY_REQUIRED, DEPOSIT_IN_PROGRESS, UNEXPECTED -> "unexpected";
    };
  }

  /** The engine's unpaved ranges (inclusive indices of its polyline); null when it sent none. */
  private static @Nullable List<int[]> engineRough(
      @Nullable List<List<Integer>> unpaved, int size) {
    if (unpaved == null) {
      return null;
    }
    List<int[]> ranges = new ArrayList<>();
    for (List<Integer> r : unpaved) {
      if (r != null && r.size() == 2 && r.get(0) != null && r.get(1) != null) {
        ranges.add(new int[] {r.get(0), Math.min(r.get(1), size - 1)});
      }
    }
    return ranges;
  }

  private RouterResponse routeWithStadia(RouterRequest routerRequest) {
    ValhallaRequest valhallaRequest = getValhallaRequest(routerRequest);

    ValhallaResponse response;
    try {
      response = stadiaMapsClient.route(valhallaRequest);
    } catch (WebApplicationException e) {
      throw toRoutingException(e);
    } catch (ProcessingException e) {
      // A remote API behind a 15 s read timeout: DNS, TLS or a timeout land here, not above. The
      // exception class only, and no cause on the 503: its message may carry the host and path.
      // GlobalExceptionMapper logs a ServiceUnavailableException as one WARN line, without stack.
      LOG.warnv("Stadia Maps routing unreachable: {0}", e.getClass().getSimpleName());
      throw new ServiceUnavailableException(ErrorCode.ROUTING_UNAVAILABLE);
    }

    if (response.trip() == null || response.trip().legs().isEmpty()) {
      return new RouterResponse(linestring(WGS84_3D), 0, 0, null);
    }

    // Decode all leg shapes and concatenate coordinates
    List<double[]> allCoords =
        response.trip().legs().stream()
            .flatMap(leg -> Polyline6Decoder.decode(leg.shape()).stream())
            .toList();

    if (allCoords.isEmpty()) {
      throw new BusinessException(ErrorCode.UNKNOWN);
    }

    return finish(allCoords, roughRanges(response.trip().legs()));
  }

  /**
   * What both engines share: the raw geometry through the very same pipeline route import runs,
   * the unpaved ranges carried onto its output, and the raw shape the saved track derives from.
   *
   * @param allCoords the raw geometry, [lon, lat] pairs
   * @param rough the unpaved ranges as [begin, end] indices into it; null when nothing is known of
   *     the surface
   */
  private RouterResponse finish(List<double[]> allCoords, @Nullable List<int[]> rough) {
    // Convert to LineString<G3D> (elevation = 0, set by the pipeline below)
    G3D[] geomPoints = allCoords.stream().map(c -> g(c[0], c[1], 0.0)).toArray(G3D[]::new);
    LineString<G3D> rawRoute = linestring(WGS84_3D, geomPoints);

    // Stadia Maps bounds a bicycle route (500 km as the crow flies); the check repeats it on the
    // actual track before the resampling allocates (SEC-6).
    Path raw = toPath(rawRoute);
    GpxLimits.checkTracks(List.of(raw));

    // Resample / fix elevation / simplify — the very same pipeline route import runs, shared
    // rather than duplicated so the planner and an uploaded GPX cannot drift apart.
    Path path = gpxPipeline.process(raw, "route", ElevationQuality.FAST);

    // Convert back to LineString and compute metrics
    LineString<G3D> filteredRoute = toLineString3D(path);
    double dist = path.getTotalDistance();
    double ascend = path.getReportedElevationGain();

    // Surface (C1a): the engine's own unpaved ranges (Valhalla's rough flag, free). Absent when the
    // answer carries none (the caller then shows "unknown"), empty when everything is paved.
    List<UnpavedSpan> unpaved = null;
    if (rough != null) {
      double[] lon = new double[path.getSize()];
      double[] lat = new double[path.getSize()];
      for (int i = 0; i < lon.length; i++) {
        lon[i] = path.longitudeDeg(i);
        lat[i] = path.latitudeDeg(i);
      }
      unpaved = UnpavedSpans.project(allCoords, rough, lon, lat);
    }

    // The raw geometry (docs/LEDGER_*.md API-149, phase C), untouched: what the saved track is
    // derived from, so that the route is stored as the router drew it and simplified like a file.
    String shape = PolylineCodec.encode2(allCoords.toArray(double[][]::new));

    return new RouterResponse(filteredRoute, dist, ascend, unpaved, shape);
  }

  /**
   * The rough maneuvers of the legs as [begin, end] indices into the concatenated shape, or null
   * when a leg carries no maneuvers at all (then nothing is known about the surface). The legs'
   * shapes are concatenated as they are, so each leg's indices shift by the points before it.
   */
  static @Nullable List<int[]> roughRanges(List<ValhallaResponse.ValhallaLeg> legs) {
    List<int[]> ranges = new ArrayList<>();
    int offset = 0;
    for (ValhallaResponse.ValhallaLeg leg : legs) {
      if (leg.maneuvers() == null) {
        return null;
      }
      for (ValhallaResponse.ValhallaManeuver m : leg.maneuvers()) {
        if (Boolean.TRUE.equals(m.rough())) {
          ranges.add(new int[] {offset + m.beginShapeIndex(), offset + m.endShapeIndex()});
        }
      }
      offset += Polyline6Decoder.decode(leg.shape()).size();
    }
    return ranges;
  }

  /**
   * Maps a Stadia Maps error to a code the planner can tell apart. Only the status and the
   * Valhalla {@code error_code} are logged: the URL and the headers carry the API key.
   *
   * <p>The codes come from the Valhalla route API reference ("Internal error codes and
   * conditions", https://valhalla.github.io/valhalla/api/route/api-reference/), which Stadia Maps
   * relays in a JSON body {@code {"error_code": 154, "error": "...", "status_code": 400}}: 154 "Path
   * distance exceeds the max distance limit"; 170 "Locations are in unconnected regions", 171 "No
   * suitable edges near location", 441 "Location is unreachable" and 442 "No path could be found
   * for input" all mean there is no route. A 429 is the spent monthly quota (Stadia Maps
   * documentation, "Rate limits").
   */
  private static PedalonsException toRoutingException(WebApplicationException e) {
    int status = e.getResponse().getStatus();
    int valhallaCode = ValhallaErrors.errorCode(e.getResponse());
    LOG.warnv("Stadia Maps routing failed with status {0}, error_code {1}", status, valhallaCode);
    if (status == 429) {
      return new ServiceUnavailableException(ErrorCode.ROUTING_QUOTA_EXCEEDED);
    }
    if (status == 400) {
      if (valhallaCode == ERROR_PATH_DISTANCE_EXCEEDED) {
        return new BusinessException(ErrorCode.ROUTING_SEGMENT_TOO_LONG, e);
      }
      if (NO_ROUTE_CODES.contains(valhallaCode)) {
        return new BusinessException(ErrorCode.ROUTING_NO_ROUTE, e);
      }
      return new BusinessException(ErrorCode.UNKNOWN, e);
    }
    // 5xx, and anything unexpected (401/403 on a bad key, 404): the planner is out of order for
    // the caller, who did nothing wrong.
    return new ServiceUnavailableException(ErrorCode.ROUTING_UNAVAILABLE);
  }

  /** What the offered engine accepts, from its cached capabilities. */
  private List<RouterEngineOption> engineOptions() {
    List<RouterEngineOption> options = new ArrayList<>();
    if (routerEngine.acceptsUseRoads()) {
      options.add(RouterEngineOption.USE_ROADS);
    }
    if (routerEngine.acceptsAvoidMainRoads()) {
      options.add(RouterEngineOption.AVOID_MAIN_ROADS);
    }
    return options;
  }

  /** Valhalla's default {@code use_roads} of the bicycle costing, for a profile that has none. */
  static final double DEFAULT_USE_ROADS = 0.25;

  /**
   * The profile's own {@code use_roads}: the same {@link RouterProfile#getCostingOptions()} that is
   * sent to Stadia Maps, {@link #DEFAULT_USE_ROADS} when the profile does not carry the key.
   */
  static double profileUseRoads(RouterProfile profile) {
    return profile.getCostingOptions().get("use_roads") instanceof Number n
        ? n.doubleValue()
        : DEFAULT_USE_ROADS;
  }

  /**
   * The profile's costing options, with the request's {@code useHills} / {@code useRoads} replacing
   * the profile's value. Both apply to the bicycle costing only; absent, the result is the
   * profile's options untouched.
   */
  static Map<String, Object> mergeCostingOptions(RouterRequest routerRequest) {
    RouterProfile profile = routerRequest.profile();
    Map<String, Object> options = new HashMap<>(profile.getCostingOptions());
    if ("bicycle".equals(profile.getCosting())) {
      if (routerRequest.useHills() != null) {
        options.put("use_hills", routerRequest.useHills());
      }
      if (routerRequest.useRoads() != null) {
        options.put("use_roads", routerRequest.useRoads());
      }
    }
    return options;
  }

  static ValhallaRequest getValhallaRequest(RouterRequest routerRequest) {
    RouterProfile profile = routerRequest.profile();

    Map<String, Object> options = mergeCostingOptions(routerRequest);
    Map<String, Map<String, Object>> costingOptions =
        options.isEmpty() ? Map.of() : Map.of(profile.getCosting(), options);

    return new ValhallaRequest(
        List.of(
            new ValhallaLocation(routerRequest.from().lat(), routerRequest.from().lng()),
            new ValhallaLocation(routerRequest.to().lat(), routerRequest.to().lng())),
        profile.getCosting(),
        costingOptions);
  }

  private static Path toPath(LineString<G3D> geometry) {
    var positions = geometry.getPositions();
    List<CoordinatesElevation> coordinates = new ArrayList<>(positions.size());
    for (int i = 0; i < positions.size(); i++) {
      G3D pos = positions.getPositionN(i);
      coordinates.add(new LatLonElevation(pos.getLat(), pos.getLon(), pos.getCoordinate(2)));
    }
    return PathJvm.fromCoordinates(coordinates);
  }

  private static LineString<G3D> toLineString3D(Path path) {
    G3D[] geomPoints = new G3D[path.getSize()];
    for (int i = 0; i < path.getSize(); i++) {
      geomPoints[i] = g(path.longitudeDeg(i), path.latitudeDeg(i), path.elevation(i));
    }
    return linestring(WGS84_3D, geomPoints);
  }
}
