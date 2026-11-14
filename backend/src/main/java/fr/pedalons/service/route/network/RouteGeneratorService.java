package fr.pedalons.service.route.network;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.ErrorValidationDetails;
import fr.pedalons.dto.error.FieldError;
import fr.pedalons.dto.routes.request.RouteGeneratorRequest;
import fr.pedalons.dto.routes.response.BoundsDto;
import fr.pedalons.dto.routes.response.GeneratedRouteDto;
import fr.pedalons.dto.routes.response.RouteGeneratorNetworkDto;
import fr.pedalons.dto.routes.response.RouteGeneratorResponse;
import fr.pedalons.enums.CompassPoint;
import fr.pedalons.enums.RouteGeneratorType;
import fr.pedalons.service.route.generator.Bearing8;
import fr.pedalons.service.route.generator.GeneratedRoute;
import fr.pedalons.service.route.generator.GeneratorDiagnostics;
import fr.pedalons.service.route.generator.GeneratorRequest;
import fr.pedalons.service.route.generator.GeneratorResult;
import fr.pedalons.service.route.generator.GeneratorStoppedException;
import fr.pedalons.service.route.generator.LatLon;
import fr.pedalons.service.route.generator.RideType;
import fr.pedalons.service.route.generator.RouteGenerator;
import fr.pedalons.service.route.planner.PolylineCodec;
import fr.pedalons.service.router.PlannerAccess;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.team.TeamService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Proposes routes made of the roads a team already rides (ledger docs/LEDGER_*.md API-198, lot 3
 * plan §3). Not transactional: the graph comes from {@link TeamNetworkCache}, which reads in its own
 * short transactions, and no database connection is held while the engine computes.
 */
@ApplicationScoped
public class RouteGeneratorService {
  private static final Logger LOG = Logger.getLogger(RouteGeneratorService.class);
  private static final double DEFAULT_FAMILIARITY = 0.5;

  @Inject PlannerAccess plannerAccess;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject TeamService teamService;
  @Inject TeamNetworkCache networkCache;
  @Inject RouteGeneratorGuard guard;
  @Inject RouteGeneratorMetrics metrics;

  @ConfigProperty(name = "pedalons.route-generator.enabled", defaultValue = "true")
  boolean enabled;

  private final RouteGenerator routeGenerator = new RouteGenerator();

  @Logged
  public RouteGeneratorResponse generate(String teamSlug, RouteGeneratorRequest request) {
    // Rights first, then the planner flag: a non-member learns nothing. Not checkRouting: no
    // routing provider is called, so no daily count and no quota (plan §3.4).
    plannerAccess.check(teamSlug);
    if (!enabled) {
      throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
    }
    Team team = teamService.getTeam(teamSlug);
    long domainId = pedalonsContext.getDomainId();
    guard.admit(domainId, pedalonsContext.getUser().getId());

    GeneratorRequest engineRequest = engineRequest(team, request);
    long teamId = team.getId();
    long t0 = System.nanoTime();
    TeamNetwork network = lookup(teamId, domainId);
    long t1 = System.nanoTime();
    TeamNetworkSummary summary = network.summary();
    if (network.graph().edgeCount() == 0) {
      metrics.request("network_too_small");
      throw RouteGeneratorErrors.networkTooSmall(summary);
    }

    GeneratorResult result;
    try {
      result =
          guard.withPermit(
              () -> routeGenerator.generate(network.graph(), engineRequest, guard.deadline()));
    } catch (GeneratorStoppedException e) {
      long ms = Duration.ofNanos(System.nanoTime() - t1).toMillis();
      LOG.warnf(
          "Route generator stopped after %d ms: team %d, %.0f km, %s, %s",
          ms,
          teamId,
          engineRequest.distanceM() / 1000,
          engineRequest.type(),
          engineRequest.end() == null ? "loop" : "trip");
      metrics.request("stopped");
      throw new ServiceUnavailableException(ErrorCode.ROUTE_GENERATOR_BUSY);
    }
    long t2 = System.nanoTime();
    metrics.generated(Duration.ofNanos(t2 - t1));

    if (result instanceof GeneratorResult.Failure f) {
      log(teamId, engineRequest, f.reason().name(), f.detail(), f.diagnostics(), t0, t1, t2);
      metrics.request(f.reason().name());
      throw RouteGeneratorErrors.of(f.reason(), summary);
    }
    GeneratorResult.Success ok = (GeneratorResult.Success) result;
    log(teamId, engineRequest, "OK", null, ok.diagnostics(), t0, t1, t2);
    metrics.request("ok");
    List<GeneratedRouteDto> candidates = new ArrayList<>(ok.routes().size());
    for (GeneratedRoute r : ok.routes()) {
      candidates.add(toDto(r));
    }
    return new RouteGeneratorResponse(
        candidates,
        new RouteGeneratorNetworkDto(
            ok.networkLengthM(),
            summary.totalLengthM(),
            summary.routeCount(),
            summary.pendingRouteCount(),
            summary.excludedRouteCount(),
            summary.incomplete()),
        ok.familiarityFallback());
  }

