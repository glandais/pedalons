// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideRequest _$RideRequestFromJson(Map<String, dynamic> json) => _RideRequest(
  name: json['name'] as String,
  media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
  dateTime: json['dateTime'] as String,
  status: json['status'] as String,
  visibility: json['visibility'] as String,
  groups: (json['groups'] as List<dynamic>)
      .map((e) => GroupRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
  routeSlug: json['routeSlug'] as String?,
  startPlaceId: json['startPlaceId'] as String?,
  endPlaceId: json['endPlaceId'] as String?,
  publishAt: json['publishAt'] as String?,
  tagIds: (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
  templateId: json['templateId'] as String?,
);

Map<String, dynamic> _$RideRequestToJson(_RideRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'media': instance.media.toJson(),
      'dateTime': instance.dateTime,
      'status': instance.status,
      'visibility': instance.visibility,
      'groups': instance.groups.map((e) => e.toJson()).toList(),
      'routeSlug': instance.routeSlug,
      'startPlaceId': instance.startPlaceId,
      'endPlaceId': instance.endPlaceId,
      'publishAt': instance.publishAt,
      'tagIds': instance.tagIds,
      'templateId': instance.templateId,
    };
