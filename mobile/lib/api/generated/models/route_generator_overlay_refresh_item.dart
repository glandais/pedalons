// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'action.dart';
import 'instant.dart';
import 'reason.dart';

part 'route_generator_overlay_refresh_item.freezed.dart';
part 'route_generator_overlay_refresh_item.g.dart';

/// One team's overlay
@Freezed()
abstract class RouteGeneratorOverlayRefreshItem
    with _$RouteGeneratorOverlayRefreshItem {
  const factory RouteGeneratorOverlayRefreshItem({
    /// ID of the team
    required String teamId,

    /// Slug of the team
    required String teamSlug,

    /// What is done
    required String action,

    /// Why
    required String reason,

    /// State of the overlay at the engine: absent, ready or stale
    String? state,

    /// When it was deposited
    String? depositedAt,

    /// When the engine drops it if it is not deposited again
    String? expiresAt,
  }) = _RouteGeneratorOverlayRefreshItem;

  factory RouteGeneratorOverlayRefreshItem.fromJson(
    Map<String, Object?> json,
  ) => _$RouteGeneratorOverlayRefreshItemFromJson(json);
}
