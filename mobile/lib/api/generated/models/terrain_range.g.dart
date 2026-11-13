// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terrain_range.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TerrainRange _$TerrainRangeFromJson(Map<String, dynamic> json) =>
    _TerrainRange(
      fromM: (json['from_m'] as num?)?.toDouble(),
      toM: (json['to_m'] as num?)?.toDouble(),
      origin: json['origin'] as String?,
      measured: json['measured'] as bool?,
      fallbackAfterError: json['fallback_after_error'] as bool?,
    );

Map<String, dynamic> _$TerrainRangeToJson(_TerrainRange instance) =>
    <String, dynamic>{
      'from_m': instance.fromM,
      'to_m': instance.toM,
      'origin': instance.origin,
      'measured': instance.measured,
      'fallback_after_error': instance.fallbackAfterError,
    };
