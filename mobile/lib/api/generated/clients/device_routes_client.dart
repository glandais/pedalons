// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/device_routes_response.dart';
import '../models/route_upload_response.dart';

part 'device_routes_client.g.dart';

@RestApi()
abstract class DeviceRoutesClient {
  factory DeviceRoutesClient(Dio dio, {String? baseUrl}) = _DeviceRoutesClient;

  /// List routes for user.
  ///
  /// Get routes for authenticated user. Prioritizes routes from upcoming rides, then latest routes from user's teams.
  ///
  /// [details] - Also return, on each registered group, teamName, startPlaceName, status and endDateTime, and list the groups of a cancelled ride. Off by default: a device that does not ask keeps the response it always had.
  ///
  /// [lat] - User's current latitude (for proximity sorting).
  ///
  /// [lon] - User's current longitude (for proximity sorting).
  ///
  /// [stages] - Also return registeredStages, the upcoming stages of the trips the user is registered for. Off by default: a device that does not ask keeps the response it always had.
  @GET('/api/device/routes')
  Future<DeviceRoutesResponse> deviceListRoutes({
    @Query('lat') double? lat,
    @Query('lon') double? lon,
    @Query('details') bool? details = false,
    @Query('stages') bool? stages = false,
  });

  /// Download FIT file.
  ///
  /// Download route as FIT file for GPS devices.
  ///
  /// [routeSlug] - Route URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/device/routes/{teamSlug}/{routeSlug}/fit')
  Future<void> deviceDownloadFit({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Download GPX file.
  ///
  /// Download route as GPX file for GPS devices.
  ///
  /// [routeSlug] - Route URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/device/routes/{teamSlug}/{routeSlug}/gpx')
  Future<void> deviceDownloadGpx({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
  });

  /// Sync route to cloud service.
  ///
  /// Upload route to a cloud GPS service (e.g., Hammerhead, Garmin Connect, Wahoo).
  ///
  /// [routeSlug] - Route slug.
  ///
  /// [teamSlug] - Team slug.
  ///
  /// [type] - GPS service type (hammerhead, garmin, wahoo).
  @POST('/api/device/routes/{teamSlug}/{routeSlug}/sync')
  Future<RouteUploadResponse> deviceSyncRoute({
    @Path('routeSlug') required String routeSlug,
    @Path('teamSlug') required String teamSlug,
    @Query('type') required String type,
  });
}
