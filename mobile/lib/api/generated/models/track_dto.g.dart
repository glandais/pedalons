// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrackDto _$TrackDtoFromJson(Map<String, dynamic> json) => _TrackDto(
  line: GeoJsonLineString.fromJson(json['line'] as Map<String, dynamic>),
  climbs: (json['climbs'] as List<dynamic>)
      .map((e) => ClimbDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  surfaceState: json['surfaceState'] as String?,
  surfaces: (json['surfaces'] as List<dynamic>?)
      ?.map((e) => SurfaceSpanDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TrackDtoToJson(_TrackDto instance) => <String, dynamic>{
  'line': instance.line.toJson(),
  'climbs': instance.climbs.map((e) => e.toJson()).toList(),
  'surfaceState': instance.surfaceState,
  'surfaces': instance.surfaces?.map((e) => e.toJson()).toList(),
};
