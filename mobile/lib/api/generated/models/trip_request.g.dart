// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TripRequest _$TripRequestFromJson(Map<String, dynamic> json) => _TripRequest(
  name: json['name'] as String,
  media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
  dateTime: json['dateTime'] as String,
  status: json['status'] as String,
  visibility: json['visibility'] as String,
  stages: (json['stages'] as List<dynamic>)
      .map((e) => StageRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
  routeSlug: json['routeSlug'] as String?,
  publishAt: json['publishAt'] as String?,
  tagIds: (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
  alignVisibility: json['alignVisibility'] as bool?,
);

Map<String, dynamic> _$TripRequestToJson(_TripRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'media': instance.media.toJson(),
      'dateTime': instance.dateTime,
      'status': instance.status,
      'visibility': instance.visibility,
      'stages': instance.stages.map((e) => e.toJson()).toList(),
      'routeSlug': instance.routeSlug,
      'publishAt': instance.publishAt,
      'tagIds': instance.tagIds,
      'alignVisibility': instance.alignVisibility,
    };
