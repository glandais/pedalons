// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'gpx_import_track.freezed.dart';
part 'gpx_import_track.g.dart';

/// A track of an imported GPX file
@Freezed()
abstract class GpxImportTrack with _$GpxImportTrack {
  const factory GpxImportTrack({
    /// Polyline (precision 6, latitude then longitude) of the processed track, as PlannerSource.line
    required String line,

    /// Length in metres
    required double dist,

    /// Reported ascent in metres
    required double ascend,

    /// One-dimension polyline (tenths of a metre), one value per point of line; absent when an elevation is not finite
    String? ele,

    /// One-dimension polyline (tenths of a metre): the ascent accumulated up to each point of line (dead-band, non-decreasing, first 0, last = ascend); absent when ele is
    String? climb,
  }) = _GpxImportTrack;

  factory GpxImportTrack.fromJson(Map<String, Object?> json) =>
      _$GpxImportTrackFromJson(json);
}
