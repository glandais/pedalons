// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/count_response.dart';
import '../models/hilliness.dart';
import '../models/list_view_mode.dart';
import '../models/min_role.dart';
import '../models/near_type.dart';
import '../models/planner_state_response.dart';
import '../models/route_bounds_response.dart';
import '../models/route_detail_dto.dart';
import '../models/route_dto.dart';
import '../models/route_list_response.dart';
import '../models/route_request.dart';
import '../models/route_sort_by.dart';
import '../models/route_usages_response.dart';
import '../models/routes_bulk_response.dart';
import '../models/slug_change_request.dart';
import '../models/sort_direction.dart';
import '../models/surface_type.dart';
import '../models/wind_direction.dart';

part 'routes_client.g.dart';

@RestApi()
abstract class RoutesClient {
  factory RoutesClient(Dio dio, {String? baseUrl}) = _RoutesClient;

  /// List all routes.
  ///
  /// Get paginated list of routes from all accessible teams (user's teams + public teams).
  ///
  /// [hilliness] - Hilliness preset (FLAT, HILLY, MOUNTAINOUS).
  ///
  /// [maxDistance] - Maximum distance in meters.
  ///
  /// [maxElevationGain] - Maximum elevation gain in meters.
  ///
  /// [minDistance] - Minimum distance in meters.
  ///
  /// [minElevationGain] - Minimum elevation gain in meters.
  ///
  /// [minRole] - Only routes from teams where the user has at least this role. Yields nothing for an anonymous visitor.
  ///
  /// [nearLat] - Latitude for proximity search.
  ///
  /// [nearLon] - Longitude for proximity search.
  ///
  /// [nearRadius] - Search radius in meters (default: 25000).
  ///
  /// [nearType] - Search near START, END, or START_OR_END (default).
  ///
  /// [page] - Page number (0-indexed).
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [size] - Page size.
  ///
  /// [sortBy] - Sort by field (DISTANCE, ELEVATION_GAIN, HILLINESS, DATE_TIME).
  ///
  /// [sortDir] - Sort direction (ASC, DESC).
  ///
  /// [surfaceType] - Filter by surface type.
  ///
  /// [view] - How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte.
  ///
  /// [windDirection] - Filter by wind direction.
  @GET('/api/routes')
  Future<RouteListResponse> listAllRoutes({
    @Query('page') int? page = 0,
    @Query('size') int? size = 20,
    @Query('hilliness') Hilliness? hilliness,
    @Query('maxDistance') double? maxDistance,
    @Query('maxElevationGain') double? maxElevationGain,
    @Query('minDistance') double? minDistance,
    @Query('minElevationGain') double? minElevationGain,
    @Query('minRole') MinRole? minRole,
    @Query('nearLat') double? nearLat,
    @Query('nearLon') double? nearLon,
    @Query('nearRadius') double? nearRadius,
    @Query('nearType') NearType? nearType,
    @Query('search') String? search,
    @Query('sortBy') RouteSortBy? sortBy,
    @Query('sortDir') SortDirection? sortDir,
    @Query('surfaceType') SurfaceType? surfaceType,
    @Query('view') ListViewMode? view,
    @Query('windDirection') WindDirection? windDirection,
  });

  /// All routes bounding box.
  ///
  /// Extent enclosing the routes of all accessible teams, so a map can open framed on them. Accepts the same filters as the route list, minus sorting and pagination. Yields a null box when no route matches.
  ///
  /// [hilliness] - Hilliness preset (FLAT, HILLY, MOUNTAINOUS).
  ///
  /// [maxDistance] - Maximum distance in meters.
  ///
  /// [maxElevationGain] - Maximum elevation gain in meters.
  ///
  /// [minDistance] - Minimum distance in meters.
  ///
  /// [minElevationGain] - Minimum elevation gain in meters.
  ///
  /// [minRole] - Only routes from teams where the user has at least this role. Yields a null box for an anonymous visitor.
  ///
  /// [nearLat] - Latitude for proximity search.
  ///
  /// [nearLon] - Longitude for proximity search.
  ///
  /// [nearRadius] - Search radius in meters (default: 25000).
  ///
  /// [nearType] - Search near START, END, or START_OR_END (default).
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [surfaceType] - Filter by surface type.
  ///
  /// [windDirection] - Filter by wind direction.
  @GET('/api/routes/bounds')
  Future<RouteBoundsResponse> getAllRoutesBounds({
    @Query('hilliness') Hilliness? hilliness,
    @Query('maxDistance') double? maxDistance,
    @Query('maxElevationGain') double? maxElevationGain,
    @Query('minDistance') double? minDistance,
    @Query('minElevationGain') double? minElevationGain,
    @Query('minRole') MinRole? minRole,
    @Query('nearLat') double? nearLat,
    @Query('nearLon') double? nearLon,
    @Query('nearRadius') double? nearRadius,
    @Query('nearType') NearType? nearType,
    @Query('search') String? search,
    @Query('surfaceType') SurfaceType? surfaceType,
    @Query('windDirection') WindDirection? windDirection,
  });

