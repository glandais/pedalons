// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/elevation_refresh_retry_request.dart';
import '../models/elevation_refresh_retry_response.dart';

part 'admin_elevation_client.g.dart';

@RestApi()
abstract class AdminElevationClient {
  factory AdminElevationClient(Dio dio, {String? baseUrl}) =
      _AdminElevationClient;

  /// Retry abandoned HD elevation recomputations.
  ///
  /// Start again the HD recomputation of the routes and GPX-tool previews whose request used up its attempts (they stay on the fast profile, state FAST). Their attempts are reset and their due times spread one minute apart, oldest first, so the worker is not flooded; the targets go back to PENDING. Idempotent: a second call finds nothing. Run it with dryRun first.
  ///
  /// [domainId] - Target domain ID (defaults to the request's domain).
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/admin/elevation-refresh/retry')
  Future<ElevationRefreshRetryResponse> adminRetryElevationRefresh({
    @Body() required ElevationRefreshRetryRequest body,
    @Query('domainId') String? domainId,
  });
}