  private TeamNetwork lookup(long teamId, long domainId) {
    return networkCache.lookup(teamId, domainId);
  }

  private static GeneratorRequest engineRequest(Team team, RouteGeneratorRequest request) {
    LatLon start;
    if (request.start() != null) {
      start = new LatLon(request.start().lat(), request.start().lng());
    } else {
      Point<G2D> location = team.getGeometry();
      if (location == null) {
        throw new BusinessException(
            ErrorCode.VALIDATION,
            new ErrorValidationDetails(
                List.of(new FieldError("start", "must be given: the team has no location"))),
            null);
      }
      start = new LatLon(location.getPosition().getLat(), location.getPosition().getLon());
    }
    LatLon end =
        request.end() == null ? null : new LatLon(request.end().lat(), request.end().lng());
    CompassPoint bearing = request.bearing();
    RouteGeneratorType type = request.type();
    return new GeneratorRequest(
        start,
        end,
        bearing == null ? null : Bearing8.valueOf(bearing.name()),
        request.distanceKm() * 1000,
        request.familiarity() == null ? DEFAULT_FAMILIARITY : request.familiarity(),
        type == null ? RideType.ROAD : RideType.valueOf(type.name()),
        request.seed() == null ? 0 : request.seed());
  }

  static GeneratedRouteDto toDto(GeneratedRoute r) {
    List<LatLon> points = r.points();
    double[][] lngLat = new double[points.size()][];
    double minLon = Double.POSITIVE_INFINITY;
    double minLat = Double.POSITIVE_INFINITY;
    double maxLon = Double.NEGATIVE_INFINITY;
    double maxLat = Double.NEGATIVE_INFINITY;
    for (int i = 0; i < lngLat.length; i++) {
      LatLon p = points.get(i);
      lngLat[i] = new double[] {p.lon(), p.lat()};
      minLon = Math.min(minLon, p.lon());
      maxLon = Math.max(maxLon, p.lon());
      minLat = Math.min(minLat, p.lat());
      maxLat = Math.max(maxLat, p.lat());
    }
    return new GeneratedRouteDto(
        PolylineCodec.encode2(lngLat),
        r.distanceM(),
        r.ascentM(),
        r.descentM(),
        r.bearingDeviationDeg(),
        r.familiarity(),
        r.unpavedShare(),
        r.sharedM(),
        r.crossings(),
        new BoundsDto(minLon, minLat, maxLon, maxLat));
  }

  /** One INFO line per request. No coordinates: a start point is often someone's home. */
  private static void log(
      long teamId,
      GeneratorRequest r,
      String outcome,
      @Nullable String detail,
      GeneratorDiagnostics d,
      long t0,
      long t1,
      long t2) {
    LOG.infof(
        "Route generator: team %d, %.0f km, %s, %s, outcome %s%s, lookup %d ms, generate %d ms,"
            + " candidates loop %d/%d polygon %d/%d",
        teamId,
        r.distanceM() / 1000,
        r.type(),
        r.end() == null ? "loop" : "trip",
        outcome,
        detail == null ? "" : " (" + detail + ")",
        Duration.ofNanos(t1 - t0).toMillis(),
        Duration.ofNanos(t2 - t1).toMillis(),
        d.validLoop(),
        d.loopCandidates(),
        d.validPolygon(),
        d.polygonCandidates());
  }
}
