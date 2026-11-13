// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'output_point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OutputPoint _$OutputPointFromJson(Map<String, dynamic> json) => _OutputPoint(
  dM: (json['d_m'] as num?)?.toDouble(),
  indexField: (json['index'] as num?)?.toInt(),
  origin: json['origin'] as String?,
  reasons: (json['reasons'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  lat: (json['lat'] as num?)?.toDouble(),
  lon: (json['lon'] as num?)?.toDouble(),
  ele: (json['ele'] as num?)?.toDouble(),
  eleSmoothed: (json['ele_smoothed'] as num?)?.toDouble(),
  eleMethod: json['ele_method'] as String?,
  gainCumM: (json['gain_cum_m'] as num?)?.toDouble(),
  lossCumM: (json['loss_cum_m'] as num?)?.toDouble(),
  inserted: json['inserted'] as bool?,
);

Map<String, dynamic> _$OutputPointToJson(_OutputPoint instance) =>
    <String, dynamic>{
      'd_m': instance.dM,
      'index': instance.indexField,
      'origin': instance.origin,
      'reasons': instance.reasons,
      'lat': instance.lat,
      'lon': instance.lon,
      'ele': instance.ele,
      'ele_smoothed': instance.eleSmoothed,
      'ele_method': instance.eleMethod,
      'gain_cum_m': instance.gainCumM,
      'loss_cum_m': instance.lossCumM,
      'inserted': instance.inserted,
    };
