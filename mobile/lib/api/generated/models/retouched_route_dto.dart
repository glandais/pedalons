// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'bounds_dto.dart';
import 'retouch_kind.dart';
import 'retouch_variant.dart';
import 'retouched_span_dto.dart';

part 'retouched_route_dto.freezed.dart';
part 'retouched_route_dto.g.dart';

/// A route retouched by the generator's engine
@Freezed()
abstract class RetouchedRouteDto with _$RetouchedRouteDto {
  const factory RetouchedRouteDto({
    /// The WHOLE retouched route as a polyline of precision 6 (latitude then longitude), the encoding of the planner's GPX import
    required String polyline,

    /// Distance in metres
    required double distanceM,

    /// What changed
    required String kind,

    /// Share of the original route kept as it was drawn, 0 to 1
    required double keptShare,

    /// Metres of the kept parts that the engine could not match to its map: there, the route may ride a road twice and nothing was checked
    required double unmatchedM,

    /// The stretch that changed
    required RetouchedSpanDto changed,

    /// Map frame of the whole route
    required BoundsDto bounds,

    /// Elevation gain in metres, measured as the original's (originalAscentM). Absent when the profile was not ready in time
    double? ascentM,

    /// Elevation loss in metres. Absent like the gain
    double? descentM,

    /// Which choice a MOVE_END route makes. Absent for the others
    String? variant,

    /// MOVE_END and TRUNCATE: distance in metres from the asked finish to the last point of the route
    double? endSnapM,
  }) = _RetouchedRouteDto;

  factory RetouchedRouteDto.fromJson(Map<String, Object?> json) =>
      _$RetouchedRouteDtoFromJson(json);
}
