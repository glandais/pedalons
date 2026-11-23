package fr.pedalons.service.route.network;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.ErrorValidationDetails;
import fr.pedalons.dto.error.FieldError;
import fr.pedalons.dto.routes.request.RouteGeneratorRequest;
import fr.pedalons.dto.routes.response.GeneratedRouteDto;
import fr.pedalons.dto.routes.response.RouteGeneratorResponse;
import fr.pedalons.enums.RouteGeneratorType;
import fr.pedalons.enums.RouteGeneratorUnpaved;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway.Availability;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GenerateRequest;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GenerateResponse;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GeoPoint;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.OffroadResult;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.Route;
import fr.pedalons.service.router.PlannerAccess;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.team.TeamService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Proposes routes from the roads a team rides and the rest of the map, by asking the route
 * generator of osm-route-details (ledger docs/LEDGER_*.md API-198, lot 3b). Not transactional: no
 * database connection is held while the engine computes. The team's roads are prepared in the
 * engine by the nightly {@link RouteGeneratorOverlayJob}, never here.
 */
@ApplicationScoped
public class RouteGeneratorService {
  private static final Logger LOG = Logger.getLogger(RouteGeneratorService.class);

  /** The default of the cursor: mostly the team's roads, a little discovery. */
  static final double DEFAULT_DISCOVERY = 0.25;

  /**
   * The share of the route off pavement each level asks of the engine (ledger API-207, lot 5, the
   * owner's choice of 2026-11-23): the shares of the team routes the engine was measured on, a
   * third of them below LOW and a third above HIGH. They stay here, not in the contract, so they
   * can be tuned without touching the clients.
   */
  static final double UNPAVED_LOW = 0.25;

  static final double UNPAVED_USUAL = 0.47;
  static final double UNPAVED_HIGH = 0.60;

  /** The target of a level of unpaved share. */
  static double unpavedTarget(RouteGeneratorUnpaved level) {
    return switch (level) {
      case LOW -> UNPAVED_LOW;
      case USUAL -> UNPAVED_USUAL;
      case HIGH -> UNPAVED_HIGH;
    };
  }

  @Inject PlannerAccess plannerAccess;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject TeamService teamService;
  @Inject RouteGeneratorGuard guard;
  @Inject RouteGeneratorMetrics metrics;
  @Inject RouteGeneratorGateway gateway;
  @Inject GeneratedRouteAscent ascent;

  @ConfigProperty(name = "pedalons.route-generator.enabled", defaultValue = "true")
  boolean enabled;

  @Logged
  public RouteGeneratorResponse generate(String teamSlug, RouteGeneratorRequest request) {
    // Rights first, then the planner flag: a non-member learns nothing. Not checkRouting: no
    // routing provider is called, so no daily count and no quota (plan §3.4).
    plannerAccess.check(teamSlug);
    if (!enabled) {
      throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
    }
    Team team = teamService.getTeam(teamSlug);
    guard.admit(pedalonsContext.getDomainId(), pedalonsContext.getUser().getId());

    GenerateRequest engineRequest = engineRequest(team, request);
    Availability availability = gateway.configured() ? gateway.availability(false) : null;
    if (availability == null || !availability.usable()) {
      // Nothing is sent to a service that is off, or that predates the generator
      metrics.request("unavailable");
      throw new ServiceUnavailableException(ErrorCode.GENERATOR_UNAVAILABLE);
    }
    if (engineRequest.offroadTarget() != null
        && !availability.steersUnpaved(engineRequest.rideType())) {
      // An engine that does not steer this ride type would refuse the key (400): ask nothing, and
      // the answer carries no target either
      engineRequest = engineRequest.withoutOffroadTarget();
    }

    String teamRef = TsidUtils.toString(team.getId());
    long t0 = System.nanoTime();
    GenerateResponse answer;
    try {
      answer = gateway.generate(teamRef, engineRequest);
    } catch (RouteGeneratorException e) {
      Duration took = Duration.ofNanos(System.nanoTime() - t0);
      metrics.generated(took);
      metrics.request(RouteGeneratorErrors.outcome(e));
      PedalonsException mapped = RouteGeneratorErrors.of(e);
      if (RouteGeneratorErrors.isDrift(e)
          || e.kind() == RouteGeneratorException.Kind.NOT_CONFIGURED) {
        LOG.errorf("Route generator: unexpected answer for team %s: %s", teamRef, e.getMessage());
      } else {
        LOG.infof(
            "Route generator: team %s, %.0f km, %s, outcome %s, %d ms",
            teamRef,
            engineRequest.distanceM() / 1000,
            engineRequest.rideType(),
            e.kind().name().toLowerCase(Locale.ROOT)
                + (e.reason() == null ? "" : " (" + e.reason() + ")"),
            took.toMillis());
      }
      throw mapped;
    }
    metrics.generated(Duration.ofNanos(System.nanoTime() - t0));

    List<Route> kept = new ArrayList<>();
    List<GeneratedRouteSanity.Verdict> verdicts = new ArrayList<>();
    for (Route route : answer.routes() == null ? List.<Route>of() : answer.routes()) {
      GeneratedRouteSanity.Verdict verdict = GeneratedRouteSanity.check(engineRequest, route);
      if (verdict.sane()) {
        kept.add(route);
        verdicts.add(verdict);
      } else {
        metrics.dropped(verdict.failed().name());
        LOG.warnf(
            "Route generator: a route of team %s dropped by the sanity check %s (%.0f km asked)",
            teamRef, verdict.failed(), engineRequest.distanceM() / 1000);
      }
    }
    if (kept.isEmpty()) {
      metrics.request("no_route");
      throw new BusinessException(ErrorCode.GENERATOR_NO_ROUTE);
    }
    metrics.request("ok");

    List<GeneratedRouteAscent.Gain> gains =
        ascent.compute(kept.stream().map(Route::polyline).toList());
    List<GeneratedRouteDto> candidates = new ArrayList<>(kept.size());
    for (int i = 0; i < kept.size(); i++) {
      candidates.add(
          toDto(kept.get(i), verdicts.get(i), gains.get(i), engineRequest, answer.offroad()));
    }
    LOG.infof(
        "Route generator: team %s, %.0f km, %s, outcome ok, %d route(s), %d dropped, %d ms",
        teamRef,
        engineRequest.distanceM() / 1000,
        engineRequest.rideType(),
        candidates.size(),
        answer.dropped() + (answer.routes() == null ? 0 : answer.routes().size() - kept.size()),
        Duration.ofNanos(System.nanoTime() - t0).toMillis());
    return new RouteGeneratorResponse(
        candidates,
        answer.overlay() == null ? null : answer.overlay().depositedInstant(),
        answer.partialCoverage());
  }

