// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_registered_stage_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceRegisteredStageDto _$DeviceRegisteredStageDtoFromJson(
  Map<String, dynamic> json,
) => _DeviceRegisteredStageDto(
  teamSlug: json['teamSlug'] as String,
  tripSlug: json['tripSlug'] as String,
  tripName: json['tripName'] as String,
  stageName: json['stageName'] as String,
  routeSlug: json['routeSlug'] as String,
  routeName: json['routeName'] as String,
  distance: (json['distance'] as num).toDouble(),
  elevationGain: (json['elevationGain'] as num).toDouble(),
  startDateTime: json['startDateTime'] as String,
  timezone: json['timezone'] as String,
  syncStatuses: (json['syncStatuses'] as List<dynamic>)
      .map((e) => DeviceRouteSyncStatusDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  startPlaceName: json['startPlaceName'] as String?,
  endPlaceName: json['endPlaceName'] as String?,
);

Map<String, dynamic> _$DeviceRegisteredStageDtoToJson(
  _DeviceRegisteredStageDto instance,
) => <String, dynamic>{
  'teamSlug': instance.teamSlug,
  'tripSlug': instance.tripSlug,
  'tripName': instance.tripName,
  'stageName': instance.stageName,
  'routeSlug': instance.routeSlug,
  'routeName': instance.routeName,
  'distance': instance.distance,
  'elevationGain': instance.elevationGain,
  'startDateTime': instance.startDateTime,
  'timezone': instance.timezone,
  'syncStatuses': instance.syncStatuses.map((e) => e.toJson()).toList(),
  'startPlaceName': instance.startPlaceName,
  'endPlaceName': instance.endPlaceName,
};