  /// Count all routes.
  ///
  /// How many routes of all accessible teams match the filters, with none of them read. Accepts exactly the same filters as the route list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
  ///
  /// [hilliness] - Hilliness preset (FLAT, HILLY, MOUNTAINOUS).
  ///
  /// [maxDistance] - Maximum distance in meters.
  ///
  /// [maxElevationGain] - Maximum elevation gain in meters.
  ///
  /// [minDistance] - Minimum distance in meters.
  ///
  /// [minElevationGain] - Minimum elevation gain in meters.
  ///
  /// [minRole] - Only routes from teams where the user has at least this role. Yields zero for an anonymous visitor.
  ///
  /// [nearLat] - Latitude for proximity search.
  ///
  /// [nearLon] - Longitude for proximity search.
  ///
  /// [nearRadius] - Search radius in meters (default: 25000).
  ///
  /// [nearType] - Search near START, END, or START_OR_END (default).
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [surfaceType] - Filter by surface type.
  ///
  /// [windDirection] - Filter by wind direction.
  @GET('/api/routes/count')
  Future<CountResponse> countAllRoutes({
    @Query('hilliness') Hilliness? hilliness,
    @Query('maxDistance') double? maxDistance,
    @Query('maxElevationGain') double? maxElevationGain,
    @Query('minDistance') double? minDistance,
    @Query('minElevationGain') double? minElevationGain,
    @Query('minRole') MinRole? minRole,
    @Query('nearLat') double? nearLat,
    @Query('nearLon') double? nearLon,
    @Query('nearRadius') double? nearRadius,
    @Query('nearType') NearType? nearType,
    @Query('search') String? search,
    @Query('surfaceType') SurfaceType? surfaceType,
    @Query('windDirection') WindDirection? windDirection,
  });

  /// All routes vector tile.
  ///
  /// Mapbox vector tile holding the routes of all accessible teams, layer 'routes'. Accepts the same filters as the route list, minus sorting and pagination, which a tile has no use for. Fetched directly by the map renderer, outside the authenticated HTTP stack: a browser authenticates with its session cookie, any other client with the 't' tile token.
  ///
  /// [x] - Tile column.
  ///
  /// [y] - Tile row.
  ///
  /// [z] - Zoom level.
  ///
  /// [hilliness] - Hilliness preset (FLAT, HILLY, MOUNTAINOUS).
  ///
  /// [maxDistance] - Maximum distance in meters.
  ///
  /// [maxElevationGain] - Maximum elevation gain in meters.
  ///
  /// [minDistance] - Minimum distance in meters.
  ///
  /// [minElevationGain] - Minimum elevation gain in meters.
  ///
  /// [minRole] - Only routes from teams where the user has at least this role. Yields an empty tile for an anonymous visitor.
  ///
  /// [nearLat] - Latitude for proximity search.
  ///
  /// [nearLon] - Longitude for proximity search.
  ///
  /// [nearRadius] - Search radius in meters (default: 25000).
  ///
  /// [nearType] - Search near START, END, or START_OR_END (default).
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [surfaceType] - Filter by surface type.
  ///
  /// [t] - Tile token from POST /api/tiles/token, for clients whose map renderer cannot carry an Authorization header. Omitted, the request falls back to the session cookie and then to the anonymous visitor.
  ///
  /// [windDirection] - Filter by wind direction.
  @GET('/api/routes/tiles/{z}/{x}/{y}.mvt')
  Future<void> allRoutesTile({
    @Path('x') required int x,
    @Path('y') required int y,
    @Path('z') required int z,
    @Query('hilliness') Hilliness? hilliness,
    @Query('maxDistance') double? maxDistance,
    @Query('maxElevationGain') double? maxElevationGain,
    @Query('minDistance') double? minDistance,
    @Query('minElevationGain') double? minElevationGain,
    @Query('minRole') MinRole? minRole,
    @Query('nearLat') double? nearLat,
    @Query('nearLon') double? nearLon,
    @Query('nearRadius') double? nearRadius,
    @Query('nearType') NearType? nearType,
    @Query('search') String? search,
    @Query('surfaceType') SurfaceType? surfaceType,
    @Query('t') String? t,
    @Query('windDirection') WindDirection? windDirection,
  });