  static GenerateRequest engineRequest(Team team, RouteGeneratorRequest request) {
    GeoPoint start;
    if (request.start() != null) {
      start = new GeoPoint(request.start().lat(), request.start().lng());
    } else {
      Point<G2D> location = team.getGeometry();
      if (location == null) {
        throw new BusinessException(
            ErrorCode.VALIDATION,
            new ErrorValidationDetails(
                List.of(new FieldError("start", "must be given: the team has no location"))),
            null);
      }
      start = new GeoPoint(location.getPosition().getLat(), location.getPosition().getLon());
    }
    GeoPoint end =
        request.end() == null ? null : new GeoPoint(request.end().lat(), request.end().lng());
    RouteGeneratorType type = request.type() == null ? RouteGeneratorType.ROAD : request.type();
    return new GenerateRequest(
        start,
        end,
        request.bearing() == null ? null : request.bearing().name(),
        request.distanceKm() * 1000,
        type.name().toLowerCase(Locale.ROOT),
        request.discovery() == null ? DEFAULT_DISCOVERY : request.discovery(),
        request.seed() == null ? 0 : request.seed(),
        steersUnpaved(type) ? unpavedTarget(unpavedLevel(request)) : null);
  }

  /** Only a ride that leaves the road has a share off pavement to ask for. */
  private static boolean steersUnpaved(RouteGeneratorType type) {
    return type == RouteGeneratorType.GRAVEL || type == RouteGeneratorType.MTB;
  }

  private static RouteGeneratorUnpaved unpavedLevel(RouteGeneratorRequest request) {
    return request.unpaved() == null ? RouteGeneratorUnpaved.USUAL : request.unpaved();
  }

  static GeneratedRouteDto toDto(
      Route r,
      GeneratedRouteSanity.Verdict verdict,
      GeneratedRouteAscent.@Nullable Gain gain,
      GenerateRequest sent,
      @Nullable OffroadResult offroad) {
    // Per route, not the engine's own flag: that one holds for its first route only, and the sanity
    // check may have dropped that one
    Double target = sent.offroadTarget() != null && offroad != null ? sent.offroadTarget() : null;
    Boolean reached =
        target == null ? null : Math.abs(r.offpavementShare() - target) <= offroad.tolerance();
    return new GeneratedRouteDto(
        r.polyline(),
        r.distanceM(),
        gain == null ? null : gain.ascentM(),
        gain == null ? null : gain.descentM(),
        r.bearingDeviationDeg(),
        r.teamShare(),
        r.offpavementShare(),
        target,
        reached,
        r.tailM(),
        r.crossings(),
        verdict.bounds());
  }
}
