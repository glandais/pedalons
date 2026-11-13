// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'segment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Segment _$SegmentFromJson(Map<String, dynamic> json) => _Segment(
  fromM: (json['from_m'] as num?)?.toDouble(),
  toM: (json['to_m'] as num?)?.toDouble(),
  fromIndex: (json['from_index'] as num?)?.toInt(),
  toIndex: (json['to_index'] as num?)?.toInt(),
  structure: json['structure'] as String?,
  structureSource: json['structure_source'] as String?,
  surface: json['surface'] == null
      ? null
      : Surface.fromJson(json['surface'] as Map<String, dynamic>),
  wayKind: json['way_kind'] as String?,
  matched: json['matched'] as bool?,
);

Map<String, dynamic> _$SegmentToJson(_Segment instance) => <String, dynamic>{
  'from_m': instance.fromM,
  'to_m': instance.toM,
  'from_index': instance.fromIndex,
  'to_index': instance.toIndex,
  'structure': instance.structure,
  'structure_source': instance.structureSource,
  'surface': instance.surface?.toJson(),
  'way_kind': instance.wayKind,
  'matched': instance.matched,
};
