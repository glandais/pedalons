// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_code.dart';
import 'error_details.dart';

part 'route_generator_network_details.freezed.dart';
part 'route_generator_network_details.g.dart';

@Freezed()
abstract class RouteGeneratorNetworkDetails
    with _$RouteGeneratorNetworkDetails {
  const factory RouteGeneratorNetworkDetails({
    /// Type
    required String type,

    /// Routes the network is made of
    required int routeCount,

    /// Routes whose roads are still being analysed and are not in the network yet
    required int pendingRouteCount,

    /// Routes ticked "ne pas utiliser pour générer des parcours"
    required int excludedRouteCount,

    /// Length of the whole network of the team, in metres
    required double totalLengthM,

    /// True when pendingRouteCount is above zero: the network may still grow
    required bool incomplete,
  }) = _RouteGeneratorNetworkDetails;

  factory RouteGeneratorNetworkDetails.fromJson(Map<String, Object?> json) =>
      _$RouteGeneratorNetworkDetailsFromJson(json);
}
