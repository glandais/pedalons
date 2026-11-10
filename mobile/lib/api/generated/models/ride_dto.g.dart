// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideDto _$RideDtoFromJson(Map<String, dynamic> json) => _RideDto(
  topParticipants: (json['topParticipants'] as List<dynamic>)
      .map((e) => PublicUserDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  team: TeamPublicationDto.fromJson(json['team'] as Map<String, dynamic>),
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
  groupSummaries: (json['groupSummaries'] as List<dynamic>)
      .map((e) => RideGroupSummaryDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  dateTime: json['dateTime'] as String,
  timezone: json['timezone'] as String,
  endDateTime: json['endDateTime'] as String,
  status: json['status'] as String,
  finished: json['finished'] as bool,
  visibility: json['visibility'] as String,
  type: json['type'] as String,
  participantCount: (json['participantCount'] as num).toInt(),
  groupCount: (json['groupCount'] as num).toInt(),
  groups: (json['groups'] as List<dynamic>)
      .map((e) => RideGroupDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  full: json['full'] as bool,
  tags: (json['tags'] as List<dynamic>)
      .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  registered: json['registered'] as bool,
  deleted: json['deleted'] as bool,
  elevationGain: (json['elevationGain'] as num?)?.toDouble(),
  surfaceType: json['surfaceType'] as String?,
  startPlace: json['startPlace'] == null
      ? null
      : PlaceDetailDto.fromJson(json['startPlace'] as Map<String, dynamic>),
  endPlace: json['endPlace'] == null
      ? null
      : PlaceDetailDto.fromJson(json['endPlace'] as Map<String, dynamic>),
  gpsSyncStatuses: (json['gpsSyncStatuses'] as List<dynamic>?)
      ?.map((e) => RouteGpsSyncStatusDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  thumbnailLightUrl: json['thumbnailLightUrl'] as String?,
  thumbnailDarkUrl: json['thumbnailDarkUrl'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  distance: (json['distance'] as num?)?.toDouble(),
  publishAt: json['publishAt'] as String?,
  registeredGroupId: json['registeredGroupId'] as String?,
  registeredGroup: json['registeredGroup'] == null
      ? null
      : RideGroupDto.fromJson(json['registeredGroup'] as Map<String, dynamic>),
  routeSlug: json['routeSlug'] as String?,
  maxParticipants: (json['maxParticipants'] as num?)?.toInt(),
  commentCount: (json['commentCount'] as num?)?.toInt(),
  createdAt: json['createdAt'] as String?,
  weather: json['weather'] == null
      ? null
      : RideWeatherSummaryDto.fromJson(json['weather'] as Map<String, dynamic>),
  excerpt: json['excerpt'] as String?,
);

Map<String, dynamic> _$RideDtoToJson(_RideDto instance) => <String, dynamic>{
  'topParticipants': instance.topParticipants.map((e) => e.toJson()).toList(),
  'team': instance.team.toJson(),
  'id': instance.id,
  'slug': instance.slug,
  'name': instance.name,
  'media': instance.media.toJson(),
  'groupSummaries': instance.groupSummaries.map((e) => e.toJson()).toList(),
  'dateTime': instance.dateTime,
  'timezone': instance.timezone,
  'endDateTime': instance.endDateTime,
  'status': instance.status,
  'finished': instance.finished,
  'visibility': instance.visibility,
  'type': instance.type,
  'participantCount': instance.participantCount,
  'groupCount': instance.groupCount,
  'groups': instance.groups.map((e) => e.toJson()).toList(),
  'full': instance.full,
  'tags': instance.tags.map((e) => e.toJson()).toList(),
  'registered': instance.registered,
  'deleted': instance.deleted,
  'elevationGain': instance.elevationGain,
  'surfaceType': instance.surfaceType,
  'startPlace': instance.startPlace?.toJson(),
  'endPlace': instance.endPlace?.toJson(),
  'gpsSyncStatuses': instance.gpsSyncStatuses?.map((e) => e.toJson()).toList(),
  'thumbnailLightUrl': instance.thumbnailLightUrl,
  'thumbnailDarkUrl': instance.thumbnailDarkUrl,
  'thumbnailUrl': instance.thumbnailUrl,
  'distance': instance.distance,
  'publishAt': instance.publishAt,
  'registeredGroupId': instance.registeredGroupId,
  'registeredGroup': instance.registeredGroup?.toJson(),
  'routeSlug': instance.routeSlug,
  'maxParticipants': instance.maxParticipants,
  'commentCount': instance.commentCount,
  'createdAt': instance.createdAt,
  'weather': instance.weather?.toJson(),
  'excerpt': instance.excerpt,
};
