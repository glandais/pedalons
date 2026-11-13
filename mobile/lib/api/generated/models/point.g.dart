// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Point _$PointFromJson(Map<String, dynamic> json) => _Point(
  lat: (json['lat'] as num?)?.toDouble(),
  lon: (json['lon'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PointToJson(_Point instance) => <String, dynamic>{
  'lat': instance.lat,
  'lon': instance.lon,
};
