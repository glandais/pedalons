// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'gpx_import_track.dart';

part 'line_elevation_response.freezed.dart';
part 'line_elevation_response.g.dart';

/// The relief of straight lines, processed with the FAST elevations
@Freezed()
abstract class LineElevationResponse with _$LineElevationResponse {
  const factory LineElevationResponse({
    /// One track per requested line, in the same order, from its start to its end
    required List<GpxImportTrack> lines,

    /// True when part of the elevations could not be read from the elevation source
    required bool elevationFallback,
  }) = _LineElevationResponse;

  factory LineElevationResponse.fromJson(Map<String, Object?> json) =>
      _$LineElevationResponseFromJson(json);
}