  /// List routes.
  ///
  /// Get paginated list of routes for a team with optional filters and sorting.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [hilliness] - Hilliness preset (FLAT, HILLY, MOUNTAINOUS).
  ///
  /// [maxDistance] - Maximum distance in meters.
  ///
  /// [maxElevationGain] - Maximum elevation gain in meters.
  ///
  /// [minDistance] - Minimum distance in meters.
  ///
  /// [minElevationGain] - Minimum elevation gain in meters.
  ///
  /// [nearLat] - Latitude for proximity search.
  ///
  /// [nearLon] - Longitude for proximity search.
  ///
  /// [nearRadius] - Search radius in meters (default: 25000).
  ///
  /// [nearType] - Search near START, END, or START_OR_END (default).
  ///
  /// [page] - Page number (0-indexed).
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [size] - Page size.
  ///
  /// [sortBy] - Sort by field (DISTANCE, ELEVATION_GAIN, HILLINESS, DATE_TIME).
  ///
  /// [sortDir] - Sort direction (ASC, DESC).
  ///
  /// [surfaceType] - Filter by surface type.
  ///
  /// [tags] - Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing.
  ///
  /// [view] - How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte.
  ///
  /// [windDirection] - Filter by wind direction.
  @GET('/api/teams/{teamSlug}/routes')
  Future<RouteListResponse> listRoutes({
    @Path('teamSlug') required String teamSlug,
    @Query('page') int? page = 0,
    @Query('size') int? size = 20,
    @Query('hilliness') Hilliness? hilliness,
    @Query('maxDistance') double? maxDistance,
    @Query('maxElevationGain') double? maxElevationGain,
    @Query('minDistance') double? minDistance,
    @Query('minElevationGain') double? minElevationGain,
    @Query('nearLat') double? nearLat,
    @Query('nearLon') double? nearLon,
    @Query('nearRadius') double? nearRadius,
    @Query('nearType') NearType? nearType,
    @Query('search') String? search,
    @Query('sortBy') RouteSortBy? sortBy,
    @Query('sortDir') SortDirection? sortDir,
    @Query('surfaceType') SurfaceType? surfaceType,
    @Query('tags') List<String>? tags,
    @Query('view') ListViewMode? view,
    @Query('windDirection') WindDirection? windDirection,
  });

  /// Create route.
  ///
  /// Create a new route by uploading a GPX file.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [route] - Name not received - field will be skipped.
  ///
  /// [gpxFile] - Name not received - field will be skipped.
  @MultiPart()
  @POST('/api/teams/{teamSlug}/routes')
  Future<RouteDto> createRoute({
    @Path('teamSlug') required String teamSlug,
    @Part(name: 'route') RouteRequest? route,
    @Part(name: 'gpxFile') MultipartFile? gpxFile,
  });

  /// Team routes bounding box.
  ///
  /// Extent enclosing the team's routes, so a map can open framed on them. Accepts the same filters as the route list, minus sorting and pagination. Yields a null box when no route matches.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [hilliness] - Hilliness preset (FLAT, HILLY, MOUNTAINOUS).
  ///
  /// [maxDistance] - Maximum distance in meters.
  ///
  /// [maxElevationGain] - Maximum elevation gain in meters.
  ///
  /// [minDistance] - Minimum distance in meters.
  ///
  /// [minElevationGain] - Minimum elevation gain in meters.
  ///
  /// [nearLat] - Latitude for proximity search.
  ///
  /// [nearLon] - Longitude for proximity search.
  ///
  /// [nearRadius] - Search radius in meters (default: 25000).
  ///
  /// [nearType] - Search near START, END, or START_OR_END (default).
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [surfaceType] - Filter by surface type.
  ///
  /// [tags] - Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing.
  ///
  /// [windDirection] - Filter by wind direction.
  @GET('/api/teams/{teamSlug}/routes/bounds')
  Future<RouteBoundsResponse> getRoutesBounds({
    @Path('teamSlug') required String teamSlug,
    @Query('hilliness') Hilliness? hilliness,
    @Query('maxDistance') double? maxDistance,
    @Query('maxElevationGain') double? maxElevationGain,
    @Query('minDistance') double? minDistance,
    @Query('minElevationGain') double? minElevationGain,
    @Query('nearLat') double? nearLat,
    @Query('nearLon') double? nearLon,
    @Query('nearRadius') double? nearRadius,
    @Query('nearType') NearType? nearType,
    @Query('search') String? search,
    @Query('surfaceType') SurfaceType? surfaceType,
    @Query('tags') List<String>? tags,
    @Query('windDirection') WindDirection? windDirection,
  });

