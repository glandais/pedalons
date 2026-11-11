// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TripDto _$TripDtoFromJson(Map<String, dynamic> json) => _TripDto(
  type: json['type'] as String,
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
  participantCount: (json['participantCount'] as num).toInt(),
  stageCount: (json['stageCount'] as num).toInt(),
  stages: (json['stages'] as List<dynamic>)
      .map((e) => TripStageDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  participants: (json['participants'] as List<dynamic>)
      .map((e) => PublicUserDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  deleted: json['deleted'] as bool,
  registered: json['registered'] as bool,
  tags: (json['tags'] as List<dynamic>)
      .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  permissions: ContentPermissionsDto.fromJson(
    json['permissions'] as Map<String, dynamic>,
  ),
  excerpt: json['excerpt'] as String?,
  endDate: json['endDate'] as String?,
  publishAt: json['publishAt'] as String?,
  createdAt: json['createdAt'] as String?,
  routeSlug: json['routeSlug'] as String?,
  totalDistance: (json['totalDistance'] as num?)?.toDouble(),
  totalElevationGain: (json['totalElevationGain'] as num?)?.toDouble(),
  thumbnailLightUrl: json['thumbnailLightUrl'] as String?,
  thumbnailDarkUrl: json['thumbnailDarkUrl'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  commentCount: (json['commentCount'] as num?)?.toInt(),
  weather: json['weather'] == null
      ? null
      : RideWeatherSummaryDto.fromJson(json['weather'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TripDtoToJson(_TripDto instance) => <String, dynamic>{
  'type': instance.type,
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
  'participantCount': instance.participantCount,
  'stageCount': instance.stageCount,
  'stages': instance.stages.map((e) => e.toJson()).toList(),
  'participants': instance.participants.map((e) => e.toJson()).toList(),
  'deleted': instance.deleted,
  'registered': instance.registered,
  'tags': instance.tags.map((e) => e.toJson()).toList(),
  'permissions': instance.permissions.toJson(),
  'excerpt': instance.excerpt,
  'endDate': instance.endDate,
  'publishAt': instance.publishAt,
  'createdAt': instance.createdAt,
  'routeSlug': instance.routeSlug,
  'totalDistance': instance.totalDistance,
  'totalElevationGain': instance.totalElevationGain,
  'thumbnailLightUrl': instance.thumbnailLightUrl,
  'thumbnailDarkUrl': instance.thumbnailDarkUrl,
  'thumbnailUrl': instance.thumbnailUrl,
  'commentCount': instance.commentCount,
  'weather': instance.weather?.toJson(),
};
