// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'route_generator_overlay_refresh_request.freezed.dart';
part 'route_generator_overlay_refresh_request.g.dart';

/// Which team overlays of the route generator to prepare now: the nightly pass, by hand. Without force, only the teams whose overlay is absent, stale, changed or about to expire.
@Freezed()
abstract class RouteGeneratorOverlayRefreshRequest
    with _$RouteGeneratorOverlayRefreshRequest {
  const factory RouteGeneratorOverlayRefreshRequest({
    /// Deposit every team again, whatever its overlay: after a key rotation or a new graph
    required bool force,

    /// Say what would be done, without depositing or deleting anything
    required bool dryRun,

    /// Only this team (default: every team of every domain)
    String? teamId,
  }) = _RouteGeneratorOverlayRefreshRequest;

  factory RouteGeneratorOverlayRefreshRequest.fromJson(
    Map<String, Object?> json,
  ) => _$RouteGeneratorOverlayRefreshRequestFromJson(json);
}
