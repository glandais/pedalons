// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/route_generator_overlay_refresh_request.dart';
import '../models/route_generator_overlay_refresh_response.dart';

part 'admin_route_generator_client.g.dart';

@RestApi()
abstract class AdminRouteGeneratorClient {
  factory AdminRouteGeneratorClient(Dio dio, {String? baseUrl}) =
      _AdminRouteGeneratorClient;

  /// Prepare the teams' roads for the route generator now.
  ///
  /// The nightly pass, by hand: for each team (or the one given), compares the digest of its tracks with the one the engine holds and deposits it again when it differs, is absent, stale or about to expire (or always with force); deletes the overlay of a deleted team, or one whose planner is off. Idempotent. With dryRun the answer (200) lists what would be done; otherwise the pass runs in the background (202, started=false if one already runs on this instance). Run it with dryRun first; use force after a key rotation or a new graph.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/admin/route-generator/overlays/refresh')
  Future<RouteGeneratorOverlayRefreshResponse>
  adminRefreshRouteGeneratorOverlays({
    @Body() required RouteGeneratorOverlayRefreshRequest body,
  });
}
