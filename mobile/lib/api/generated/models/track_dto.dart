// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'climb_dto.dart';
import 'geo_json_line_string.dart';
import 'surface_span_dto.dart';
import 'track_surface_state.dart';

part 'track_dto.freezed.dart';
part 'track_dto.g.dart';

/// GPX track with track points
@Freezed()
abstract class TrackDto with _$TrackDto {
  const factory TrackDto({
    required GeoJsonLineString line,

    /// List of climbs on the route
    required List<ClimbDto> climbs,

    /// Where the surface of the track stands. Absent: never computed (a track saved before the feature, or the feature off), or not included (bulk endpoint)
    String? surfaceState,

    /// Surface along the track when surfaceState is READY: contiguous spans from 0 to the track's length, adjacent spans of the same class merged. Derived from OpenStreetMap (© OpenStreetMap contributors, ODbL) by Stadia Maps
    List<SurfaceSpanDto>? surfaces,
  }) = _TrackDto;

  factory TrackDto.fromJson(Map<String, Object?> json) =>
      _$TrackDtoFromJson(json);
}
