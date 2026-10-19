// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/gps_service_type.dart';
import '../models/gpx_preview_dto.dart';
import '../models/gpx_preview_from_points_request.dart';
import '../models/gpx_preview_list_response.dart';
import '../models/gpx_preview_update_request.dart';
import '../models/planner_state_response.dart';
import '../models/route_dto.dart';
import '../models/route_request.dart';
import '../models/route_upload_response.dart';

part 'gpx_previews_client.g.dart';

@RestApi()
abstract class GpxPreviewsClient {
  factory GpxPreviewsClient(Dio dio, {String? baseUrl}) = _GpxPreviewsClient;

  /// List the current user's analysed GPX files.
  ///
  /// Returns the current user's previews still within the 30-day retention window, most recent first.
  ///
  /// [page] - Zero-based page number.
  ///
  /// [size] - Page size.
  @GET('/api/gpx-previews')
  Future<GpxPreviewListResponse> listMyPreviews({
    @Query('page') int? page = 0,
    @Query('size') int? size = 20,
  });

  /// Analyse a GPX file.
  ///
  /// Uploads a GPX file, runs the elevation and climb pipeline, and stores the result under an unguessable identifier for 30 days.
  ///
  /// [gpxFile] - Name not received - field will be skipped.
  @MultiPart()
  @POST('/api/gpx-previews')
  Future<GpxPreviewDto> createPreview({
    @Part(name: 'gpxFile') MultipartFile? gpxFile,
  });

  /// Create an analysed GPX file from planner points.
  ///
  /// Builds a preview from a route drawn with the planner (no GPX file; drawn = true), runs the elevation and climb pipeline, and stores the result under an unguessable identifier for 30 days.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/gpx-previews/from-points')
  Future<GpxPreviewDto> createPreviewFromPoints({
    @Body() required GpxPreviewFromPointsRequest body,
  });

  /// Merge several GPX files into one analysed GPX file.
  ///
  /// Uploads 2 to 10 GPX files (10 MB together at most) and merges all their tracks into a single track, choosing the order of the tracks and the direction each one is ridden in so that the summed straight-line gaps between them are as short as possible. The result then runs the same pipeline as a single upload and is stored the same way, for 30 days.
  ///
  /// [gpxFiles] - Name not received - field will be skipped.
  @MultiPart()
  @POST('/api/gpx-previews/merge')
  Future<GpxPreviewDto> mergePreviews({
    @Part(name: 'gpxFiles') List<MultipartFile>? gpxFiles,
  });

  /// Update an analysed GPX file.
  ///
  /// Rename the preview and, when a new GPX file or planner points are provided, replay the pipeline to replace its track. Only the creator may edit.
  ///
  /// [previewId] - Public preview identifier.
  ///
  /// [preview] - Name not received - field will be skipped.
  ///
  /// [gpxFile] - Name not received - field will be skipped.
  @MultiPart()
  @PUT('/api/gpx-previews/{previewId}')
  Future<GpxPreviewDto> updatePreview({
    @Path('previewId') required String previewId,
    @Part(name: 'preview') GpxPreviewUpdateRequest? preview,
    @Part(name: 'gpxFile') MultipartFile? gpxFile,
  });

  /// Get an analysed GPX file.
  ///
  /// Anyone holding the link may read the preview: the unguessable identifier is what grants access. Creating and deleting require an account.
  ///
  /// [previewId] - Public preview identifier.
  @GET('/api/gpx-previews/{previewId}')
  Future<GpxPreviewDto> getPreview({
    @Path('previewId') required String previewId,
  });

  /// Delete an analysed GPX file.
  ///
  /// Only the creator may delete.
  ///
  /// [previewId] - Public preview identifier.
  @DELETE('/api/gpx-previews/{previewId}')
  Future<void> deletePreview({
    @Path('previewId') required String previewId,
  });

  /// Send an analysed GPX file to a GPS service.
  ///
  /// Uploads the preview to the current user's connected Garmin, Hammerhead or Wahoo.
  ///
  /// [previewId] - Public preview identifier.
  ///
  /// [serviceType] - GPS service type.
  @POST('/api/gpx-previews/{previewId}/gps/{serviceType}')
  Future<RouteUploadResponse> uploadToGpsService({
    @Path('previewId') required String previewId,
    @Path('serviceType') required GpsServiceType serviceType,
  });

  /// Get the planner state of an analysed GPX file.
  ///
  /// The control points, routed pieces and imported ranges the preview was last saved with, for its edit page. Only the creator may read it. 'state' is absent when there is none to read back.
  ///
  /// [previewId] - Public preview identifier.
  @GET('/api/gpx-previews/{previewId}/planner-state')
  Future<PlannerStateResponse> getPreviewPlannerState({
    @Path('previewId') required String previewId,
  });

  /// Save an analysed GPX file as a route.
  ///
  /// Creates a team route from the preview's original upload. A preview that was drawn in the route planner (drawn = true) is refused with ROUTE_PLANNER_DISABLED when the team has no route planner; an imported GPX file can become a route of any team.
  ///
  /// [previewId] - Public preview identifier.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/gpx-previews/{previewId}/routes/{teamSlug}')
  Future<RouteDto> createRouteFromPreview({
    @Path('previewId') required String previewId,
    @Path('teamSlug') required String teamSlug,
    @Body() required RouteRequest body,
  });
}
