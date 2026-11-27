// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/thumbnail_catch_up_status.dart';
import '../models/thumbnail_regeneration_request.dart';
import '../models/thumbnail_regeneration_response.dart';

part 'admin_thumbnails_client.g.dart';

@RestApi()
abstract class AdminThumbnailsClient {
  factory AdminThumbnailsClient(Dio dio, {String? baseUrl}) =
      _AdminThumbnailsClient;

  /// State of the automatic thumbnail catch-up.
  ///
  /// How many routes, rides and trips of the domain have thumbnails drawn before the current basemap, how many of those wait for a new attempt, and how many the catch-up gave up on.
  ///
  /// [domainId] - Target domain ID (defaults to the request's domain).
  @GET('/api/admin/thumbnails/catch-up')
  Future<ThumbnailCatchUpStatus> adminGetThumbnailCatchUp({
    @Query('domainId') String? domainId,
  });

  /// Regenerate map thumbnails.
  ///
  /// Redraw the light and dark map thumbnails of routes, rides and trips from the geometry already stored, selected by drawing date, stored size or absence. Synchronous; run it with dryRun first.
  ///
  /// [domainId] - Target domain ID (defaults to the request's domain).
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/admin/thumbnails/regenerate')
  Future<ThumbnailRegenerationResponse> adminRegenerateThumbnails({
    @Body() required ThumbnailRegenerationRequest body,
    @Query('domainId') String? domainId,
  });
}
