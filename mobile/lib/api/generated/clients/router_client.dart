// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/gpx_import_response.dart';
import '../models/router_request.dart';
import '../models/router_response.dart';

part 'router_client.g.dart';

@RestApi()
abstract class RouterClient {
  factory RouterClient(Dio dio, {String? baseUrl}) = _RouterClient;

  /// Calculate route.
  ///
  /// Calculate a route between two points using the Stadia Maps routing API. Each call is billed against a monthly quota, so the checks come first: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled. Otherwise ROUTE_PLANNER_DISABLED. Routing failures have their own codes: ROUTING_SEGMENT_TOO_LONG and ROUTING_NO_ROUTE (400), ROUTING_QUOTA_EXCEEDED and ROUTING_UNAVAILABLE (503).
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/router')
  Future<RouterResponse> route({
    @Body() required RouterRequest body,
  });

  /// Load a GPX file into the route editor.
  ///
  /// Processes a GPX file with the FAST elevations and returns its tracks as polylines, with the ascent accumulated up to each point. Nothing is stored and the routing provider is not called. Same rights as the route calculation: with teamSlug, the caller must be allowed to create routes in that team and the team must have the route planner enabled; without it, the domain's GPX planner must be enabled.
  ///
  /// [gpxFile] - Name not received - field will be skipped.
  ///
  /// [teamSlug] - Name not received - field will be skipped.
  @MultiPart()
  @POST('/api/router/import-gpx')
  Future<GpxImportResponse> importGpx({
    @Part(name: 'gpxFile') MultipartFile? gpxFile,
    @Part(name: 'teamSlug') String? teamSlug,
  });
}
