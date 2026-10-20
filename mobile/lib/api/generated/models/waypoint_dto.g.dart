// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waypoint_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WaypointDto _$WaypointDtoFromJson(Map<String, dynamic> json) => _WaypointDto(
  geometry: GeoJsonPoint.fromJson(json['geometry'] as Map<String, dynamic>),
  name: json['name'] as String,
  type: json['type'] as String,
  origin: json['origin'] as String,
  id: json['id'] as String?,
  description: json['description'] as String?,
  distance: (json['distance'] as num?)?.toDouble(),
);

Map<String, dynamic> _$WaypointDtoToJson(_WaypointDto instance) =>
    <String, dynamic>{
      'geometry': instance.geometry.toJson(),
      'name': instance.name,
      'type': instance.type,
      'origin': instance.origin,
      'id': instance.id,
      'description': instance.description,
      'distance': instance.distance,
    };
