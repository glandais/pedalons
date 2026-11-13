// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'structure.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Structure _$StructureFromJson(Map<String, dynamic> json) => _Structure(
  kind: json['kind'] as String?,
  fromM: (json['from_m'] as num?)?.toDouble(),
  toM: (json['to_m'] as num?)?.toDouble(),
  lengthM: (json['length_m'] as num?)?.toDouble(),
  structureSource: json['structure_source'] as String?,
  method: json['method'] as String?,
);

Map<String, dynamic> _$StructureToJson(_Structure instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'from_m': instance.fromM,
      'to_m': instance.toM,
      'length_m': instance.lengthM,
      'structure_source': instance.structureSource,
      'method': instance.method,
    };
