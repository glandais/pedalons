// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Summary _$SummaryFromJson(Map<String, dynamic> json) => _Summary(
  lengthM: (json['length_m'] as num?)?.toDouble(),
  gainM: (json['gain_m'] as num?)?.toDouble(),
  lossM: (json['loss_m'] as num?)?.toDouble(),
  eleMinM: (json['ele_min_m'] as num?)?.toDouble(),
  eleMaxM: (json['ele_max_m'] as num?)?.toDouble(),
  structures: (json['structures'] as List<dynamic>?)
      ?.map((e) => Structure.fromJson(e as Map<String, dynamic>))
      .toList(),
  terrainM: (json['terrain_m'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
);

Map<String, dynamic> _$SummaryToJson(_Summary instance) => <String, dynamic>{
  'length_m': instance.lengthM,
  'gain_m': instance.gainM,
  'loss_m': instance.lossM,
  'ele_min_m': instance.eleMinM,
  'ele_max_m': instance.eleMaxM,
  'structures': instance.structures?.map((e) => e.toJson()).toList(),
  'terrain_m': instance.terrainM,
};
