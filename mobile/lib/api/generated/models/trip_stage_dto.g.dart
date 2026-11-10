// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_stage_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TripStageDto _$TripStageDtoFromJson(Map<String, dynamic> json) =>
    _TripStageDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      dateTime: json['dateTime'] as String,
      timezone: json['timezone'] as String,
      media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
      sortOrder: (json['sortOrder'] as num).toInt(),
      stageIndex: (json['stageIndex'] as num).toInt(),
      stageCount: (json['stageCount'] as num).toInt(),
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      route: json['route'] == null
          ? null
          : RouteDto.fromJson(json['route'] as Map<String, dynamic>),
      startPlace: json['startPlace'] == null
          ? null
          : PlaceDetailDto.fromJson(json['startPlace'] as Map<String, dynamic>),
      endPlace: json['endPlace'] == null
          ? null
          : PlaceDetailDto.fromJson(json['endPlace'] as Map<String, dynamic>),
      commentCount: (json['commentCount'] as num?)?.toInt(),
      estimatedArrival: json['estimatedArrival'] as String?,
      estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num?)
          ?.toInt(),
    );

Map<String, dynamic> _$TripStageDtoToJson(_TripStageDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'dateTime': instance.dateTime,
      'timezone': instance.timezone,
      'media': instance.media.toJson(),
      'sortOrder': instance.sortOrder,
      'stageIndex': instance.stageIndex,
      'stageCount': instance.stageCount,
      'averageSpeed': instance.averageSpeed,
      'route': instance.route?.toJson(),
      'startPlace': instance.startPlace?.toJson(),
      'endPlace': instance.endPlace?.toJson(),
      'commentCount': instance.commentCount,
      'estimatedArrival': instance.estimatedArrival,
      'estimatedDurationMinutes': instance.estimatedDurationMinutes,
    };
