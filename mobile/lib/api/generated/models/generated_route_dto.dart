// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'bounds_dto.dart';

part 'generated_route_dto.freezed.dart';
part 'generated_route_dto.g.dart';

/// A route proposed by the generator
@Freezed()
abstract class GeneratedRouteDto with _$GeneratedRouteDto {
  const factory GeneratedRouteDto({
    /// Geometry as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import
    required String polyline,

    /// Distance in metres
    required double distanceM,

    /// Share of the distance on the team's roads, short gaps between them included, 0 to 1
    required double teamShare,

    /// Share of the distance off pavement, 0 to 1, as the route page of a saved route measures it (surface tag, then track type, then road class)
    required double unpavedShare,

    /// Metres ridden twice (the way to and from the loop), counted once
    required double sharedM,

    /// Junctions crossed more than once outside the shared part
    required int crossings,

    /// Map frame of the route
    required BoundsDto bounds,

    /// Elevation gain in metres. Absent when the profile was not ready in time: the editor computes it
    double? ascentM,

    /// Elevation loss in metres. Absent like the gain
    double? descentM,

    /// Angle in degrees between the wished bearing and the route's. Absent when the bearing did not apply
    double? bearingDeviationDeg,

    /// The share of unpaved asked for, 0 to 1. Absent when no target was sent: a road ride, a request without it, or an engine that does not steer
    double? unpavedTarget,

    /// Whether unpavedShare is within the engine's tolerance of unpavedTarget. Absent like unpavedTarget. False: the area has no better route, compare the two to tell more from less
    bool? unpavedTargetReached,
  }) = _GeneratedRouteDto;

  factory GeneratedRouteDto.fromJson(Map<String, Object?> json) =>
      _$GeneratedRouteDtoFromJson(json);
}
