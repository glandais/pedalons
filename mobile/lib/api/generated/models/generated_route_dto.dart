// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'bounds_dto.dart';

part 'generated_route_dto.freezed.dart';
part 'generated_route_dto.g.dart';

/// A route proposed by the generator, every metre of it on a team road
@Freezed()
abstract class GeneratedRouteDto with _$GeneratedRouteDto {
  const factory GeneratedRouteDto({
    /// Geometry as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import
    required String polyline,

    /// Distance in metres
    required double distanceM,

    /// Elevation gain in metres
    required double ascentM,

    /// Elevation loss in metres
    required double descentM,

    /// How often the team rides these roads, 0 to 1
    required double familiarity,

    /// Share of the distance on unpaved roads, 0 to 1
    required double unpavedShare,

    /// Metres ridden twice (the way to and from the loop), counted once
    required double sharedM,

    /// Junctions crossed more than once outside the shared part
    required int crossings,

    /// Map frame of the route
    required BoundsDto bounds,

    /// Angle in degrees between the wished bearing and the route's. Absent when the bearing did not apply
    double? bearingDeviationDeg,
  }) = _GeneratedRouteDto;

  factory GeneratedRouteDto.fromJson(Map<String, Object?> json) =>
      _$GeneratedRouteDtoFromJson(json);
}
