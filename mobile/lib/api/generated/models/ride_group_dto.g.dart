// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_group_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideGroupDto _$RideGroupDtoFromJson(
  Map<String, dynamic> json,
) => _RideGroupDto(
  id: json['id'] as String,
  name: json['name'] as String,
  startAt: json['startAt'] as String,
  countParticipants: (json['countParticipants'] as num).toInt(),
  participants: (json['participants'] as List<dynamic>)
      .map((e) => PublicUserDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  sortOrder: (json['sortOrder'] as num).toInt(),
  registered: json['registered'] as bool,
  full: json['full'] as bool,
  time: json['time'] as String?,
  routeSlug: json['routeSlug'] as String?,
  averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
  maxParticipants: (json['maxParticipants'] as num?)?.toInt(),
  distance: (json['distance'] as num?)?.toDouble(),
  elevationGain: (json['elevationGain'] as num?)?.toDouble(),
  leader: json['leader'] == null
      ? null
      : PublicUserDto.fromJson(json['leader'] as Map<String, dynamic>),
  thumbnailLightUrl: json['thumbnailLightUrl'] as String?,
  thumbnailDarkUrl: json['thumbnailDarkUrl'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  gpsSyncStatuses: (json['gpsSyncStatuses'] as List<dynamic>?)
      ?.map((e) => RouteGpsSyncStatusDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  estimatedArrival: json['estimatedArrival'] as String?,
  estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num?)?.toInt(),
);

Map<String, dynamic> _$RideGroupDtoToJson(
  _RideGroupDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'startAt': instance.startAt,
  'countParticipants': instance.countParticipants,
  'participants': instance.participants.map((e) => e.toJson()).toList(),
  'sortOrder': instance.sortOrder,
  'registered': instance.registered,
  'full': instance.full,
  'time': instance.time,
  'routeSlug': instance.routeSlug,
  'averageSpeed': instance.averageSpeed,
  'maxParticipants': instance.maxParticipants,
  'distance': instance.distance,
  'elevationGain': instance.elevationGain,
  'leader': instance.leader?.toJson(),
  'thumbnailLightUrl': instance.thumbnailLightUrl,
  'thumbnailDarkUrl': instance.thumbnailDarkUrl,
  'thumbnailUrl': instance.thumbnailUrl,
  'gpsSyncStatuses': instance.gpsSyncStatuses?.map((e) => e.toJson()).toList(),
  'estimatedArrival': instance.estimatedArrival,
  'estimatedDurationMinutes': instance.estimatedDurationMinutes,
};
