// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'thumbnail_catch_up_status.freezed.dart';
part 'thumbnail_catch_up_status.g.dart';

/// State of the automatic catch-up that redraws outdated map thumbnails
@Freezed()
abstract class ThumbnailCatchUpStatus with _$ThumbnailCatchUpStatus {
  const factory ThumbnailCatchUpStatus({
    /// Current version of the thumbnail drawing
    required int version,

    /// Whether the scheduled catch-up is switched on
    required bool enabled,

    /// Entities the catch-up redraws per hour, per backend
    required int perHour,

    /// Entities with thumbnails drawn before the current version that the catch-up still has to redraw, those waiting for a retry included
    required int behind,

    /// Among the entities behind, those waiting for the next attempt
    required int waiting,

    /// Entities the catch-up gave up on after repeated failures
    required int givenUp,
  }) = _ThumbnailCatchUpStatus;

  factory ThumbnailCatchUpStatus.fromJson(Map<String, Object?> json) =>
      _$ThumbnailCatchUpStatusFromJson(json);
}