  /// Get several routes' details at once.
  ///
  /// The detail of every requested 'slug' that exists and the caller may read, in one round-trip — built for the screens that load several routes together (a ride's stages, a comparison view), which would otherwise cost one request per route. Each row is exactly what the single-route endpoint returns, geometry included (track surfaces too, read for the whole batch at once). Unknown slugs and slugs the caller may not read are silently left out of the answer rather than failing the whole batch. Set 'geometry' to false for the screens that only need each route's name and figures. The response also carries the bounding box of the track geometry actually sent back (waypoints are excluded, so an imported meeting-point or car-park waypoint far off the track cannot widen it), so a map can frame the batch without a second request.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [geometry] - Whether to include each route's track geometry. False answers metadata only — name, distances, media, asset links — with an empty 'tracks' array and no 'extent', for the screens that name routes without drawing them.
  ///
  /// [slug] - Route slug to include, repeatable. Capped at 50; unknown slugs and slugs the caller may not read are silently omitted from the response rather than erroring. Unlike GET /{routeSlug}, a slug that was renamed is also omitted rather than followed to the route's current slug: the single-route endpoint falls back to the rename history, this one does not. Same 'omit, never fail' contract as an unknown or unreadable slug, just for a different reason.
  @GET('/api/teams/{teamSlug}/routes/bulk')
  Future<RoutesBulkResponse> getRoutesBulk({
    @Path('teamSlug') required String teamSlug,
    @Query('slug') List<String>? slug,
    @Query('geometry') bool? geometry = true,
  });

  /// Count routes.
  ///
  /// How many of the team's routes match the filters, with none of them read. Accepts exactly the same filters as the route list, minus sorting and pagination, so the figure and the list it opens can never disagree. Meant for a filter sheet that wants to announce its result count before the user commits to it.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [hilliness] - Hilliness preset (FLAT, HILLY, MOUNTAINOUS).
  ///
  /// [maxDistance] - Maximum distance in meters.
  ///
  /// [maxElevationGain] - Maximum elevation gain in meters.
  ///
  /// [minDistance] - Minimum distance in meters.
  ///
  /// [minElevationGain] - Minimum elevation gain in meters.
  ///
  /// [nearLat] - Latitude for proximity search.
  ///
  /// [nearLon] - Longitude for proximity search.
  ///
  /// [nearRadius] - Search radius in meters (default: 25000).
  ///
  /// [nearType] - Search near START, END, or START_OR_END (default).
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [surfaceType] - Filter by surface type.
  ///
  /// [tags] - Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing.
  ///
  /// [windDirection] - Filter by wind direction.
  @GET('/api/teams/{teamSlug}/routes/count')
  Future<CountResponse> countRoutes({
    @Path('teamSlug') required String teamSlug,
    @Query('hilliness') Hilliness? hilliness,
    @Query('maxDistance') double? maxDistance,
    @Query('maxElevationGain') double? maxElevationGain,
    @Query('minDistance') double? minDistance,
    @Query('minElevationGain') double? minElevationGain,
    @Query('nearLat') double? nearLat,
    @Query('nearLon') double? nearLon,
    @Query('nearRadius') double? nearRadius,
    @Query('nearType') NearType? nearType,
    @Query('search') String? search,
    @Query('surfaceType') SurfaceType? surfaceType,
    @Query('tags') List<String>? tags,
    @Query('windDirection') WindDirection? windDirection,
  });

