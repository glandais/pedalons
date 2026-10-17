// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'elevation_refresh_kind.dart';
import 'instant.dart';

part 'elevation_refresh_retry_item.freezed.dart';
part 'elevation_refresh_retry_item.g.dart';

/// One abandoned recomputation
@Freezed()
abstract class ElevationRefreshRetryItem with _$ElevationRefreshRetryItem {
  const factory ElevationRefreshRetryItem({
    /// Kind of target
    required String kind,

    /// ID of the route or preview
    required String targetId,

    /// Failed attempts before the retry
    required int attempts,

    /// When the recomputation was first requested
    required String firstRequestedAt,

    /// Team slug (routes)
    String? teamSlug,

    /// Route slug (routes)
    String? routeSlug,

    /// Public identifier (previews)
    String? previewPublicId,

    /// Last error recorded, before the retry
    String? lastError,
  }) = _ElevationRefreshRetryItem;

  factory ElevationRefreshRetryItem.fromJson(Map<String, Object?> json) =>
      _$ElevationRefreshRetryItemFromJson(json);
}
