// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_generator_network_dto.freezed.dart';
part 'route_generator_network_dto.g.dart';

/// What the team's generator network is made of. Lengths in metres
@Freezed()
abstract class RouteGeneratorNetworkDto with _$RouteGeneratorNetworkDto {
  const factory RouteGeneratorNetworkDto({
    /// Length of the whole network of the team
    required double totalLengthM,

    /// Routes the network is made of
    required int routeCount,

    /// Routes whose roads are still being analysed and are not in the network yet
    required int pendingRouteCount,

    /// Routes ticked "ne pas utiliser pour générer des parcours"
    required int excludedRouteCount,

    /// True when pendingRouteCount is above zero: the network may still grow
    required bool incomplete,

    /// Length of the road the search can reach around the start and the end. Absent when no route was generated
    double? lengthM,
  }) = _RouteGeneratorNetworkDto;

  factory RouteGeneratorNetworkDto.fromJson(Map<String, Object?> json) =>
      _$RouteGeneratorNetworkDtoFromJson(json);
}
