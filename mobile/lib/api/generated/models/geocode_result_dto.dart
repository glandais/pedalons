// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'geocode_result_dto.freezed.dart';
part 'geocode_result_dto.g.dart';

/// A place matching a geocoding query
@Freezed()
abstract class GeocodeResultDto with _$GeocodeResultDto {
  const factory GeocodeResultDto({
    /// Opaque identifier of the result, stable enough to key a list on; what GET /api/geocode/place takes to resolve the position
    required String id,

    /// Full human-readable name of the place
    required String displayName,

    /// Latitude in degrees (WGS 84). Null on a search suggestion the provider gave no position for: resolve it with GET /api/geocode/place once the user picks it. Always set in that endpoint's answer.
    double? lat,

    /// Longitude in degrees (WGS 84). Null exactly when lat is null: resolve it with GET /api/geocode/place once the user picks the suggestion.
    double? lon,
  }) = _GeocodeResultDto;

  factory GeocodeResultDto.fromJson(Map<String, Object?> json) =>
      _$GeocodeResultDtoFromJson(json);
}
