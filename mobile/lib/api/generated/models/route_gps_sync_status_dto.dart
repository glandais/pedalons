// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'gps_route_sync_state.dart';
import 'gps_service_type.dart';
import 'instant.dart';

part 'route_gps_sync_status_dto.freezed.dart';
part 'route_gps_sync_status_dto.g.dart';

/// Where the route stands at one of the caller's automatically synced services
@Freezed()
abstract class RouteGpsSyncStatusDto with _$RouteGpsSyncStatusDto {
  const factory RouteGpsSyncStatusDto({
    /// GPS service
    required String serviceType,

    /// SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed
    required String state,

    /// When the route was last sent to the service successfully. Absent while it never was.
    String? syncedAt,
  }) = _RouteGpsSyncStatusDto;

  factory RouteGpsSyncStatusDto.fromJson(Map<String, Object?> json) =>
      _$RouteGpsSyncStatusDtoFromJson(json);
}
