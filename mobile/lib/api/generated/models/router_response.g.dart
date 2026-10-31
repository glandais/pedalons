// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouterResponse _$RouterResponseFromJson(Map<String, dynamic> json) =>
    _RouterResponse(
      route: GeoJsonLineString.fromJson(json['route'] as Map<String, dynamic>),
      dist: (json['dist'] as num?)?.toDouble(),
      ascend: (json['ascend'] as num?)?.toDouble(),
      unpaved: (json['unpaved'] as List<dynamic>?)
          ?.map((e) => UnpavedSpan.fromJson(e as Map<String, dynamic>))
          .toList(),
      shape: json['shape'] as String?,
    );

Map<String, dynamic> _$RouterResponseToJson(_RouterResponse instance) =>
    <String, dynamic>{
      'route': instance.route.toJson(),
      'dist': instance.dist,
      'ascend': instance.ascend,
      'unpaved': instance.unpaved?.map((e) => e.toJson()).toList(),
      'shape': instance.shape,
    };
