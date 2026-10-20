// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waypoint_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WaypointRequest _$WaypointRequestFromJson(Map<String, dynamic> json) =>
    _WaypointRequest(
      position: GeoPoint.fromJson(json['position'] as Map<String, dynamic>),
      type: json['type'] as String,
      name: json['name'] as String,
      id: json['id'] as String?,
      description: json['description'] as String?,
      distance: (json['distance'] as num?)?.toDouble(),
      origin: json['origin'] as String?,
    );

Map<String, dynamic> _$WaypointRequestToJson(_WaypointRequest instance) =>
    <String, dynamic>{
      'position': instance.position.toJson(),
      'type': instance.type,
      'name': instance.name,
      'id': instance.id,
      'description': instance.description,
      'distance': instance.distance,
      'origin': instance.origin,
    };
