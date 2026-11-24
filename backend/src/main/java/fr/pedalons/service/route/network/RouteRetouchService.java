package fr.pedalons.service.route.network;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.ErrorValidationDetails;
import fr.pedalons.dto.error.FieldError;
import fr.pedalons.dto.routes.request.RouteRetouchEnd;
import fr.pedalons.dto.routes.request.RouteRetouchRequest;
import fr.pedalons.dto.routes.response.BoundsDto;
import fr.pedalons.dto.routes.response.RetouchedRouteDto;
import fr.pedalons.dto.routes.response.RetouchedSpanDto;
import fr.pedalons.dto.routes.response.RouteRetouchOfferDto;
import fr.pedalons.dto.routes.response.RouteRetouchResponse;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.RetouchKind;
import fr.pedalons.enums.RetouchVariant;
import fr.pedalons.enums.RouteGeneratorType;
import fr.pedalons.enums.RouteRetouchOperation;
import fr.pedalons.enums.RouteRetouchUnavailable;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.infrastructure.routedetails.RouteDetailsCapabilities.EditInfo;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway.Availability;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.EditOperation;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.EditRequest;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.EditResponse;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.EditedRoute;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.place.PlaceRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.GpxTrackRepository.RetouchHead;
import fr.pedalons.repository.route.GpxTrackRepository.RetouchSource;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.route.planner.PolylineCodec;
import fr.pedalons.service.router.PlannerAccess;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.team.TeamService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.geolatte.geom.G2D;
import org.geolatte.geom.LineString;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Retouches a saved route by asking the route generator's engine to change one stretch of it
 * (docs/LEDGER_*.md API-212, docs/plans/2026-11-24-retouche-parcours-lot7c.md). Not transactional:
 * the reads each take a short transaction of their own, none is held while the engine computes.
 *
 * <p>Nothing is computed on the fly: the engine is given the route's raw track and the street edges
 * document stored for it, and only when that document still describes the track ({@link
 * NetworkEdgesHeader#current}, the rule of the nightly overlay). Nothing is stored and no quota is
 * drawn: the proposals are opened in the planner as a new route.
 */
@ApplicationScoped
public class RouteRetouchService {
  private static final Logger LOG = Logger.getLogger(RouteRetouchService.class);

  @Inject PlannerAccess plannerAccess;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject TeamService teamService;
  @Inject RouteService routeService;
  @Inject GpxTrackRepository gpxTrackRepository;
  @Inject AssetRepository assetRepository;
  @Inject PlaceRepository placeRepository;
  @Inject RouteGeneratorGuard guard;
  @Inject RouteGeneratorMetrics metrics;
  @Inject RouteGeneratorGateway gateway;
  @Inject GeneratedRouteAscent ascent;

  /** What the polyline and the rest of an edit body take beside the document, at most. */
  static final long BODY_MARGIN_BYTES = 512L * 1024;

  /** Distance bounds judged from the stored length, which the exact one differs from by less. */
  private static final double PRECHECK_SLACK = 0.01;

  @ConfigProperty(name = "pedalons.route-generator.enabled", defaultValue = "true")
  boolean enabled;

  /** What a read of the route found: enough to decide, nothing lazy. */
  record Located(long routeId, boolean deleted, @Nullable SurfaceType surfaceType) {}

  /**
   * Whether the stored document lets the route be retouched, and what the track weighs. {@code
   * problem} is null when it does.
   */
  record Readiness(
      @Nullable RouteRetouchUnavailable problem,
      @Nullable RetouchHead head,
      @Nullable Long original) {
    boolean ready() {
      return problem == null;
    }
  }

  // ---------------------------------------------------------------------------------- the offer

  /**
   * Whether the retouch is offered to the caller for this route, and within which bounds. Costs a
   * few reads: no document, no geometry, no call to the engine.
   */
  @Logged
  public RouteRetouchOfferDto offer(String teamSlug, String routeSlug) {
    Team team = teamService.getTeam(teamSlug);
    Located route = locate(team, routeSlug);
    if (route.deleted() || !mayPlan(teamSlug)) {
      return unavailable(RouteRetouchUnavailable.NOT_ALLOWED);
    }
    Availability availability =
        enabled && gateway.configured() ? gateway.availability(false) : null;
    EditInfo edit = availability == null ? null : availability.edit();
    String rideType = rideType(route.surfaceType());
    if (availability == null
        || !availability.usable()
        || edit == null
        || !edit.accepts(rideType)
        || operations(edit).isEmpty()) {
      return unavailable(RouteRetouchUnavailable.ENGINE_UNAVAILABLE);
    }
    Readiness readiness = readiness(route.routeId(), edit, availability);
    RetouchHead head = readiness.head();
    if (!readiness.ready() || head == null) {
      return unavailable(
          readiness.problem() == null ? RouteRetouchUnavailable.UNSUPPORTED : readiness.problem());
    }
    double length = head.rawLengthM();
    double min = length * (1 - edit.changeShareMax());
    double max = Math.min(length * (1 + edit.changeShareMax()), availability.distanceMMax());
    // A field with no valid target (a short route, or one near the engine's longest) is not offered
    boolean resizable = Math.max(length - min, max - length) >= edit.changeMMin();
    List<RouteRetouchOperation> operations = new ArrayList<>(operations(edit));
    if (!resizable) {
      operations.remove(RouteRetouchOperation.RESIZE);
    }
    if (operations.isEmpty()) {
      return unavailable(RouteRetouchUnavailable.UNSUPPORTED);
    }
    return new RouteRetouchOfferDto(
        true,
        null,
        operations,
        length,
        // Rounded inwards to the tenth of a kilometre, and never under the contract's 1 km
        Math.max(1.0, Math.ceil(min / 100) / 10),
        Math.floor(max / 100) / 10,
        edit.changeMMin() / 1000,
        edit.changeShareMax(),
        edit.endSnapM(),
        edit.proposalsMax(),
        RouteGeneratorType.valueOf(rideType.toUpperCase(Locale.ROOT)));
  }

  private static RouteRetouchOfferDto unavailable(RouteRetouchUnavailable reason) {
    return new RouteRetouchOfferDto(
        false, reason, List.of(), null, null, null, null, null, null, null, null);
  }

  private static List<RouteRetouchOperation> operations(EditInfo edit) {
    List<RouteRetouchOperation> out = new ArrayList<>(2);
    if (edit.offers("resize")) {
      out.add(RouteRetouchOperation.RESIZE);
    }
    if (edit.offers("move_end")) {
      out.add(RouteRetouchOperation.MOVE_END);
    }
    return out;
  }

  /** The rule of {@link PlannerAccess#check}, as an answer: rights and planner flag. */
  private boolean mayPlan(String teamSlug) {
    try {
      plannerAccess.check(teamSlug);
      return true;
    } catch (ForbiddenException e) {
      return false;
    } catch (BusinessException e) {
      if (e.getErrorCode() == ErrorCode.ROUTE_PLANNER_DISABLED) {
        return false;
      }
      throw e;
    }
  }

  // ---------------------------------------------------------------------------------- the retouch

  @Logged
  public RouteRetouchResponse retouch(
      String teamSlug, String routeSlug, RouteRetouchRequest request) {
    // Rights first, then the route, then the flag: a non-member learns nothing
    plannerAccess.check(teamSlug);
    Team team = teamService.getTeam(teamSlug);
    Located route = locate(team, routeSlug);
    RouteRetouchOperation operation =
        request.targetDistanceKm() != null
            ? RouteRetouchOperation.RESIZE
            : RouteRetouchOperation.MOVE_END;
    String label = operation == RouteRetouchOperation.RESIZE ? "resize" : "move_end";
    if (route.deleted()) {
      throw refused(label, "unsupported", ErrorCode.ROUTE_RETOUCH_UNSUPPORTED);
    }
    if (!enabled) {
      throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
    }
    // What costs nothing is refused before the window of requests is drawn on
    GeoPoint end = validate(request, team);
    String rideType = rideType(route.surfaceType());
    Availability availability = gateway.configured() ? gateway.availability(false) : null;
    EditInfo edit = availability == null ? null : availability.edit();
    if (availability == null
        || !availability.usable()
        || edit == null
        || !edit.offers(label)
        || !edit.accepts(rideType)) {
      // Nothing is sent to an engine that cannot edit (a 1.17 one in production)
      metrics.retouch(label, "unavailable");
      throw new ServiceUnavailableException(ErrorCode.GENERATOR_UNAVAILABLE);
    }
    Readiness readiness = readiness(route.routeId(), edit, availability);
    RetouchHead head = readiness.head();
    if (!readiness.ready() || head == null) {
      throw refused(label, readiness);
    }
    if (operation == RouteRetouchOperation.RESIZE) {
      // Judged on the stored length, with a slack, before the raw track and the document are read
      double slack = head.rawLengthM() * PRECHECK_SLACK;
      double change = Math.abs(request.targetDistanceKm() * 1000 - head.rawLengthM());
      if (change < edit.changeMMin() - slack) {
        throw refused(label, "change_too_small", ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL);
      }
      if (change > edit.changeShareMax() * head.rawLengthM() + slack) {
        throw refused(label, "change_too_large", ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE);
      }
    }
    RetouchSource source =
        QuarkusTransaction.requiringNew()
            .call(() -> gpxTrackRepository.findRetouchSource(head.trackId()));
    String document = source.document();
    LineString<G2D> raw = source.raw();
    // The head and the source are two reads: a document that changed in between is not current
    if (raw == null
        || document == null
        || !NetworkEdgesHeader.current(NetworkEdgesHeader.read(document), readiness.original())) {
      throw refused(label, "not_ready", ErrorCode.ROUTE_RETOUCH_NOT_READY);
    }
    int n = raw.getNumPositions();
    double[][] lonLat = new double[n][];
    double length = 0;
    for (int i = 0; i < n; i++) {
      lonLat[i] = new double[] {raw.getPositionN(i).getLon(), raw.getPositionN(i).getLat()};
      if (i > 0) {
        length +=
            GeoDistance.haversineMeters(
                lonLat[i - 1][1], lonLat[i - 1][0], lonLat[i][1], lonLat[i][0]);
      }
    }
    if (n < 2 || n > edit.pointsMax() || length > availability.distanceMMax()) {
      throw refused(label, "unsupported", ErrorCode.ROUTE_RETOUCH_UNSUPPORTED);
    }

    Double targetM = null;
    EditOperation engineOperation;
    boolean shortening = false;
    if (operation == RouteRetouchOperation.RESIZE) {
      targetM = request.targetDistanceKm() * 1000;
      double change = targetM - length;
      shortening = change < 0;
      if (Math.abs(change) < edit.changeMMin()) {
        throw refused(label, "change_too_small", ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL);
      }
      if (Math.abs(change) > edit.changeShareMax() * length
          || targetM > availability.distanceMMax()) {
        throw refused(label, "change_too_large", ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE);
      }
      engineOperation = EditOperation.resize(targetM);
    } else {
      engineOperation =
          EditOperation.moveEnd(
              new fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GeoPoint(
                  end.lat(), end.lng()));
    }

    String polyline = PolylineCodec.encode2(lonLat);
    EditRequest engineRequest =
        new EditRequest(
            polyline,
            document,
            rideType,
            request.discovery() == null
                ? RouteGeneratorService.DEFAULT_DISCOVERY
                : request.discovery(),
            request.seed() == null ? 0 : request.seed(),
            engineOperation);
    byte[] body = gateway.bodyOf(engineRequest);
    if (body.length > edit.requestBodyBytes()) {
      throw refused(label, "unsupported", ErrorCode.ROUTE_RETOUCH_UNSUPPORTED);
    }

    // The window of requests is the generator's own: one count for both
    try {
      guard.admit(pedalonsContext.getDomainId(), pedalonsContext.getUser().getId());
    } catch (PedalonsException e) {
      metrics.retouch(label, "rate_limited");
      throw e;
    }

    String teamRef = TsidUtils.toString(team.getId());
    long t0 = System.nanoTime();
    EditResponse answer;
    try {
      answer = gateway.edit(teamRef, body);
    } catch (RouteGeneratorException e) {
      Duration took = Duration.ofNanos(System.nanoTime() - t0);
      metrics.retouchDuration(label, took);
      metrics.retouch(label, RouteRetouchErrors.outcome(e));
      if (RouteRetouchErrors.isDrift(e)
          || e.kind() == RouteGeneratorException.Kind.NOT_CONFIGURED) {
        LOG.errorf("Route retouch: unexpected answer for team %s: %s", teamRef, e.getMessage());
      } else if (RouteRetouchErrors.isStaleDocument(e)) {
        // A document judged current that does not describe its track: worth looking at
        LOG.warnf("Route retouch: team %s, the stored document does not match its track", teamRef);
      } else {
        LOG.infof(
            "Route retouch: team %s, %s, %s, outcome %s, %d ms",
            teamRef,
            label,
            rideType,
            e.kind().name().toLowerCase(Locale.ROOT)
                + (e.reason() == null ? "" : " (" + e.reason() + ")"),
            took.toMillis());
      }
      throw RouteRetouchErrors.of(e, shortening);
    }
    metrics.retouchDuration(label, Duration.ofNanos(System.nanoTime() - t0));

    GeneratedRouteSanity.EditContext context =
        new GeneratedRouteSanity.EditContext(
            lonLat[0],
            lonLat[n - 1],
            targetM,
            operation == RouteRetouchOperation.MOVE_END
                ? new fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GeoPoint(
                    end.lat(), end.lng())
                : null);
    List<EditedRoute> kept = new ArrayList<>();
    List<GeneratedRouteSanity.Verdict> verdicts = new ArrayList<>();
    List<EditedRoute> proposals = answer.routes() == null ? List.of() : answer.routes();
    for (EditedRoute candidate : proposals) {
      GeneratedRouteSanity.Verdict verdict = GeneratedRouteSanity.checkEdit(context, candidate);
      if (verdict.sane()) {
        kept.add(candidate);
        verdicts.add(verdict);
      } else {
        metrics.dropped(verdict.failed().name());
        LOG.warnf(
            "Route retouch: a proposal of team %s dropped by the sanity check %s",
            teamRef, verdict.failed());
      }
    }
    if (kept.isEmpty()) {
      metrics.retouch(label, proposals.isEmpty() ? "no_proposal" : "sanity");
      throw new BusinessException(
          shortening ? ErrorCode.ROUTE_RETOUCH_NO_SHORTER : ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL);
    }
    metrics.retouch(label, "ok");

    // One batch: the original's ascent is measured as the proposals' are, so that "before and
    // after" compare two measures of the same source
    List<String> polylines = new ArrayList<>(kept.size() + 1);
    polylines.add(polyline);
    kept.forEach(r -> polylines.add(r.polyline()));
    List<GeneratedRouteAscent.@Nullable Gain> gains = ascent.compute(polylines);
    GeneratedRouteAscent.Gain originalGain = gains.getFirst();
    List<RetouchedRouteDto> candidates = new ArrayList<>(kept.size());
    for (int i = 0; i < kept.size(); i++) {
      candidates.add(toDto(kept.get(i), verdicts.get(i).bounds(), gains.get(i + 1), operation));
    }
    LOG.infof(
        "Route retouch: team %s, %s, %s, outcome ok, %d proposal(s), %d dropped, %d ms",
        teamRef,
        label,
        rideType,
        candidates.size(),
        answer.dropped() + proposals.size() - kept.size(),
        Duration.ofNanos(System.nanoTime() - t0).toMillis());
    return new RouteRetouchResponse(
        operation,
        answer.originalM() > 0 ? answer.originalM() : length,
        originalGain == null ? null : originalGain.ascentM(),
        originalGain == null ? null : originalGain.descentM(),
        targetM,
        candidates,
        answer.overlay() == null ? null : answer.overlay().depositedInstant());
  }

  static RetouchedRouteDto toDto(
      EditedRoute r,
      @Nullable BoundsDto bounds,
      GeneratedRouteAscent.@Nullable Gain gain,
      RouteRetouchOperation operation) {
    var c = r.changed();
    if (c == null || c.points() == null || bounds == null) {
      throw new IllegalStateException("a proposal that passed the sanity check has no span");
    }
    return new RetouchedRouteDto(
        r.polyline(),
        r.distanceM(),
        gain == null ? null : gain.ascentM(),
        gain == null ? null : gain.descentM(),
        RetouchKind.valueOf(r.kind().toUpperCase(Locale.ROOT)),
        variant(r.variant()),
        r.keptShare(),
        r.unmatchedM(),
        r.endSnapM(),
        new RetouchedSpanDto(
            c.fromM(),
            c.toM(),
            c.newM(),
            c.points().get(0),
            c.points().get(1),
            c.teamShare(),
            c.offroadShare(),
            c.crossings()),
        bounds);
  }

  private static @Nullable RetouchVariant variant(@Nullable String wire) {
    if (wire == null) {
      return null;
    }
    try {
      return RetouchVariant.valueOf(wire.toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------------- the reads

  private Located locate(Team team, String routeSlug) {
    return QuarkusTransaction.requiringNew()
        .call(() -> {
          // Throws a 404 for a route the caller may not read, like the route's own page
          Route route = routeService.findBySlug(team, routeSlug);
          return new Located(route.getId(), route.isDeleted(), route.getSurfaceType());
        });
  }

  /** Whether the stored document lets a route be retouched (docs/plans/2026-11-24-retouche-parcours-lot7c.md §4.1). */
  private Readiness readiness(long routeId, EditInfo edit, Availability availability) {
    record Read(List<RetouchHead> heads, @Nullable Long original) {}
    Read read =
        QuarkusTransaction.requiringNew()
            .call(() ->
                new Read(
                    gpxTrackRepository.findRetouchHeads(routeId),
                    assetRepository.findCurrentFileId(routeId, AssetType.ROUTE_ORIGINAL_GPX)));
    if (read.heads().size() != 1) {
      return new Readiness(RouteRetouchUnavailable.UNSUPPORTED, null, read.original());
    }
    RetouchHead head = read.heads().getFirst();
    if (!head.hasDocument()
        || !NetworkEdgesHeader.current(
            new NetworkEdgesHeader.Header(head.version(), head.revision(), head.status()),
            read.original())) {
      return new Readiness(RouteRetouchUnavailable.NOT_READY, head, read.original());
    }
    if (!NetworkEdgesDocument.STATUS_OK.equals(head.status())) {
      return new Readiness(RouteRetouchUnavailable.UNSUPPORTED, head, read.original());
    }
    if (!head.hasRaw()) {
      return new Readiness(RouteRetouchUnavailable.NOT_READY, head, read.original());
    }
    // The document alone may fill the engine's body: the polyline comes on top, with a margin
    if (head.rawPoints() > edit.pointsMax()
        || head.rawLengthM() > availability.distanceMMax()
        || head.documentBytes() + BODY_MARGIN_BYTES > edit.requestBodyBytes()) {
      return new Readiness(RouteRetouchUnavailable.UNSUPPORTED, head, read.original());
    }
    return new Readiness(null, head, read.original());
  }

  // ---------------------------------------------------------------------------------- the request

  /**
   * Exactly one of the distance and the finish; the finish is exactly one of a point and a place of
   * the team. Returns the finish of a {@code move_end}, null for a {@code resize}.
   */
  private @Nullable GeoPoint validate(RouteRetouchRequest request, Team team) {
    RouteRetouchEnd end = request.end();
    if ((request.targetDistanceKm() == null) == (end == null)) {
      throw invalid("targetDistanceKm", "exactly one of targetDistanceKm and end must be given");
    }
    if (end == null) {
      return null;
    }
    if ((end.point() == null) == (end.placeId() == null)) {
      throw invalid("end", "exactly one of point and placeId must be given");
    }
    if (end.point() != null) {
      return end.point();
    }
    String placeId = end.placeId();
    double[] lonLat = null;
    if (placeId != null) {
      try {
        Long id = TsidUtils.toLong(placeId);
        lonLat =
            QuarkusTransaction.requiringNew()
                .call(() -> {
                  // Read with the team: a place of another team, or domain, is nobody's
                  Place found = placeRepository.findByIdAndTeam(id, team.getId()).orElse(null);
                  if (found == null || found.getGeometry() == null) {
                    return null;
                  }
                  var position = found.getGeometry().getPosition();
                  return new double[] {position.getLon(), position.getLat()};
                });
      } catch (IllegalArgumentException e) {
        lonLat = null;
      }
    }
    if (lonLat == null) {
      throw invalid("end.placeId", "must be a place of the team that has a position");
    }
    return new GeoPoint(lonLat[0], lonLat[1]);
  }

  private static BusinessException invalid(String field, String message) {
    return new BusinessException(
        ErrorCode.VALIDATION,
        new ErrorValidationDetails(List.of(new FieldError(field, message))),
        null);
  }

  /** {@code road}, {@code gravel} or {@code mtb}: a mixed route is asked as gravel. */
  static String rideType(@Nullable SurfaceType type) {
    if (type == null) {
      return "road";
    }
    return switch (type) {
      case ROAD -> "road";
      case GRAVEL, MIXED -> "gravel";
      case MTB -> "mtb";
    };
  }

  private BusinessException refused(String operation, Readiness readiness) {
    return readiness.problem() == RouteRetouchUnavailable.NOT_READY
        ? refused(operation, "not_ready", ErrorCode.ROUTE_RETOUCH_NOT_READY)
        : refused(operation, "unsupported", ErrorCode.ROUTE_RETOUCH_UNSUPPORTED);
  }

  private BusinessException refused(String operation, String outcome, ErrorCode code) {
    metrics.retouch(operation, outcome);
    return new BusinessException(code);
  }

  /** For the logs of the tests: the body of a request as the engine receives it. */
  static String text(byte[] body) {
    return new String(body, StandardCharsets.UTF_8);
  }
}
