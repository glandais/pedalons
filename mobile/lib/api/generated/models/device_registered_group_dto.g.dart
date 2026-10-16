// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_registered_group_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceRegisteredGroupDto _$DeviceRegisteredGroupDtoFromJson(
  Map<String, dynamic> json,
) => _DeviceRegisteredGroupDto(
  teamSlug: json['teamSlug'] as String,
  rideSlug: json['rideSlug'] as String,
  rideName: json['rideName'] as String,
  groupName: json['groupName'] as String,
  routeSlug: json['routeSlug'] as String,
  routeName: json['routeName'] as String,
  distance: (json['distance'] as num).toDouble(),
  elevationGain: (json['elevationGain'] as num).toDouble(),
  startDateTime: json['startDateTime'] as String,
  timezone: json['timezone'] as String,
  syncStatuses: (json['syncStatuses'] as List<dynamic>?)
      ?.map((e) => DeviceRouteSyncStatusDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DeviceRegisteredGroupDtoToJson(
  _DeviceRegisteredGroupDto instance,
) => <String, dynamic>{
  'teamSlug': instance.teamSlug,
  'rideSlug': instance.rideSlug,
  'rideName': instance.rideName,
  'groupName': instance.groupName,
  'routeSlug': instance.routeSlug,
  'routeName': instance.routeName,
  'distance': instance.distance,
  'elevationGain': instance.elevationGain,
  'startDateTime': instance.startDateTime,
  'timezone': instance.timezone,
  'syncStatuses': instance.syncStatuses?.map((e) => e.toJson()).toList(),
};