  /// Team routes vector tile.
  ///
  /// Mapbox vector tile holding the team's routes, layer 'routes'. Accepts the same filters as the route list, minus sorting and pagination, which a tile has no use for. Fetched directly by the map renderer, outside the authenticated HTTP stack: a browser authenticates with its session cookie, any other client with the 't' tile token.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [x] - Tile column.
  ///
  /// [y] - Tile row.
  ///
  /// [z] - Zoom level.
  ///
  /// [hilliness] - Hilliness preset (FLAT, HILLY, MOUNTAINOUS).
  ///
  /// [maxDistance] - Maximum distance in meters.
  ///
  /// [maxElevationGain] - Maximum elevation gain in meters.
  ///
  /// [minDistance] - Minimum distance in meters.
  ///
  /// [minElevationGain] - Minimum elevation gain in meters.
  ///
  /// [nearLat] - Latitude for proximity search.
  ///
  /// [nearLon] - Longitude for proximity search.
  ///
  /// [nearRadius] - Search radius in meters (default: 25000).
  ///
  /// [nearType] - Search near START, END, or START_OR_END (default).
  ///
  /// [search] - Search by name/markdown.
  ///
  /// [surfaceType] - Filter by surface type.
  ///
  /// [t] - Tile token from POST /api/tiles/token, for clients whose map renderer cannot carry an Authorization header. Omitted, the request falls back to the session cookie and then to the anonymous visitor.
  ///
  /// [tags] - Only the routes carrying at least one of these tags — ids (TSID) of the team's ROUTE tags, comma-separated or repeated. Unknown ids are ignored; a filter left with no known id filters nothing.
  ///
  /// [windDirection] - Filter by wind direction.
  @GET('/api/teams/{teamSlug}/routes/tiles/{z}/{x}/{y}.mvt')
  Future<void> routesTile({
    @Path('teamSlug') required String teamSlug,
    @Path('x') required int x,
    @Path('y') required int y,
    @Path('z') required int z,
    @Query('hilliness') Hilliness? hilliness,
    @Query('maxDistance') double? maxDistance,
    @Query('maxElevationGain') double? maxElevationGain,
    @Query('minDistance') double? minDistance,
    @Query('minElevationGain') double? minElevationGain,
    @Query('nearLat') double? nearLat,
    @Query('nearLon') double? nearLon,
    @Query('nearRadius') double? nearRadius,
    @Query('nearType') NearType? nearType,
    @Query('search') String? search,
    @Query('surfaceType') SurfaceType? surfaceType,
    @Query('t') String? t,
    @Query('tags') List<String>? tags,
    @Query('windDirection') WindDirection? windDirection,
  });

  /// Update route.
  ///
  /// Update route metadata (name, markdown, etc.) and optionally replace the GPX file. If a new GPX file is provided, the old track data and climbs will be replaced.
  ///
  /// [routeSlug] - Route slug.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [route] - Name not received - field will be skipped.
  ///
  /// [gpxFile] - Name not received - field will be skipped.
  @MultiPart()
  @PUT('/api/teams/{teamSlug}/routes/{routeSlug}')
  Future<RouteDto> updateRoute({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
    @Part(name: 'route') RouteRequest? route,
    @Part(name: 'gpxFile') MultipartFile? gpxFile,
  });

  /// Get route details.
  ///
  /// Get detailed route information including GPS coordinates and statistics. The track is returned exactly as stored — already resampled and Douglas-Peucker-filtered at import, which lands it at roughly one point every 90 m. Every coordinate carries longitude, latitude, elevation and cumulative distance in meters, so a client can draw both the line and its elevation profile from this one payload.
  ///
  /// [routeSlug] - Route slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}/routes/{routeSlug}')
  Future<RouteDetailDto> getRoute({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Delete route.
  ///
  /// Soft delete a route. Requires route creator or team admin permissions.
  ///
  /// [routeSlug] - Route slug.
  ///
  /// [teamSlug] - Team URL slug.
  @DELETE('/api/teams/{teamSlug}/routes/{routeSlug}')
  Future<void> deleteRoute({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Get the planner state of a route.
  ///
  /// The control points, routed pieces and imported ranges the route was last saved with, for its edit page. Reserved to those who may edit the route. 'state' is absent when there is none to read back (never saved with one, track replaced since by a path that does not carry it, several tracks): the editor then opens the saved track as an import.
  ///
  /// [routeSlug] - Route slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}/routes/{routeSlug}/planner-state')
  Future<PlannerStateResponse> getRoutePlannerState({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Change route slug.
  ///
  /// Change route URL slug. Requires organizer permissions.
  ///
  /// [routeSlug] - Current route URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PATCH('/api/teams/{teamSlug}/routes/{routeSlug}/slug')
  Future<RouteDetailDto> changeRouteSlug({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
    @Body() required SlugChangeRequest body,
  });

  /// Restore route.
  ///
  /// Restore a soft-deleted route. Requires route creator or team admin permissions.
  ///
  /// [routeSlug] - Route slug.
  ///
  /// [teamSlug] - Team URL slug.
  @POST('/api/teams/{teamSlug}/routes/{routeSlug}/undelete')
  Future<RouteDetailDto> undeleteRoute({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// List route usages.
  ///
  /// Rides and trips that reference this route, directly or via a group/stage. Results are visibility filtered for the caller.
  ///
  /// [routeSlug] - Route slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}/routes/{routeSlug}/usages')
  Future<RouteUsagesResponse> getRouteUsages({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
  });
}
