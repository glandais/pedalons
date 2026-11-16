// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'generated_route_dto.dart';
import 'instant.dart';

part 'route_generator_response.freezed.dart';
part 'route_generator_response.g.dart';

/// Routes proposed by the route generator
@Freezed()
abstract class RouteGeneratorResponse with _$RouteGeneratorResponse {
  const factory RouteGeneratorResponse({
    /// One to three routes, best first, different from each other
    required List<GeneratedRouteDto> candidates,

    /// True when part of the area around the start leaves the region the generator covers: proposals are rarer there
    required bool partialCoverage,

    /// When the team's roads were last prepared for the generator (the night before at best). Absent when the request did not use them (discovery)
    String? networkPreparedAt,
  }) = _RouteGeneratorResponse;

  factory RouteGeneratorResponse.fromJson(Map<String, Object?> json) =>
      _$RouteGeneratorResponseFromJson(json);
}
