// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteRequest _$RouteRequestFromJson(Map<String, dynamic> json) =>
    _RouteRequest(
      name: json['name'] as String,
      media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
      surfaceType: json['surfaceType'] as String,
      visibility: json['visibility'] as String,
      points: (json['points'] as List<dynamic>?)
          ?.map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      tagIds: (json['tagIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      plannerState: json['plannerState'] == null
          ? null
          : PlannerState.fromJson(json['plannerState'] as Map<String, dynamic>),
      waypoints: (json['waypoints'] as List<dynamic>?)
          ?.map((e) => WaypointRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RouteRequestToJson(_RouteRequest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'media': instance.media.toJson(),
      'surfaceType': instance.surfaceType,
      'visibility': instance.visibility,
      'points': instance.points?.map((e) => e.toJson()).toList(),
      'tagIds': instance.tagIds,
      'plannerState': instance.plannerState?.toJson(),
      'waypoints': instance.waypoints?.map((e) => e.toJson()).toList(),
    };
