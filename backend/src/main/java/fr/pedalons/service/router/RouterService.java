package fr.pedalons.service.router;

import static org.geolatte.geom.builder.DSL.*;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.addVerticalSystem;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.dto.router.request.RouterRequest;
import fr.pedalons.dto.router.response.RouterResponse;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import fr.pedalons.infrastructure.valhalla.StadiaMapsClient;
import fr.pedalons.infrastructure.valhalla.ValhallaLocation;
import fr.pedalons.infrastructure.valhalla.ValhallaRequest;
import fr.pedalons.infrastructure.valhalla.ValhallaResponse;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.security.annotation.Logged;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import java.io.IOException;
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

@ApplicationScoped
public class RouterService {

  private static final Logger LOG = Logger.getLogger(RouterService.class);
  private static final CoordinateReferenceSystem<G3D> WGS84_3D =
      addVerticalSystem(WGS84, G3D.class, LinearUnit.METER);

  /** Valhalla "Path distance exceeds the max distance limit". */
  private static final int ERROR_PATH_DISTANCE_EXCEEDED = 154;

  /** Valhalla 170, 171, 441, 442: see {@link #toRoutingException}. */
  private static final Set<Integer> NO_ROUTE_CODES = Set.of(170, 171, 441, 442);

  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

  @Inject @RestClient StadiaMapsClient stadiaMapsClient;

  @Inject GpxPipeline gpxPipeline;

  @Inject PlannerAccess plannerAccess;

  @Logged
  public RouterResponse getRoute(RouterRequest routerRequest) {
    // Every check comes before the call to Stadia Maps, which is billed against a monthly quota.
    plannerAccess.check(routerRequest.teamSlug());
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
      return new RouterResponse(linestring(WGS84_3D), 0, 0);
    }

    // Decode all leg shapes and concatenate coordinates
    List<double[]> allCoords =
        response.trip().legs().stream()
            .flatMap(leg -> Polyline6Decoder.decode(leg.shape()).stream())
            .toList();

    if (allCoords.isEmpty()) {
      throw new BusinessException(ErrorCode.UNKNOWN);
    }

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

    return new RouterResponse(filteredRoute, dist, ascend);
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
    int valhallaCode = readValhallaErrorCode(e.getResponse());
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

  /** The Valhalla {@code error_code} of an error body, or -1 when it is empty or not JSON. */
  private static int readValhallaErrorCode(Response response) {
    try {
      if (!response.hasEntity()) {
        return -1;
      }
      String body = response.readEntity(String.class);
      if (body == null || body.isBlank()) {
        return -1;
      }
      JsonNode code = OBJECT_MAPPER.readTree(body).path("error_code");
      return code.isInt() ? code.asInt() : -1;
    } catch (RuntimeException | IOException ex) {
      // Empty, truncated or HTML body: the status alone decides.
      return -1;
    }
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
