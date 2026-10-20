// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_json_point.dart';
import 'waypoint_origin.dart';
import 'waypoint_type.dart';

part 'waypoint_dto.freezed.dart';
part 'waypoint_dto.g.dart';

/// A waypoint of a route. Its geometry is where the author put it: its own position, never its projection on the track
@Freezed()
abstract class WaypointDto with _$WaypointDto {
  const factory WaypointDto({
    required GeoJsonPoint geometry,

    /// Name, possibly empty
    required String name,

    /// What the waypoint is
    required String type,

    /// Who put the waypoint: its AUTHOR in the editor, or a GPX file it was IMPORTED from. A new GPX file replaces the imported ones and keeps the author's
    required String origin,

    /// Identifier (TSID) of the waypoint, to send back in the request so that it keeps its origin. Null for a waypoint of a GPX file not saved yet
    String? id,

    /// Free text, at most 500 characters
    String? description,

    /// Metres from the start along the tracks in order (cumulated from one track to the next, in the order of their ids). Null for a waypoint more than 50 m from the track
    double? distance,
  }) = _WaypointDto;

  factory WaypointDto.fromJson(Map<String, Object?> json) =>
      _$WaypointDtoFromJson(json);
}
