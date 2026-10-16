// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'gps_route_sync_state.dart';
import 'gps_service_type.dart';

part 'device_route_sync_status_dto.freezed.dart';
part 'device_route_sync_status_dto.g.dart';

/// Where the route stands at one of the user's GPS services
@Freezed()
abstract class DeviceRouteSyncStatusDto with _$DeviceRouteSyncStatusDto {
  const factory DeviceRouteSyncStatusDto({
    /// GPS service
    required String serviceType,

    /// SENT: at the service, up to date; OUTDATED: at the service in an older version that nothing will update, send it again; PENDING: to be sent or updated shortly; FAILING: the last attempt failed (a few retries, then it waits for the route to change); RECONNECT_REQUIRED: the connection must be renewed
    required String state,
  }) = _DeviceRouteSyncStatusDto;

  factory DeviceRouteSyncStatusDto.fromJson(Map<String, Object?> json) =>
      _$DeviceRouteSyncStatusDtoFromJson(json);
}
