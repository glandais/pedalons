// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'device_route_sync_status_dto.dart';
import 'instant.dart';
import 'status.dart';

part 'device_registered_stage_dto.freezed.dart';
part 'device_registered_stage_dto.g.dart';

/// Upcoming stage of a trip the user is registered for, with the route to load on the device
@Freezed()
abstract class DeviceRegisteredStageDto with _$DeviceRegisteredStageDto {
  const factory DeviceRegisteredStageDto({
    /// Team slug
    required String teamSlug,

    /// Trip slug
    required String tripSlug,

    /// Trip name
    required String tripName,

    /// Stage name
    required String stageName,

    /// Slug of the route to load: the stage's own route, never the trip's (a stage without a route is left out)
    required String routeSlug,

    /// Route name
    required String routeName,

    /// Distance in meters
    required double distance,

    /// Elevation gain in meters
    required double elevationGain,

    /// When the stage leaves, as an absolute instant (UTC)
    required String startDateTime,

    /// IANA time zone of the stage (e.g. Europe/Paris)
    required String timezone,

    /// Where the route stands at each of the user's GPS services that hold it, as DeviceRegisteredGroupDto.syncStatuses
    required List<DeviceRouteSyncStatusDto> syncStatuses,

    /// Team name
    required String teamName,

    /// Status of the trip: PUBLISHED or CANCELLED (the stages of a cancelled trip are listed, for the device to say so)
    required String status,

    /// When the stage is expected to end, as an absolute instant (UTC): its stored end, the departure plus three hours without one
    required String endDateTime,

    /// Name of the place the stage leaves from, when it has one
    String? startPlaceName,

    /// Name of the place the stage ends at, when it has one
    String? endPlaceName,
  }) = _DeviceRegisteredStageDto;

  factory DeviceRegisteredStageDto.fromJson(Map<String, Object?> json) =>
      _$DeviceRegisteredStageDtoFromJson(json);
}
