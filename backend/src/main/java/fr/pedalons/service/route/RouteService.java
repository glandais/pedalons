package fr.pedalons.service.route;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.CountResponse;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.request.RouteSearchParams;
import fr.pedalons.dto.routes.request.WaypointRequest;
import fr.pedalons.dto.routes.response.BoundsDto;
import fr.pedalons.dto.routes.response.PlannerStateResponse;
import fr.pedalons.dto.routes.response.RouteBoundsResponse;
import fr.pedalons.dto.routes.response.RouteDetailDto;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.dto.routes.response.RouteListResponse;
import fr.pedalons.dto.routes.response.RouteUsageDto;
import fr.pedalons.dto.routes.response.RouteUsagesResponse;
import fr.pedalons.dto.routes.response.RoutesBulkResponse;
import fr.pedalons.dto.routes.response.TrackDto;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.TagTarget;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.common.TeamEntityQueryBasic;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.RouteQuery;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.repository.trip.TripRepository;
import fr.pedalons.service.comment.CommentCountLookup;
import fr.pedalons.service.common.MemberNamesVisibility;
import fr.pedalons.service.common.TeamEntityService;
import fr.pedalons.service.elevation.ElevationRefreshService;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.route.planner.PlannerStates;
import fr.pedalons.service.route.response.TrackMetadata;
import fr.pedalons.service.route.waypoint.AnchoredWaypoint;
import fr.pedalons.service.route.waypoint.TrackAxis;
import fr.pedalons.service.route.waypoint.WaypointAnchoring;
import fr.pedalons.service.route.waypoint.WaypointDraft;
import fr.pedalons.service.route.waypoint.WaypointDrafts;
import fr.pedalons.service.route.waypoint.WaypointPlan;
import fr.pedalons.service.route.waypoint.WaypointRows;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.security.annotation.Public;
import fr.pedalons.service.surface.RouteSurfaces;
import fr.pedalons.service.surface.SurfaceRefreshService;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.tag.TagService;
import io.github.glandais.engine.gpx.GpxDocument;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.LockModeType;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.geolatte.geom.G3DM;
import org.geolatte.geom.PositionSequence;
import org.jspecify.annotations.Nullable;

/**
 * Business logic service for route management.
 * Handles CRUD operations, GPX processing orchestration, and security checks.
 */
@ApplicationScoped
public class RouteService extends TeamEntityService<Route, RouteRepository, RouteDetailDto> {

  @Inject MemberNamesVisibility memberNamesVisibility;

  /**
   * A route's track points are the heaviest column of the schema; a batch beyond this is not "a
   * few routes for one screen" any more, it is a listing wearing a detail endpoint's clothes.
   *
   * <p>Since the read-time decimation knobs were removed, this is the *only* bound on what {@link
   * #getRoutesBulk} weighs, and that is a deliberate choice rather than an oversight. The stored
   * track is already Douglas-Peucker-filtered at import and sits at roughly one point every 90 m,
   * which puts a realistic batch of {@value #MAX_BULK_SLUGS} routes at a few MB — the pathological
   * case needs a caller who knows which are the heaviest routes of the whole database and names
   * them all at once, which is a rate-limiting concern rather than a contract one.
   */
  public static final int MAX_BULK_SLUGS = 50;

  @Inject RouteRepository routeRepository;

  @Inject CommentCountLookup commentCountLookup;

  @Inject GpxProcessingService gpxProcessingService;

  @Inject ElevationRefreshService elevationRefreshService;

  @Inject SurfaceRefreshService surfaceRefreshService;

  @Inject AssetRepository assetRepository;

  @Inject GpxTrackRepository gpxTrackRepository;

  @Inject PlannerStates plannerStates;

  @Inject RideRepository rideRepository;

  @Inject TripRepository tripRepository;

  @Inject TagService tagService;

  @Inject TagLookup tagLookup;

  @Inject PublicationEndCalculator publicationEndCalculator;

  @Override
  protected RouteRepository getRepository() {
    return routeRepository;
  }

  @Override
  protected RouteDetailDto toDto(Route entity) {
    return RouteDetailDto.from(
        entity,
        assetService,
        commentCountLookup.forEntity(entity),
        tagsOf(entity),
        true,
        surfaceRefreshService.readRoute(entity.getId()),
        memberNamesVisibility.canSeeNames(entity.getTeam().getId()));
  }

  @Override
  public Route findBySlug(Team team, String entitySlug) {
    return super.findBySlug(team, entitySlug);
  }

