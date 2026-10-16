// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'gps_auto_sync_state.dart';
import 'gps_service_type.dart';
import 'instant.dart';

part 'gps_service_connection_dto.freezed.dart';
part 'gps_service_connection_dto.g.dart';

/// GPS service connection information
@Freezed()
abstract class GpsServiceConnectionDto with _$GpsServiceConnectionDto {
  const factory GpsServiceConnectionDto({
    /// Service type identifier
    required String serviceType,

    /// Display name of the service
    required String displayName,

    /// When the service was connected
    required String connectedAt,

    /// Whether the routes of the rides the user is registered in are sent to this service automatically, and kept in sync (new route, corrected GPX, another group), from 7 days before the departure until a day after it
    required bool autoSync,

    /// Where the automatic sync stands. OFF when autoSync is false; RECONNECT_REQUIRED is only cleared by connecting the service again
    required String autoSyncState,

    /// How many routes the automatic sync currently has at the service (removed after the ride, or when the sync is turned off)
    required int autoSyncRouteCount,

    /// When the automatic sync last sent a route to this service
    String? lastAutoSyncAt,
  }) = _GpsServiceConnectionDto;

  factory GpsServiceConnectionDto.fromJson(Map<String, Object?> json) =>
      _$GpsServiceConnectionDtoFromJson(json);
}
