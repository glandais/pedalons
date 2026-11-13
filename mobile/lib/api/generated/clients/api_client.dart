// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/route_details_capabilities.dart';
import '../models/route_details_request.dart';
import '../models/route_details_response.dart';

part 'api_client.g.dart';

@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String? baseUrl}) = _ApiClient;

  @GET('/v1/capabilities')
  Future<RouteDetailsCapabilities> capabilities();

  /// [body] - Name not received - field will be skipped.
  @POST('/v1/route-details')
  Future<RouteDetailsResponse> routeDetails({
    @Body() required RouteDetailsRequest body,
  });
}
