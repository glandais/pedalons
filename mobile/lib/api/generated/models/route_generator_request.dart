// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'compass_point.dart';
import 'geo_point.dart';
import 'route_generator_type.dart';

part 'route_generator_request.freezed.dart';
part 'route_generator_request.g.dart';

/// What to ask the team's route generator for
@Freezed()
abstract class RouteGeneratorRequest with _$RouteGeneratorRequest {
  const factory RouteGeneratorRequest({
    /// Wished distance in kilometres, 10 to 300
    required double distanceKm,

    /// Start. Absent: the team's location (400 VALIDATION if it has none)
    GeoPoint? start,

    /// End. Absent: a loop, the route ends where it starts. Present: a one-way route from start to end
    GeoPoint? end,

    /// Wished direction, only used when the end is closer than half the distance (a loop included)
    String? bearing,

    /// 0 prefers roads the team rides rarely, 1 the ones it rides often. Absent: 0.5
    double? familiarity,

    /// What to ride. Absent: ROAD
    String? type,

    /// Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0
    int? seed,
  }) = _RouteGeneratorRequest;

  factory RouteGeneratorRequest.fromJson(Map<String, Object?> json) =>
      _$RouteGeneratorRequestFromJson(json);
}