  public Route get(String teamSlug, String entitySlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.findBySlug(team, entitySlug);
  }

  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.READ)
  public RouteDetailDto getDto(String teamSlug, String entitySlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.getDto(team, entitySlug);
  }

  /**
   * The detail of every requested slug the caller may read, one query for the whole batch.
   *
   * <p>No {@code @CheckAccess} here: unlike every other method of this service, the caller passes
   * a <em>list</em> of slugs, which {@code RouteAccessChecker} (built around a single positional
   * slug parameter) cannot express. Read authorization instead comes straight from {@link
   * RouteRepository#findByTeamAndSlugs}, which reuses the exact visibility clauses {@link
   * #findBySlug} would apply to any one of those slugs — the same SQL predicate the single-route
   * {@code READ} check ultimately delegates to (see {@code RouteAccessChecker}, "filtering done via
   * SQL"). A slug that is unknown or unreadable simply is not among the rows that query returns, so
   * it silently drops out of the answer rather than 404ing the whole batch.
   *
   * <p>The response is reordered to follow {@code slugs} (first occurrence, duplicates collapsed)
   * rather than whatever order the database returned rows in — the natural contract for a caller
   * that is fetching several named routes at once.
   *
   * @param slugs capped at {@link #MAX_BULK_SLUGS}: the track points column this walks is the
   *     heaviest of the schema, once per route in the batch
   * @param geometry false leaves every row's {@code tracks} empty. Everything else about the
   *     response is unchanged, so a screen that only shows names and figures pays for none of the
   *     geometry — which is the whole reason this flag exists now that the read path no longer
   *     decimates anything
   */
  @Public
  public RoutesBulkResponse getRoutesBulk(String teamSlug, List<String> slugs, boolean geometry) {
    if (slugs.size() > MAX_BULK_SLUGS) {
      throw new BadRequestException(ErrorCode.BAD_REQUEST);
    }
    // Resolved even for an empty slug list: every other endpoint under this team-scoped path
    // 404s on an unknown team regardless of its other parameters, and this one must not be the
    // exception just because it has nothing else to look up.
    Team team = teamService.getTeam(teamSlug);
    if (slugs.isEmpty()) {
      return new RoutesBulkResponse(List.of(), null);
    }

    Long domainId = pedalonsContext.getDomainId();
    Long userId = pedalonsContext.getUserIdNullable();
    boolean includeDeleted = isIncludeDeleted(team);
    boolean platformAdmin = isPlatformAdmin();

    Set<String> distinctSlugs = Set.copyOf(slugs);
    List<Route> routes =
        routeRepository.findByTeamAndSlugs(
            domainId, team.getId(), userId, distinctSlugs, includeDeleted, platformAdmin);

    // Two queries for the whole batch — the comment count of a bulk row must not cost a
    // round-trip per row, same rule as any other page.
    CommentCounts commentCounts = commentCountLookup.forEntities(routes);
    ContentTags tags = tagLookup.forContents(routes.stream().map(Route::getId).toList());

    // Surfaces only matter when tracks are drawn; read per page, two queries for the batch.
    Map<Long, RouteSurfaces> surfaces =
        geometry
            ? surfaceRefreshService.readRoutes(routes.stream().map(Route::getId).toList())
            : Map.of();

    // Once for the batch: every route belongs to this team (docs/LEDGER_*.md API-144).
    boolean withCreator = memberNamesVisibility.canSeeNames(team.getId());
    Map<String, RouteDetailDto> bySlug = new LinkedHashMap<>();
    for (Route route : routes) {
      bySlug.put(
          route.getSlug(),
          RouteDetailDto.from(
              route,
              assetService,
              commentCounts,
              tags,
              geometry,
              surfaces.getOrDefault(route.getId(), RouteSurfaces.NONE),
              withCreator));
    }

    List<RouteDetailDto> ordered =
        slugs.stream().distinct().map(bySlug::get).filter(Objects::nonNull).toList();

    return new RoutesBulkResponse(ordered, computeExtent(ordered));
  }

  /**
   * The bounding box of every track {@code routes} carries, computed in memory — exactly what
   * {@link #getRoutesBulk} already loaded, so this costs no extra query. Mirrors {@code
   * RouteRepository.bounds}, which computes the same box in SQL for a filtered listing; this one
   * walks the geometry actually being returned, so it answers {@code null} when the batch was
   * asked for metadata only ({@code geometry=false}) rather than a box around nothing.
   *
   * <p>Deliberately ignores waypoints, even though both clients do render them (the web's {@code
   * WaypointMarker} in {@code RouteTrackMap.tsx}, the waypoint dots and labels in mobile's {@code
   * route_map.dart}): {@code RoutesBulkResponse.extent} exists so a client can fit its map directly
   * on the track geometry it was just handed, and a waypoint imported from a GPX for a meeting
   * cafe or a car park can sit tens of km off the actual loop — including it would widen the
   * extent around geometry the track itself never reaches.
   */
  private static @Nullable BoundsDto computeExtent(List<RouteDetailDto> routes) {
    double minLon = Double.POSITIVE_INFINITY;
    double minLat = Double.POSITIVE_INFINITY;
    double maxLon = Double.NEGATIVE_INFINITY;
    double maxLat = Double.NEGATIVE_INFINITY;
    boolean any = false;
    for (RouteDetailDto route : routes) {
      for (TrackDto track : route.tracks()) {
        PositionSequence<G3DM> positions = track.line().getPositions();
        for (int i = 0; i < positions.size(); i++) {
          G3DM p = positions.getPositionN(i);
          minLon = Math.min(minLon, p.getLon());
          maxLon = Math.max(maxLon, p.getLon());
          minLat = Math.min(minLat, p.getLat());
          maxLat = Math.max(maxLat, p.getLat());
          any = true;
        }
      }
    }
    return any ? new BoundsDto(minLon, minLat, maxLon, maxLat) : null;
  }

  /**
   * List the rides and trips that reference a route — directly, or through a ride group or trip
   * stage. Each referencing ride/trip appears once, most recent first. The listing is visibility
   * filtered per the caller, so an anonymous visitor only sees public published usages.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.READ)
  public RouteUsagesResponse getUsages(String teamSlug, String routeSlug) {
    Team team = teamService.getTeam(teamSlug);
    Route route = findBySlug(team, routeSlug);
    Long routeId = route.getId();
    User user = pedalonsContext.getUserNullable();

    TeamEntityQueryBasic base =
        TeamEntityQueryBasic.builder()
            .domainId(pedalonsContext.getDomainId())
            .pinnedTeamId(pedalonsContext.getPinnedTeamIdNullable())
            .userId(user == null ? null : user.getId())
            .teamIds(Set.of(team.getId()))
            .includeDeleted(false)
            .platformAdmin(isPlatformAdmin())
            .build();

    List<RouteUsageDto> usages = new ArrayList<>();
    rideRepository
        .findByRouteId(base, routeId)
        .forEach(ride -> usages.add(RouteUsageDto.fromRide(ride, routeId)));
    tripRepository
        .findByRouteId(base, routeId)
        .forEach(trip -> usages.add(RouteUsageDto.fromTrip(trip, routeId)));
    usages.sort(Comparator.comparing(RouteUsageDto::dateTime).reversed());
    return new RouteUsagesResponse(usages);
  }

  /**
   * Create a new route with GPX upload.
   * Processes GPX file, extracts metadata, generates files, and stores everything.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.CREATE)
  public RouteDto createRoute(String teamSlug, RouteRequest request, @Nullable Path gpxPath) {
    return doCreateRoute(teamSlug, request, gpxPath, null, null, null);
  }

  /**
   * As {@link #createRoute(String, RouteRequest, Path)}, for the promotion of a preview: {@code
   * copiedState} is the planner state of the preview, written with the track of the new route
   * (docs/LEDGER_*.md WEB-100, C4a). The track comes from the preview's original GPX, which is the
   * one derived from that state, so the two agree by construction.
   *
   * <p>{@code copiedSurfaces} are the surface documents of the preview, one per track, when they
   * describe its current tracks (C1b): the new route has the same tracks, so it keeps them and
   * asks for nothing.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.CREATE)
  public RouteDto createRoute(
      String teamSlug,
      RouteRequest request,
      @Nullable Path gpxPath,
      @Nullable PlannerState copiedState,
      @Nullable List<@Nullable TrackSurfaceDocument> copiedSurfaces) {
    return doCreateRoute(teamSlug, request, gpxPath, copiedState, copiedSurfaces, null);
  }

  /**
   * As {@link #createRoute(String, RouteRequest, Path, PlannerState, List)}, also taking the
   * waypoints of the preview, which {@code original.gpx} does not carry (docs/LEDGER_*.md API-134):
   * they are placed again on the new route, unless the request has a list of its own.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.CREATE)
  public RouteDto createRoute(
      String teamSlug,
      RouteRequest request,
      @Nullable Path gpxPath,
      @Nullable PlannerState copiedState,
      @Nullable List<@Nullable TrackSurfaceDocument> copiedSurfaces,
      @Nullable List<WaypointDraft> copiedWaypoints) {
    return doCreateRoute(teamSlug, request, gpxPath, copiedState, copiedSurfaces, copiedWaypoints);
  }

  private RouteDto doCreateRoute(
      String teamSlug,
      RouteRequest request,
      @Nullable Path gpxPath,
      @Nullable PlannerState copiedState,
      @Nullable List<@Nullable TrackSurfaceDocument> copiedSurfaces,
      @Nullable List<WaypointDraft> copiedWaypoints) {
    Team team = teamService.getTeam(teamSlug);
    User creator = pedalonsContext.getUser();

    validateVisibility(team, request);

    // Validate GPX file. A file wins over a planner state, which is then ignored, not even
    // validated.
    List<GeoPoint> routePoints = request.points();
    rejectPointsWithState(request);
    PlannerState requestedState = gpxPath == null ? request.plannerState() : null;
    if (gpxPath == null
        && requestedState == null
        && (routePoints == null || routePoints.isEmpty())) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    checkPlannerAllowed(team, gpxPath, routePoints, requestedState);
    List<GeoPoint> statePoints =
        requestedState == null ? null : plannerStates.validateAndDerive(requestedState);

    // Before anything is stored: a malformed list is a 400 with nothing to undo
    WaypointPlan waypointPlan = creationPlan(request, copiedWaypoints);

    String slug = slugService.generateSlug(request.name(), team.getId(), routeRepository);

    // Create route entity
    Route route =
        new Route(creator, team, request.name(), slug, request.visibility(), request.surfaceType());

    // Persist to get ID for file storage
    routeRepository.persistAndFlush(route);
    // Before the GPX work: a refused tag is a 400 with nothing stored yet.
    tagService.replaceTags(route, request.tagIds());

    try {

      GpxDocument gpx;
      if (gpxPath != null) {
        gpx = gpxProcessingService.parseGpx(gpxPath);
      } else {
        gpx =
            gpxProcessingService.fromPoints(
                route.getName(), statePoints != null ? statePoints : routePoints);
      }
      // Phase 1: CPU + S3 (transaction suspended, DB connection released)
      ElevationQuality quality = elevationRefreshService.saveQuality();
      GpxProcessingService.GpxProcessingResult gpxResult =
          gpxProcessingService.processGpxData(route, gpx, quality, waypointPlan);

      // Phase 2: DB persist (transaction resumed, short burst)
      TrackMetadata metadata = gpxProcessingService.persistGpxData(route, gpxResult);

      route.setDistance(metadata.distance());
      route.setElevationGain(metadata.elevationGain());
      route.setHilliness(metadata.hilliness());
      route.setElevationLoss(metadata.elevationLoss());
      route.setStart(metadata.start());
      route.setEnd(metadata.end());
      route.setWindDirection(getWindDirection(metadata));
      recordElevationQuality(route, quality, gpxResult);
      storePlannerState(route, requestedState != null ? requestedState : copiedState, gpxResult);
      storeOrRequestSurfaces(route, copiedSurfaces, gpxResult);

      updateMedia(route, request.media());
      routeRepository.persist(route);
      return RouteDto.from(route, assetService, commentCountLookup.forEntity(route), tagsOf(route));
    } catch (Exception e) {
      gpxProcessingService.deleteRouteFiles(route);
      throw e;
    }
  }

  /**
   * The waypoints a new route gets (docs/LEDGER_*.md WEB-100, C3c): the request's list when it has
   * one (the file's <wpt> are then ignored), else the preview's it is promoted from, else those of
   * the file — a drawing has none.
   */
  private static WaypointPlan creationPlan(
      RouteRequest request, @Nullable List<WaypointDraft> copiedWaypoints) {
    if (request.waypoints() != null) {
      return new WaypointPlan(
          WaypointDrafts.fromRequest(request.waypoints(), List.of(), null), false);
    }
    if (copiedWaypoints != null) {
      return new WaypointPlan(copiedWaypoints, false);
    }
    return WaypointPlan.FROM_DOCUMENT;
  }

  /**
   * Refuse a drawn track when the team's planner is closed.
   *
   * <p>The two sources are told apart the same way the processing below does it: a {@code gpxPath}
   * means an imported file and always wins, so points or a planner state only matter when no file
   * came with the request. This deliberately lives here and not in {@code RouteAccessChecker} — the
   * checker only ever sees the team slug and the entity slug, never the payload, so it cannot
   * distinguish a drawing from an import.
   */
  private void checkPlannerAllowed(
      Team team,
      @Nullable Path gpxPath,
      @Nullable List<GeoPoint> points,
      @Nullable PlannerState plannerState) {
    boolean drawing = plannerState != null || (points != null && !points.isEmpty());
    if (gpxPath == null && drawing && !team.isEnableRoutePlanner()) {
      throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
    }
  }

  /** Points and a planner state are two sources for one track: never both (WEB-100, C4a). */
  private static void rejectPointsWithState(RouteRequest request) {
    List<GeoPoint> points = request.points();
    if (request.plannerState() != null && points != null && !points.isEmpty()) {
      throw new BusinessException(ErrorCode.PLANNER_STATE_INVALID);
    }
  }

  /**
   * Writes the planner state on the one track just saved, with the revision token of this save: the
   * {@code file_id} of the original GPX. Nothing for a state without exactly one track.
   */
  private void storePlannerState(
      Route route, @Nullable PlannerState state, GpxProcessingService.GpxProcessingResult result) {
    if (state == null || route.getTracks().size() != 1) {
      return;
    }
    route
        .getTracks()
        .getFirst()
        .setPlannerState(new PlannerStateDocument(originalFileId(result), state));
  }

  /**
   * The surface of the tracks just saved (docs/LEDGER_*.md WEB-100, C1b): the documents of the
   * preview this route is promoted from when they cover every track, else a request for the
   * background computation, in this transaction.
   */
  private void storeOrRequestSurfaces(
      Route route,
      @Nullable List<@Nullable TrackSurfaceDocument> copied,
      GpxProcessingService.GpxProcessingResult result) {
    List<GpxTrack> tracks = route.getTracks();
    if (copied != null
        && copied.size() == tracks.size()
        && copied.stream().allMatch(Objects::nonNull)) {
      for (int i = 0; i < tracks.size(); i++) {
        tracks.get(i).setSurfaces(Objects.requireNonNull(copied.get(i)));
      }
      return;
    }
    surfaceRefreshService.requestRoute(route, originalFileId(result));
  }

  private static long originalFileId(GpxProcessingService.GpxProcessingResult result) {
    return result.uploadedAssets().stream()
        .filter(pa -> pa.type() == AssetType.ROUTE_ORIGINAL_GPX)
        .findFirst()
        .orElseThrow()
        .fileId();
  }

  /**
   * Stamps the elevation state of a track just saved (PENDING or HD) and, for a fast one, asks for its HD
   * catch-up in the same transaction (docs/LEDGER_*.md API-131). The request carries the {@code
   * file_id} of the route's original GPX, which a later save of the track changes and a save of the
   * title does not (API-128).
   */
  private void recordElevationQuality(
      Route route, ElevationQuality quality, GpxProcessingService.GpxProcessingResult result) {
    if (quality != ElevationQuality.FAST) {
      route.setElevationState(ElevationState.HD);
      return;
    }
    route.setElevationState(ElevationState.PENDING);
    elevationRefreshService.requestRoute(route, originalFileId(result));
  }

  private static WindDirection getWindDirection(TrackMetadata metadata) {
    WindDirection windDirection = metadata.windDirection();
    if (windDirection == null) {
      return WindDirection.NORTH;
    }
    return windDirection;
  }

  /**
   * Update route metadata and optionally GPX file.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.UPDATE)
  public RouteDto updateRoute(
      String teamSlug, String slug, RouteRequest request, @Nullable Path gpxPath) {
    Team team = teamService.getTeam(teamSlug);
    Route route = findBySlug(team, slug);
    // Held until commit, phase 1 included (its connection stays with the suspended transaction):
    // the HD catch-up of ElevationRefreshService waits for this save, then sees its new original
    // and realigns, instead of bumping the versions under it (docs/LEDGER_*.md API-131).
    routeRepository.getEntityManager().lock(route, LockModeType.PESSIMISTIC_WRITE);

    // Before anything is cleared: this initialises the waypoints collection, and none may be
    // loaded between the clear of the tracks and their refill (HHH90032003). Docs/LEDGER_*.md
    // WEB-100, C3c: the waypoints are never cleared, they are updated and removed in place.
    List<GpxWaypoint> currentWaypoints = List.copyOf(route.getWaypoints());
    Float previousDistance = route.getDistance();

    validateVisibility(team, request);
    rejectPointsWithState(request);
    // A file wins over a planner state, which is then ignored, not even validated.
    PlannerState requestedState = gpxPath == null ? request.plannerState() : null;
    checkPlannerAllowed(team, gpxPath, request.points(), requestedState);

    // Update basic metadata
    route.setName(request.name());
    route.setSurfaceType(request.surfaceType());
    route.setVisibility(request.visibility());
    route.setDateTime(Instant.now());
    // Before the GPX work, for the same reason as on creation.
    tagService.replaceTags(route, request.tagIds());

    // Read before the try below: a file refused here (unparseable, or too long — SEC-6) keeps its
    // own error code instead of being wrapped as GPX_FAILURE by the catch.
    GpxDocument gpx = null;
    if (gpxPath != null) {
      gpx = gpxProcessingService.parseGpx(gpxPath);
    } else if (requestedState != null) {
      gpx =
          gpxProcessingService.fromPoints(
              route.getName(), plannerStates.validateAndDerive(requestedState));
    } else {
      List<GeoPoint> points = request.points();
      if (points != null && !points.isEmpty()) {
        gpx = gpxProcessingService.fromPoints(route.getName(), points);
      }
    }

    // Outside the try: a malformed list is a 400, not a GPX_FAILURE
    WaypointPlan waypointPlan =
        gpx == null ? null : updatePlan(request, gpxPath, currentWaypoints, previousDistance);

    try {
      // If GPX file provided, update track and climbs
      if (gpx != null) {
        // The asset rows are kept and given the new files by persistGpxData (docs/LEDGER_*.md
        // API-128); a rollback restores them and the transaction synchronizations clean the files.
        route.getTracks().clear();

        // Phase 1: CPU + S3 (transaction suspended, DB connection released)
        ElevationQuality quality = elevationRefreshService.saveQuality();
        GpxProcessingService.GpxProcessingResult gpxResult =
            gpxProcessingService.processGpxData(
                route, gpx, quality, Objects.requireNonNull(waypointPlan));

        // Phase 2: DB persist (transaction resumed, short burst)
        TrackMetadata metadata = gpxProcessingService.persistGpxData(route, gpxResult);

        route.setDistance(metadata.distance());
        route.setElevationGain(metadata.elevationGain());
        route.setHilliness(metadata.hilliness());
        route.setElevationLoss(metadata.elevationLoss());
        route.setStart(metadata.start());
        route.setEnd(metadata.end());
        route.setWindDirection(getWindDirection(metadata));
        recordElevationQuality(route, quality, gpxResult);
        // The new tracks carry no state of their own: the old state left with the old tracks
        // (WEB-100, C4a). A state is only written when this save was made of one.
        storePlannerState(route, requestedState, gpxResult);
        // The new tracks have no surface: the old ones left with the old tracks (WEB-100, C1b)
        surfaceRefreshService.requestRoute(route, originalFileId(gpxResult));
      }
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    if (gpx != null) {
      // A new track is a new distance: every ride, group and stage riding it ends at another time
      // (docs/LEDGER_*.md API-85).
      publicationEndCalculator.refreshUsersOf(route);
    } else if (request.waypoints() != null) {
      replaceWaypointsOnly(team, route, request.waypoints(), currentWaypoints);
    }

    updateMedia(route, request.media());
    routeRepository.persist(route);
    return RouteDto.from(route, assetService, commentCountLookup.forEntity(route), tagsOf(route));
  }

  /**
   * The waypoints placed on a track that is replaced (docs/LEDGER_*.md WEB-100, C3c): the request's
   * list when it has one; else, for a new file, the author's waypoints kept and the file's own
   * replacing the imported ones; else (a redrawn track) all of them, placed again.
   */
  private static WaypointPlan updatePlan(
      RouteRequest request,
      @Nullable Path gpxPath,
      List<GpxWaypoint> current,
      @Nullable Float previousDistance) {
    if (request.waypoints() != null) {
      return new WaypointPlan(
          WaypointDrafts.fromRequest(
              request.waypoints(), WaypointDrafts.knownOf(current), previousDistance),
          false);
    }
    if (gpxPath != null) {
      return new WaypointPlan(
          WaypointDrafts.fromRows(
              current, previousDistance, w -> w.getOrigin() == WaypointOrigin.AUTHOR),
          true);
    }
    return new WaypointPlan(WaypointDrafts.fromRows(current, previousDistance, w -> true), false);
  }

  /**
   * Replaces the waypoints of a route whose track did not change: the filtered GPX and the FIT are
   * written again from the stored track, nothing else is touched (no original, no thumbnail, no
   * elevation or surface request). A list equal to the stored one writes nothing at all, so a save
   * of the title alone sends no route to the GPS services again.
   */
  private void replaceWaypointsOnly(
      Team team, Route route, List<WaypointRequest> requested, List<GpxWaypoint> current) {
    List<GpxTrack> tracks =
        route.getTracks().stream().sorted(Comparator.comparing(GpxTrack::getId)).toList();
    List<AnchoredWaypoint> anchored =
        WaypointAnchoring.anchor(
            TrackAxis.ofTracks(tracks),
            WaypointDrafts.fromRequest(requested, WaypointDrafts.knownOf(current), null));
    if (WaypointRows.sameContent(current, anchored, true)) {
      return;
    }
    if (tracks.stream().allMatch(t -> t.getTrackPoints().isEmpty())) {
      // No stored track (legacy data): no file to write, every waypoint is off the track
      WaypointRows.apply(route, anchored, pedalonsContext.getUser());
      return;
    }
    List<GpxProcessingService.StoredTrack> stored =
        tracks.stream()
            .map(t -> new GpxProcessingService.StoredTrack(t.getName(), t.getTrackPoints()))
            .toList();
    GpxProcessingService.WaypointFiles files =
        gpxProcessingService.rewriteWaypointFiles(team, route.getName(), stored, anchored);
    WaypointRows.apply(route, anchored, pedalonsContext.getUser());
    gpxProcessingService.applyWaypointFiles(route, files);
  }

  /**
   * The planner state of a route, for its edit page (docs/LEDGER_*.md WEB-100, C4a). Null when there
   * is none to read back: never saved with one, or saved since by a path that does not carry it (its
   * revision token no longer matches the original GPX), or several tracks.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.UPDATE)
  public PlannerStateResponse getPlannerState(String teamSlug, String slug) {
    Team team = teamService.getTeam(teamSlug);
    Route route = findBySlug(team, slug);
    List<@Nullable PlannerStateDocument> documents =
        gpxTrackRepository.findPlannerStates(route.getId());
    if (documents.size() != 1 || documents.getFirst() == null) {
      return new PlannerStateResponse(null);
    }
    PlannerStateDocument document = documents.getFirst();
    Long current = assetRepository.findCurrentFileId(route.getId(), AssetType.ROUTE_ORIGINAL_GPX);
    if (current == null || current != document.trackRevision()) {
      return new PlannerStateResponse(null);
    }
    return new PlannerStateResponse(document.state());
  }

  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.UPDATE)
  @Transactional
  public RouteDetailDto updateSlug(String teamSlug, String slug, String newSlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.updateSlug(team, slug, newSlug);
  }

  /**
   * List routes for a team with pagination, filtering, and access control.
   */
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.LIST)
  public RouteListResponse getRoutes(String teamSlug, RouteSearchParams params) {
    Team team = teamService.getTeam(teamSlug);
    return getRoutesWithTeamIds(
        Set.of(team.getId()),
        pedalonsContext.getUserNullable(),
        params,
        isIncludeDeleted(team),
        tagFilter(team, params));
  }

  /**
   * The team's latest routes for its dashboard, compact rows, deleted ones left out whatever the
   * caller's role — unlike {@link #getRoutes}, which shows an administrator the deleted ones too.
   *
   * <p>No {@code @CheckAccess}: the dashboard has already established that the caller may read the
   * team (a visitor too, docs/LEDGER_*.md API-86); the visibility rules of the query apply row by
   * row, a visitor's included.
   */
  public RouteListResponse listTeamSection(Team team, int size) {
    return getRoutesWithTeamIds(
        Set.of(team.getId()),
        pedalonsContext.getUserNullable(),
        RouteSearchParams.builder().page(0).size(size).view(ListViewMode.COMPACT).build(),
        false,
        null);
  }

  /**
   * List all routes across all accessible teams with pagination, filtering, and access control.
   */
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.LIST_ALL_TEAMS)
  public RouteListResponse getAllRoutes(RouteSearchParams params) {
    return getRoutesWithTeamIds(null, pedalonsContext.getUserNullable(), params, false, null);
  }

  /**
   * How many routes {@link #getRoutes} would list, without listing them.
   *
   * <p>Built from the same {@link RouteQuery} as the listing, so the two can never disagree: a
   * filter added to one is a filter the other gets for free.
   */
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.LIST)
  public CountResponse countRoutes(String teamSlug, RouteSearchParams params) {
    Team team = teamService.getTeam(teamSlug);
    return new CountResponse(
        routeRepository.countMatching(
            listQuery(
                Set.of(team.getId()),
                pedalonsContext.getUserNullable(),
                params,
                isIncludeDeleted(team),
                tagFilter(team, params))));
  }

  /** How many routes {@link #getAllRoutes} would list, without listing them. */
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.LIST_ALL_TEAMS)
  public CountResponse countAllRoutes(RouteSearchParams params) {
    return new CountResponse(
        routeRepository.countMatching(
            listQuery(null, pedalonsContext.getUserNullable(), params, false, null)));
  }

  /**
   * Vector tile of a team's routes, subject to the same access control as {@link #getRoutes}.
   */
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.LIST)
  public byte[] getRoutesTile(String teamSlug, RouteSearchParams params, int z, int x, int y) {
    Team team = teamService.getTeam(teamSlug);
    return tile(Set.of(team.getId()), params, tagFilter(team, params), z, x, y);
  }

  /**
   * Vector tile of the routes of every accessible team, subject to the same access control as
   * {@link #getAllRoutes}.
   */
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.LIST_ALL_TEAMS)
  public byte[] getAllRoutesTile(RouteSearchParams params, int z, int x, int y) {
    return tile(null, params, null, z, x, y);
  }

  /**
   * Bounding box of a team's routes, subject to the same access control as {@link #getRoutes}.
   */
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.LIST)
  public RouteBoundsResponse getRoutesBounds(String teamSlug, RouteSearchParams params) {
    Team team = teamService.getTeam(teamSlug);
    return new RouteBoundsResponse(
        routeRepository.bounds(
            aggregateQuery(Set.of(team.getId()), params, tagFilter(team, params))));
  }

  /**
   * Bounding box of the routes of every accessible team, subject to the same access control as
   * {@link #getAllRoutes}.
   */
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.LIST_ALL_TEAMS)
  public RouteBoundsResponse getAllRoutesBounds(RouteSearchParams params) {
    return new RouteBoundsResponse(routeRepository.bounds(aggregateQuery(null, params, null)));
  }

  private byte[] tile(
      @Nullable Set<Long> teamIds,
      RouteSearchParams params,
      @Nullable Set<Long> tagIds,
      int z,
      int x,
      int y) {
    return routeRepository.mvtTile(aggregateQuery(teamIds, params, tagIds), z, x, y);
  }

  /**
   * The resolved {@code ?tags=} filter of a team's route list, tile, bounds or count — one
   * resolution for all four, so the map and the list it sits beside agree. The cross-team
   * endpoints never filter on a tag (plan D7) and pass null instead.
   */
  private @Nullable Set<Long> tagFilter(Team team, RouteSearchParams params) {
    List<String> tags = params.tags();
    if (tags == null || tags.isEmpty()) {
      return null;
    }
    return tagService.resolveFilter(team, TagTarget.ROUTE, tags);
  }

  private ContentTags tagsOf(Route route) {
    return tagLookup.forContents(List.of(route.getId()));
  }

  /**
   * The query behind the tile and the bounds: both fold every matching route into a single row. The
   * sort and the pagination of {@code params} are therefore deliberately dropped — an {@code ORDER
   * BY} would break an aggregate projection, and neither answer is paginated.
   */
  private RouteQuery aggregateQuery(
      @Nullable Set<Long> teamIds, RouteSearchParams params, @Nullable Set<Long> tagIds) {
    User user = pedalonsContext.getUserNullable();
    return RouteQuery.builder()
        .domainId(pedalonsContext.getDomainId())
        .pinnedTeamId(pedalonsContext.getPinnedTeamIdNullable())
        .userId(user == null ? null : user.getId())
        .teamIds(teamIds)
        .search(params.search())
        .minRole(params.minRole())
        .minDistance(params.minDistance())
        .maxDistance(params.maxDistance())
        .minElevationGain(params.minElevationGain())
        .maxElevationGain(params.maxElevationGain())
        .hilliness(params.hilliness())
        .surfaceType(params.surfaceType())
        .windDirection(params.windDirection())
        .nearLat(params.nearLat())
        .nearLon(params.nearLon())
        .nearRadius(params.nearRadius())
        .nearType(params.nearType())
        .tagIds(tagIds)
        .includeDeleted(false)
        .platformAdmin(isPlatformAdmin())
        .build();
  }

  /**
   * The query behind the paginated listing and behind the count — one builder, so the "Voir N
   * parcours" figure and the list it opens are answering the same question.
   */
  private RouteQuery listQuery(
      @Nullable Set<Long> teamIds,
      @Nullable User user,
      RouteSearchParams params,
      boolean includeDeleted,
      @Nullable Set<Long> tagIds) {
    return RouteQuery.builder()
        .domainId(pedalonsContext.getDomainId())
        .pinnedTeamId(pedalonsContext.getPinnedTeamIdNullable())
        .userId(user == null ? null : user.getId())
        .teamIds(teamIds)
        .search(params.search())
        .page(params.page())
        .size(params.size())
        .minRole(params.minRole())
        .minDistance(params.minDistance())
        .maxDistance(params.maxDistance())
        .minElevationGain(params.minElevationGain())
        .maxElevationGain(params.maxElevationGain())
        .hilliness(params.hilliness())
        .surfaceType(params.surfaceType())
        .windDirection(params.windDirection())
        .nearLat(params.nearLat())
        .nearLon(params.nearLon())
        .nearRadius(params.nearRadius())
        .nearType(params.nearType())
        .tagIds(tagIds)
        .sortBy(params.sortBy())
        .sortDir(params.sortDir())
        .includeDeleted(includeDeleted)
        .platformAdmin(isPlatformAdmin())
        .build();
  }

  private RouteListResponse getRoutesWithTeamIds(
      @Nullable Set<Long> teamIds,
      @Nullable User user,
      RouteSearchParams params,
      boolean includeDeleted,
      @Nullable Set<Long> tagIds) {
    PedalonsPage<Route> routes =
        routeRepository.find(listQuery(teamIds, user, params, includeDeleted, tagIds));
    // Two queries for the whole page — the comment count of a list row must not cost a round-trip
    // per row, and it is only filled in for teams this caller belongs to.
    CommentCounts commentCounts = commentCountLookup.forEntities(routes.items());
    // One more for the tags of the whole page, cross-team lists included (plan D7: shown there,
    // just not filterable).
    ContentTags tags = tagLookup.forContents(routes.items().stream().map(Route::getId).toList());
    List<RouteDto> dtos =
        routes.items().stream()
            .map(route -> RouteDto.from(route, assetService, commentCounts, tags, params.view()))
            .toList();
    return new RouteListResponse(dtos, routes.total(), params.page(), params.size());
  }

  /**
   * Delete route (soft delete).
   */
  @Transactional
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.DELETE)
  public void deleteRoute(String teamSlug, String slug) {
    Team team = teamService.getTeam(teamSlug);
    Route route = findBySlug(team, slug);

    route.setDeleted(true);
    routeRepository.persist(route);
    // A deleted route no longer gives its length: every ride, group and stage on it falls back to
    // the default duration (docs/LEDGER_*.md API-87).
    publicationEndCalculator.refreshUsersOf(route);
  }

  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.DELETE)
  @Transactional
  public RouteDetailDto undeleteRoute(String teamSlug, String slug) {
    Team team = teamService.getTeam(teamSlug);
    Route route = findBySlugIncludeDeleted(team, slug);
    requireNotRemovedByModeration(route);
    route.setDeleted(false);
    routeRepository.persist(route);
    // And a restored one gives it back (docs/LEDGER_*.md API-87).
    publicationEndCalculator.refreshUsersOf(route);
    return toDto(route);
  }

  @Override
  protected void updateMedia(TeamEntity teamEntity, @Valid MediaDto mediaDto) {
    super.updateMedia(teamEntity, mediaDto);
    Route route = (Route) teamEntity;
    for (Asset asset : teamEntity.getAssets()) {
      switch (asset.getType()) {
        case ROUTE_ORIGINAL_GPX, ROUTE_FILTERED_GPX -> asset.setFileName(route.getSlug() + ".gpx");
        case ROUTE_FIT -> asset.setFileName(route.getSlug() + ".fit");
        case ROUTE_THUMBNAIL_LIGHT, ROUTE_THUMBNAIL_DARK ->
            asset.setFileName(route.getSlug() + ".png");
      }
      assetRepository.persist(asset);
    }
  }
}
