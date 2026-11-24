// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/route_generator_request.dart';
import '../models/route_generator_response.dart';
import '../models/route_retouch_offer_dto.dart';
import '../models/route_retouch_request.dart';
import '../models/route_retouch_response.dart';

part 'route_generator_client.g.dart';

@RestApi()
abstract class RouteGeneratorClient {
  factory RouteGeneratorClient(Dio dio, {String? baseUrl}) =
      _RouteGeneratorClient;

  /// Propose routes that favour the team's own roads.
  ///
  /// Proposes one to three routes, loops or one-way, from the roads a route of the team already rides (prepared every night for the generator) and the rest of the map: the cursor `discovery` goes from the team's roads only (0) to no preference (1), default 0.25. The engine is osm-route-details and covers one region for now (GENERATOR_OUT_OF_COVERAGE elsewhere); each route was checked by an independent checker of the engine and by a geometric sanity check here. Ascent and descent are computed from the fast elevation profile and are absent when it was not ready in time. Same rights as the route planner: the caller must be allowed to create routes in the team and the team must have its route planner on (ROUTE_PLANNER_DISABLED otherwise). Nothing is stored, no routing provider is called and no quota is drawn. Failures have their own codes, all 400: GENERATOR_START_TOO_FAR and GENERATOR_END_TOO_FAR (no suitable road near), GENERATOR_DISTANCE_TOO_SHORT, GENERATOR_NETWORK_TOO_SMALL, GENERATOR_OUT_OF_COVERAGE, GENERATOR_NETWORK_NOT_READY (the team's roads are not prepared yet; discovery needs no preparation) and GENERATOR_NO_ROUTE. At most 30 requests per user in 15 minutes (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503) when the engine has no free slot or took too long, GENERATOR_UNAVAILABLE (503) when it is off or unreachable.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/teams/{teamSlug}/route-generator')
  Future<RouteGeneratorResponse> generateRoutes({
    @Path('teamSlug') required String teamSlug,
    @Body() required RouteGeneratorRequest body,
  });

  /// Propose changes to a saved route: a total distance, or a new finish.
  ///
  /// Proposes one to three routes that change ONE stretch of the saved route and keep the rest as it was drawn, by asking the route generator's engine (osm-route-details): `targetDistanceKm` aims at a total distance (within the offer's bounds, 30 percent of the route at most), `end` moves the finish (a point, or a place of the team); exactly one of the two. Each proposal carries the whole polyline and the indices of the stretch that changed. Ascent and descent come from the same profile for the original (`originalAscentM`) and the proposals. Nothing is stored, no quota is drawn: the proposal is opened in the planner as a new route. Same rights as the route planner plus reading the route; the route's street edges must be computed for its current track (ROUTE_RETOUCH_NOT_READY otherwise: nothing is computed on the fly). Refusals are answers, all 400: ROUTE_RETOUCH_NO_SHORTER (shortening fails about four times in ten, a normal case), ROUTE_RETOUCH_NO_PROPOSAL, ROUTE_RETOUCH_ORDER_ANOMALY (about one track in twenty), ROUTE_RETOUCH_CHANGE_TOO_SMALL, ROUTE_RETOUCH_CHANGE_TOO_LARGE, ROUTE_RETOUCH_END_UNREACHABLE, ROUTE_RETOUCH_UNSUPPORTED, ROUTE_RETOUCH_NOT_READY, GENERATOR_END_TOO_FAR, GENERATOR_OUT_OF_COVERAGE. The 30 requests per 15 minutes of the route generator are shared (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503), GENERATOR_UNAVAILABLE (503, also when the engine does not announce route edits: nothing is sent to it).
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/teams/{teamSlug}/routes/{routeSlug}/retouch')
  Future<RouteRetouchResponse> retouchRoute({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
    @Body() required RouteRetouchRequest body,
  });

  /// Whether a route can be retouched by the caller, and within which bounds.
  ///
  /// Answers 200 whatever the outcome: `available` and, when not, `unavailableReason` (NOT_ALLOWED and ENGINE_UNAVAILABLE and UNSUPPORTED: show nothing; NOT_READY: the route's analysis is not finished, show the action disabled). The offer comes from the engine's capabilities (a generator engine that cannot edit offers nothing) and from the head of the route's stored documents: nothing is computed, the engine is not called and no request is counted. The route must be readable by the caller (404 otherwise).
  @GET('/api/teams/{teamSlug}/routes/{routeSlug}/retouch')
  Future<RouteRetouchOfferDto> getRouteRetouchOffer({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
  });
}
