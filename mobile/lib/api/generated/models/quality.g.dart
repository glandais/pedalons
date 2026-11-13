// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quality.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Quality _$QualityFromJson(Map<String, dynamic> json) => _Quality(
  terrain: (json['terrain'] as List<dynamic>?)
      ?.map((e) => TerrainRange.fromJson(e as Map<String, dynamic>))
      .toList(),
  warnings: (json['warnings'] as List<dynamic>?)
      ?.map((e) => Warning.fromJson(e as Map<String, dynamic>))
      .toList(),
  structureCorrection: json['structure_correction'] == null
      ? null
      : JsonNode.fromJson(json['structure_correction'] as Map<String, dynamic>),
);

Map<String, dynamic> _$QualityToJson(_Quality instance) => <String, dynamic>{
  'terrain': instance.terrain?.map((e) => e.toJson()).toList(),
  'warnings': instance.warnings?.map((e) => e.toJson()).toList(),
  'structure_correction': instance.structureCorrection?.toJson(),
};
