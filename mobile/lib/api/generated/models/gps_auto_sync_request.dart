// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'gps_auto_sync_request.freezed.dart';
part 'gps_auto_sync_request.g.dart';

/// Turns the automatic route sync of one GPS service on or off
@Freezed()
abstract class GpsAutoSyncRequest with _$GpsAutoSyncRequest {
  const factory GpsAutoSyncRequest({
    /// true to send the routes of the user's upcoming rides to this service automatically; false to stop, which also removes from the service the upcoming routes the sync sent
    required bool enabled,
  }) = _GpsAutoSyncRequest;

  factory GpsAutoSyncRequest.fromJson(Map<String, Object?> json) =>
      _$GpsAutoSyncRequestFromJson(json);
}
