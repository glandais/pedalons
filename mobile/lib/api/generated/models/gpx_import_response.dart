// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'gpx_import_track.dart';
import 'waypoint_dto.dart';

part 'gpx_import_response.freezed.dart';
part 'gpx_import_response.g.dart';

/// A GPX file processed for the route editor
@Freezed()
abstract class GpxImportResponse with _$GpxImportResponse {
  const factory GpxImportResponse({
    /// Name of the file: its metadata, else its first track, else its file name
    required String name,

    /// Tracks in the order of the file, 1 to 8
    required List<GpxImportTrack> tracks,

    /// Number of waypoints of the file (the first 500 are in waypoints)
    required int waypointCount,

    /// True when the elevations of a track could not all be read from the elevation source and part of them are the file's own
    required bool elevationFallback,

    /// The waypoints of the file, typed from their symbol, at most 500, in file order: imported, with no identifier and no distance (the server places them when the route is saved)
    List<WaypointDto>? waypoints,
  }) = _GpxImportResponse;

  factory GpxImportResponse.fromJson(Map<String, Object?> json) =>
      _$GpxImportResponseFromJson(json);
}
