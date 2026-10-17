// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'elevation_refresh_kind.dart';

part 'elevation_refresh_retry_request.freezed.dart';
part 'elevation_refresh_retry_request.g.dart';

/// Which abandoned HD elevation recomputations to start again: the routes and GPX-tool previews whose request used up its attempts and stay on the fast profile.
@Freezed()
abstract class ElevationRefreshRetryRequest
    with _$ElevationRefreshRetryRequest {
  const factory ElevationRefreshRetryRequest({
    /// List what would be retried, without changing anything
    required bool dryRun,

    /// Retry at most this many targets, oldest first (default 100)
    int? limit,

    /// Only this kind of target (default: both)
    String? kind,
  }) = _ElevationRefreshRetryRequest;

  factory ElevationRefreshRetryRequest.fromJson(Map<String, Object?> json) =>
      _$ElevationRefreshRetryRequestFromJson(json);
}
