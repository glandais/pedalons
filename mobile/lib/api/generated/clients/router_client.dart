// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/router_request.dart';
import '../models/router_response.dart';

part 'router_client.g.dart';

@RestApi()
abstract class RouterClient {
  factory RouterClient(Dio dio, {String? baseUrl}) = _RouterClient;

  /// Calculate route.
  ///
  /// Calculate a route between two points using the Stadia Maps routing API.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/router')
  Future<RouterResponse> route({
    @Body() required RouterRequest body,
  });
}
