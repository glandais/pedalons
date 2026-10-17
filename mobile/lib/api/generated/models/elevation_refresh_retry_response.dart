// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'elevation_refresh_retry_item.dart';

part 'elevation_refresh_retry_response.freezed.dart';
part 'elevation_refresh_retry_response.g.dart';

/// Outcome of an HD elevation retry, one entry per target
@Freezed()
abstract class ElevationRefreshRetryResponse
    with _$ElevationRefreshRetryResponse {
  const factory ElevationRefreshRetryResponse({
    /// Whether this was a dry run (nothing changed)
    required bool dryRun,

    /// Number of abandoned targets in the domain, before the limit
    required int matched,

    /// Targets listed, and retried unless dry run; at most the limit
    required List<ElevationRefreshRetryItem> items,
  }) = _ElevationRefreshRetryResponse;

  factory ElevationRefreshRetryResponse.fromJson(Map<String, Object?> json) =>
      _$ElevationRefreshRetryResponseFromJson(json);
}
