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

  /// Propose routes made of the team's own roads.
  ///
  /// Proposes one to three routes, loops or one-way, whose every metre lies on a road that a route of the team already rides. Same rights as the route planner: the caller must be allowed to create routes in the team and the team must have its route planner on (ROUTE_PLANNER_DISABLED otherwise). Nothing is stored, no routing provider is called and no quota is drawn. Failures have their own codes, all 400: GENERATOR_START_TOO_FAR and GENERATOR_END_TOO_FAR (no road of the team within 2 km), GENERATOR_DISTANCE_TOO_SHORT, GENERATOR_NETWORK_TOO_SMALL (with RouteGeneratorNetworkDetails: also sent while the team's routes are still being analysed), GENERATOR_NETWORK_TOO_LARGE (the team's routes are more than the generator can hold in memory; no request succeeds until the limit is raised) and GENERATOR_NO_ROUTE. At most 30 requests per user in 15 minutes (ROUTE_GENERATOR_RATE_LIMITED, 429 with Retry-After); ROUTE_GENERATOR_BUSY (503) when the server has no free slot or the run took too long.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/teams/{teamSlug}/route-generator')
  Future<RouteGeneratorResponse> generateRoutes({
    @Path('teamSlug') required String teamSlug,
    @Body() required RouteGeneratorRequest body,
  });
}
