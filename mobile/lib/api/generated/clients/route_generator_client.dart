// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/route_generator_request.dart';
import '../models/route_generator_response.dart';

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
}
