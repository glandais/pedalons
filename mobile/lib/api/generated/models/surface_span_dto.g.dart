// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'surface_span_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SurfaceSpanDto _$SurfaceSpanDtoFromJson(Map<String, dynamic> json) =>
    _SurfaceSpanDto(
      from: (json['from'] as num).toDouble(),
      to: (json['to'] as num).toDouble(),
      surface: TrackSurface.fromJson(json['surface'] as String),
    );

Map<String, dynamic> _$SurfaceSpanDtoToJson(_SurfaceSpanDto instance) =>
    <String, dynamic>{
      'from': instance.from,
      'to': instance.to,
      'surface': instance.surface.toJson(),
    };
