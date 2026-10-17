package fr.pedalons.service.router;

import static org.geolatte.geom.builder.DSL.*;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.addVerticalSystem;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.dto.router.request.RouterRequest;
import fr.pedalons.dto.router.response.RouterResponse;
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
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
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

  @Inject @RestClient StadiaMapsClient stadiaMapsClient;

  @Inject GpxPipeline gpxPipeline;

  @Logged
  public RouterResponse getRoute(RouterRequest routerRequest) {
    ValhallaRequest valhallaRequest = getValhallaRequest(routerRequest);

    ValhallaResponse response;
    try {
      response = stadiaMapsClient.route(valhallaRequest);
    } catch (WebApplicationException e) {
      // Status only: the URL and headers carry the API key. A 429 (spent Stadia Maps quota) or a
      // 5xx has no code of its own in ErrorCode; the planner shows a generic failure either way.
      LOG.warnv("Stadia Maps routing failed with status {0}", e.getResponse().getStatus());
      throw new BusinessException(ErrorCode.UNKNOWN);
    } catch (ProcessingException e) {
      // A remote API behind a 15 s read timeout: DNS, TLS or a timeout land here, not above. The
      // message names the host at most, never the header.
      LOG.warnv("Stadia Maps routing unreachable: {0}", e.getClass().getSimpleName());
      throw new BusinessException(ErrorCode.UNKNOWN);
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

    // Convert to LineString<G3D> (elevation = 0, will be fixed by SRTM)
    G3D[] geomPoints = allCoords.stream().map(c -> g(c[0], c[1], 0.0)).toArray(G3D[]::new);
    LineString<G3D> rawRoute = linestring(WGS84_3D, geomPoints);

    // Stadia Maps bounds a bicycle route (500 km as the crow flies); the check repeats it on the
    // actual track before the resampling allocates (SEC-6).
    Path raw = toPath(rawRoute);
    GpxLimits.checkTracks(List.of(raw));

    // Resample / fix elevation / simplify — the very same pipeline route import runs, shared
    // rather than duplicated so the planner and an uploaded GPX cannot drift apart.
    Path path = gpxPipeline.process(raw, "route");

    // Convert back to LineString and compute metrics
    LineString<G3D> filteredRoute = toLineString3D(path);
    double dist = path.getTotalDistance();
    double ascend = path.getReportedElevationGain();

    return new RouterResponse(filteredRoute, dist, ascend);
  }

  private static ValhallaRequest getValhallaRequest(RouterRequest routerRequest) {
    RouterProfile profile = routerRequest.profile();

    Map<String, Map<String, Object>> costingOptions =
        profile.getCostingOptions().isEmpty()
            ? Map.of()
            : Map.of(profile.getCosting(), profile.getCostingOptions());

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
