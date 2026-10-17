// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'track_dto.dart';
import 'waypoint_dto.dart';

part 'gpx_preview_dto.freezed.dart';
part 'gpx_preview_dto.g.dart';

/// Analysed GPX file, not attached to any team
@Freezed()
abstract class GpxPreviewDto with _$GpxPreviewDto {
  const factory GpxPreviewDto({
    /// Public identifier used in URLs
    required String id,

    /// Track name
    required String name,

    /// Distance in meters
    required double distance,

    /// Total elevation gain in meters
    required double elevationGain,

    /// Total elevation loss in meters
    required double elevationLoss,

    /// Elevation gain per kilometer
    required double hilliness,

    /// Whether the current user created this preview
    required bool owned,

    /// Creation timestamp
    required String createdAt,

    /// URL to download the analysed GPX file
    required String gpxUrl,

    /// URL to download the analysed track as a FIT file
    required String fitUrl,

    /// Whether the track was drawn in the route planner (true) rather than imported from a GPX file. A drawn preview can only become a route of a team whose route planner is enabled; false when the origin is unknown
    required bool drawn,

    /// Tracks
    required List<TrackDto> tracks,

    /// Waypoints
    required List<WaypointDto> waypoints,

    /// Rendered map thumbnail template URL (with a {size} placeholder), used for link previews; null when no thumbnail was generated. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,
  }) = _GpxPreviewDto;

  factory GpxPreviewDto.fromJson(Map<String, Object?> json) =>
      _$GpxPreviewDtoFromJson(json);
}
