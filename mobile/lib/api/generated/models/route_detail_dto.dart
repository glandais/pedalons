// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'elevation_state.dart';
import 'geo_json_point.dart';
import 'instant.dart';
import 'media_dto.dart';
import 'public_user_dto.dart';
import 'surface_type.dart';
import 'tag_dto.dart';
import 'team_publication_dto.dart';
import 'track_dto.dart';
import 'visibility.dart';
import 'waypoint_dto.dart';

part 'route_detail_dto.freezed.dart';
part 'route_detail_dto.g.dart';

/// Detailed route information
@Freezed()
abstract class RouteDetailDto with _$RouteDetailDto {
  const factory RouteDetailDto({
    /// Route ID (TSID)
    required String id,

    /// Route slug
    required String slug,

    /// Team
    required TeamPublicationDto team,

    /// Route name
    required String name,

    /// Media
    required MediaDto media,

    /// Distance in meters
    required double distance,

    /// Total elevation gain in meters
    required double elevationGain,

    /// Total elevation loss in meters
    required double elevationLoss,

    /// Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.
    required String elevationState,

    /// Surface type
    required String surfaceType,

    /// Whether the route is public
    required String visibility,

    /// Creation timestamp
    required String createdAt,

    /// Last update timestamp
    required String updatedAt,

    /// Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'.
    required List<TrackDto> tracks,

    /// Waypoints
    required List<WaypointDto> waypoints,

    /// Whether the route is soft-deleted
    required bool deleted,

    /// The team's ROUTE tags the route carries, sorted by label. Empty when it carries none.
    required List<TagDto> tags,
    GeoJsonPoint? start,
    GeoJsonPoint? end,

    /// Creator user. Absent when the caller is not a member of the team: member names are never sent to anyone else.
    PublicUserDto? createdBy,

    /// Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero.
    int? commentCount,
  }) = _RouteDetailDto;

  factory RouteDetailDto.fromJson(Map<String, Object?> json) =>
      _$RouteDetailDtoFromJson(json);
}
