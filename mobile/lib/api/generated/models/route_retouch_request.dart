// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'route_retouch_end.dart';

part 'route_retouch_request.freezed.dart';
part 'route_retouch_request.g.dart';

/// What to change in a saved route: exactly one of targetDistanceKm (aim at a total distance) and end (move the finish)
@Freezed()
abstract class RouteRetouchRequest with _$RouteRetouchRequest {
  const factory RouteRetouchRequest({
    /// The total distance aimed at, in kilometres (not the change). The bounds of the field are the offer's (GET .../retouch): minDistanceKm to maxDistanceKm
    double? targetDistanceKm,

    /// The new finish
    RouteRetouchEnd? end,

    /// From the team's roads (0) to discovery (1); rounded to the hundredth by the engine. Absent: 0.25
    double? discovery,

    /// Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0
    int? seed,
  }) = _RouteRetouchRequest;

  factory RouteRetouchRequest.fromJson(Map<String, Object?> json) =>
      _$RouteRetouchRequestFromJson(json);
}
