package fr.pedalons.service.route;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.comments.response.CommentCounts;
import fr.pedalons.dto.common.CountResponse;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.request.RouteSearchParams;
import fr.pedalons.dto.routes.response.BoundsDto;
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
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.TagTarget;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.common.TeamEntityQueryBasic;
import fr.pedalons.repository.ride.RideRepository;
import fr.pedalons.repository.route.RouteQuery;
import fr.pedalons.repository.route.RouteRepository;
import fr.pedalons.repository.trip.TripRepository;
import fr.pedalons.service.comment.CommentCountLookup;
import fr.pedalons.service.common.TeamEntityService;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.route.response.TrackMetadata;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.security.annotation.Public;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.tag.TagService;
import io.github.glandais.gpx.data.GPX;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
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

  @Inject AssetRepository assetRepository;

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
        entity, assetService, commentCountLookup.forEntity(entity), tagsOf(entity), true);
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

    Map<String, RouteDetailDto> bySlug = new LinkedHashMap<>();
    for (Route route : routes) {
      bySlug.put(
          route.getSlug(), RouteDetailDto.from(route, assetService, commentCounts, tags, geometry));
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
    Team team = teamService.getTeam(teamSlug);
    User creator = pedalonsContext.getUser();

    validateVisibility(team, request);

    // Validate GPX file
    List<GeoPoint> routePoints = request.points();
    if (gpxPath == null && (routePoints == null || routePoints.isEmpty())) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    checkPlannerAllowed(team, gpxPath, routePoints);

    String slug = slugService.generateSlug(request.name(), team.getId(), routeRepository);

    // Create route entity
    Route route =
        new Route(creator, team, request.name(), slug, request.visibility(), request.surfaceType());

    // Persist to get ID for file storage
    routeRepository.persistAndFlush(route);
    // Before the GPX work: a refused tag is a 400 with nothing stored yet.
    tagService.replaceTags(route, request.tagIds());

    try {

      GPX gpx;
      if (gpxPath != null) {
        gpx = gpxProcessingService.parseGpx(gpxPath);
      } else {
        gpx = gpxProcessingService.fromPoints(route.getName(), routePoints);
      }
      // Phase 1: CPU + S3 (transaction suspended, DB connection released)
      GpxProcessingService.GpxProcessingResult gpxResult =
          gpxProcessingService.processGpxData(route, gpx);

      // Phase 2: DB persist (transaction resumed, short burst)
      TrackMetadata metadata = gpxProcessingService.persistGpxData(route, gpxResult);

      route.setDistance(metadata.distance());
      route.setElevationGain(metadata.elevationGain());
      route.setHilliness(metadata.hilliness());
      route.setElevationLoss(metadata.elevationLoss());
      route.setStart(metadata.start());
      route.setEnd(metadata.end());
      route.setWindDirection(getWindDirection(metadata));

      updateMedia(route, request.media());
      routeRepository.persist(route);
      return RouteDto.from(route, assetService, commentCountLookup.forEntity(route), tagsOf(route));
    } catch (Exception e) {
      gpxProcessingService.deleteRouteFiles(route);
      throw e;
    }
  }

  /**
   * Refuse a drawn track when the team's planner is closed.
   *
   * <p>The two sources are told apart the same way the processing below does it: a {@code gpxPath}
   * means an imported file and always wins, so points only matter when no file came with the
   * request. This deliberately lives here and not in {@code RouteAccessChecker} — the checker only
   * ever sees the team slug and the entity slug, never the payload, so it cannot distinguish a
   * drawing from an import.
   */
  private void checkPlannerAllowed(
      Team team, @Nullable Path gpxPath, @Nullable List<GeoPoint> points) {
    if (gpxPath == null && points != null && !points.isEmpty() && !team.isEnableRoutePlanner()) {
      throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
    }
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

    validateVisibility(team, request);
    checkPlannerAllowed(team, gpxPath, request.points());

    // Update basic metadata
    route.setName(request.name());
    route.setSurfaceType(request.surfaceType());
    route.setVisibility(request.visibility());
    route.setDateTime(Instant.now());
    // Before the GPX work, for the same reason as on creation.
    tagService.replaceTags(route, request.tagIds());

    // Read before the try below: a file refused here (unparseable, or too long — SEC-6) keeps its
    // own error code and leaves the route's current files alone, which the catch would delete.
    GPX gpx = null;
    if (gpxPath != null) {
      gpx = gpxProcessingService.parseGpx(gpxPath);
    } else {
      List<GeoPoint> points = request.points();
      if (points != null && !points.isEmpty()) {
        gpx = gpxProcessingService.fromPoints(route.getName(), points);
      }
    }

    try {
      // If GPX file provided, update track and climbs
      if (gpx != null) {
        // Delete old GPX files
        gpxProcessingService.deleteRouteFiles(route);
        route.getTracks().clear();
        route.getWaypoints().clear();

        // Phase 1: CPU + S3 (transaction suspended, DB connection released)
        GpxProcessingService.GpxProcessingResult gpxResult =
            gpxProcessingService.processGpxData(route, gpx);

        // Phase 2: DB persist (transaction resumed, short burst)
        TrackMetadata metadata = gpxProcessingService.persistGpxData(route, gpxResult);

        route.setDistance(metadata.distance());
        route.setElevationGain(metadata.elevationGain());
        route.setHilliness(metadata.hilliness());
        route.setElevationLoss(metadata.elevationLoss());
        route.setStart(metadata.start());
        route.setEnd(metadata.end());
        route.setWindDirection(getWindDirection(metadata));
      }
    } catch (Exception e) {
      gpxProcessingService.deleteRouteFiles(route);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    if (gpx != null) {
      // A new track is a new distance: every ride, group and stage riding it ends at another time
      // (docs/LEDGER_*.md API-85).
      publicationEndCalculator.refreshUsersOf(route);
    }

    updateMedia(route, request.media());
    routeRepository.persist(route);
    return RouteDto.from(route, assetService, commentCountLookup.forEntity(route), tagsOf(route));
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
