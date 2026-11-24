// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'retouched_route_dto.dart';
import 'route_retouch_operation.dart';

part 'route_retouch_response.freezed.dart';
part 'route_retouch_response.g.dart';

/// Proposals to retouch a saved route
@Freezed()
abstract class RouteRetouchResponse with _$RouteRetouchResponse {
  const factory RouteRetouchResponse({
    /// The operation answered
    required String operation,

    /// Length of the original route's raw track in metres, the engine's own
    required double originalDistanceM,

    /// One to three proposals, best first
    required List<RetouchedRouteDto> candidates,

    /// Elevation gain of the original track, computed in the same batch as the proposals' so that before and after compare like with like
    double? originalAscentM,

    /// Elevation loss of the original track
    double? originalDescentM,

    /// RESIZE: the total distance asked, in metres
    double? targetDistanceM,

    /// When the team's roads were last prepared for the generator. Absent when the request did not use them (discovery)
    String? networkPreparedAt,
  }) = _RouteRetouchResponse;

  factory RouteRetouchResponse.fromJson(Map<String, Object?> json) =>
      _$RouteRetouchResponseFromJson(json);
}
