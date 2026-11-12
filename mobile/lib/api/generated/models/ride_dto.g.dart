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
  groupSummaries: (json['groupSummaries'] as List<dynamic>)
      .map((e) => RideGroupSummaryDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  full: json['full'] as bool,
  registered: json['registered'] as bool,
  tags: (json['tags'] as List<dynamic>)
      .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  deleted: json['deleted'] as bool,
  permissions: ContentPermissionsDto.fromJson(
    json['permissions'] as Map<String, dynamic>,
  ),
  surfaceType: json['surfaceType'] as String?,
  displayDistance: (json['displayDistance'] as num?)?.toDouble(),
  displayElevationGain: (json['displayElevationGain'] as num?)?.toDouble(),
  startPlace: json['startPlace'] == null
      ? null
      : PlaceDetailDto.fromJson(json['startPlace'] as Map<String, dynamic>),
  endPlace: json['endPlace'] == null
      ? null
      : PlaceDetailDto.fromJson(json['endPlace'] as Map<String, dynamic>),
  elevationGain: (json['elevationGain'] as num?)?.toDouble(),
  thumbnailLightUrl: json['thumbnailLightUrl'] as String?,
  thumbnailDarkUrl: json['thumbnailDarkUrl'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  publishAt: json['publishAt'] as String?,
  routeSlug: json['routeSlug'] as String?,
  registeredGroupId: json['registeredGroupId'] as String?,
  registeredGroup: json['registeredGroup'] == null
      ? null
      : RideGroupDto.fromJson(json['registeredGroup'] as Map<String, dynamic>),
  createdAt: json['createdAt'] as String?,
  maxParticipants: (json['maxParticipants'] as num?)?.toInt(),
  commentCount: (json['commentCount'] as num?)?.toInt(),
  excerpt: json['excerpt'] as String?,
  weather: json['weather'] == null
      ? null
      : RideWeatherSummaryDto.fromJson(json['weather'] as Map<String, dynamic>),
  gpsSyncStatuses: (json['gpsSyncStatuses'] as List<dynamic>?)
      ?.map((e) => RouteGpsSyncStatusDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  distance: (json['distance'] as num?)?.toDouble(),
);

Map<String, dynamic> _$RideDtoToJson(_RideDto instance) => <String, dynamic>{
  'topParticipants': instance.topParticipants.map((e) => e.toJson()).toList(),
  'team': instance.team.toJson(),
  'id': instance.id,
  'slug': instance.slug,
  'name': instance.name,
  'media': instance.media.toJson(),
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
  'groupSummaries': instance.groupSummaries.map((e) => e.toJson()).toList(),
  'full': instance.full,
  'registered': instance.registered,
  'tags': instance.tags.map((e) => e.toJson()).toList(),
  'deleted': instance.deleted,
  'permissions': instance.permissions.toJson(),
  'surfaceType': instance.surfaceType,
  'displayDistance': instance.displayDistance,
  'displayElevationGain': instance.displayElevationGain,
  'startPlace': instance.startPlace?.toJson(),
  'endPlace': instance.endPlace?.toJson(),
  'elevationGain': instance.elevationGain,
  'thumbnailLightUrl': instance.thumbnailLightUrl,
  'thumbnailDarkUrl': instance.thumbnailDarkUrl,
  'thumbnailUrl': instance.thumbnailUrl,
  'publishAt': instance.publishAt,
  'routeSlug': instance.routeSlug,
  'registeredGroupId': instance.registeredGroupId,
  'registeredGroup': instance.registeredGroup?.toJson(),
  'createdAt': instance.createdAt,
  'maxParticipants': instance.maxParticipants,
  'commentCount': instance.commentCount,
  'excerpt': instance.excerpt,
  'weather': instance.weather?.toJson(),
  'gpsSyncStatuses': instance.gpsSyncStatuses?.map((e) => e.toJson()).toList(),
  'distance': instance.distance,
};
