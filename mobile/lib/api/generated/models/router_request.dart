// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_point.dart';
import 'router_profile.dart';

part 'router_request.freezed.dart';
part 'router_request.g.dart';

@Freezed()
abstract class RouterRequest with _$RouterRequest {
  const factory RouterRequest({
    required GeoPoint from,
    required GeoPoint to,
    required RouterProfile profile,

    /// Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled.
    String? teamSlug,

    /// Propensity to climb, 0 (avoid hills) to 1 (no fear). Absent: the profile's value. Bicycle profiles only; ignored otherwise.
    double? useHills,

    /// Propensity to ride with traffic, 0 (cycleways and paths) to 1 (roads). Absent: the profile's value (1 for FASTBIKE). Bicycle profiles only; ignored otherwise.
    double? useRoads,
  }) = _RouterRequest;

  factory RouterRequest.fromJson(Map<String, Object?> json) =>
      _$RouterRequestFromJson(json);
}
