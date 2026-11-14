// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'generated_route_dto.dart';
import 'route_generator_network_dto.dart';

part 'route_generator_response.freezed.dart';
part 'route_generator_response.g.dart';

/// Routes proposed by the team's route generator
@Freezed()
abstract class RouteGeneratorResponse with _$RouteGeneratorResponse {
  const factory RouteGeneratorResponse({
    /// One to three routes, best first, different from each other
    required List<GeneratedRouteDto> candidates,

    /// What the team's network is made of
    required RouteGeneratorNetworkDto network,

    /// True when the team rides too few routes of the requested type nearby, so the familiarity of all kinds was used instead
    required bool familiarityFallback,
  }) = _RouteGeneratorResponse;

  factory RouteGeneratorResponse.fromJson(Map<String, Object?> json) =>
      _$RouteGeneratorResponseFromJson(json);
}
