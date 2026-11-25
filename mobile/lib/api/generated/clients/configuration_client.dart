// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/config_dto.dart';

part 'configuration_client.g.dart';

@RestApi()
abstract class ConfigurationClient {
  factory ConfigurationClient(Dio dio, {String? baseUrl}) =
      _ConfigurationClient;

  /// Get application configuration.
  ///
  /// Get frontend configuration including auth and app settings.
  @GET('/api/config')
  Future<ConfigDto> getConfig();

  /// Get a generated map style.
  ///
  /// Returns the MapLibre style document for a raster basemap whose provider serves tiles only. The URL is the one already carried by MapStyleDto.url — clients hand it to the map engine rather than building it themselves.
  @GET('/api/map/styles/{id}.json')
  Future<dynamic> getStyle({
    @Path('id') required String id,
  });
}
