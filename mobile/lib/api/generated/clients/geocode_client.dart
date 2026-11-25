// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/geocode_result_dto.dart';

part 'geocode_client.g.dart';

@RestApi()
abstract class GeocodeClient {
  factory GeocodeClient(Dio dio, {String? baseUrl}) = _GeocodeClient;

  /// Resolve the position of a picked place.
  ///
  /// Returns the place whose id a search result carried, with lat and lon always set. Call it only for the result the user picked, never for every suggestion: each call is billed by the provider. The id is a query parameter because it contains ':'. An id that is not shaped like a provider id, or that the provider does not know, is a 404 (NOT_FOUND); a provider failure or spent quota is a 503 (GEOCODING_UNAVAILABLE) — the client should then let the user search and pick again, or leave the position empty.
  ///
  /// [id] - The id of a search result, e.g. whosonfirst:locality:101750851.
  @GET('/api/geocode/place')
  Future<GeocodeResultDto> resolvePlace({
    @Query('id') required String id,
  });

  /// Search places by name.
  ///
  /// Returns at most 5 places matching the query, or an empty list when the query is shorter than 3 characters or the provider is unreachable. A result's lat and lon are null when the provider gave no position for it (the usual case): once the user picks it, resolve its position with GET /api/geocode/place?id=. Never resolve every suggestion: each resolution is billed. Results come from the Stadia Maps geocoder: a client displaying them must credit 'Stadia Maps, © OpenStreetMap contributors & others'.
  @GET('/api/geocode/search')
  Future<List<GeocodeResultDto>> searchPlaces({
    @Query('q') String? q,
  });
}
