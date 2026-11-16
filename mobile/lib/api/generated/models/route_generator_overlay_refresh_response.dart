// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'route_generator_overlay_refresh_item.dart';

part 'route_generator_overlay_refresh_response.freezed.dart';
part 'route_generator_overlay_refresh_response.g.dart';

/// What the pass over the teams' overlays did, or would do (dry run)
@Freezed()
abstract class RouteGeneratorOverlayRefreshResponse
    with _$RouteGeneratorOverlayRefreshResponse {
  const factory RouteGeneratorOverlayRefreshResponse({
    /// False when nothing started: the generator is off or unconfigured, or a pass is already running
    required bool started,

    /// One entry per team that is deposited, deleted, or kept (dry run only: a started pass answers 202 with no entries, it runs in the background)
    required List<RouteGeneratorOverlayRefreshItem> items,

    /// Identity of the graph the engine serves
    String? graphId,
  }) = _RouteGeneratorOverlayRefreshResponse;

  factory RouteGeneratorOverlayRefreshResponse.fromJson(
    Map<String, Object?> json,
  ) => _$RouteGeneratorOverlayRefreshResponseFromJson(json);
}
