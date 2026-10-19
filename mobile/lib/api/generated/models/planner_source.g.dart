// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannerSource _$PlannerSourceFromJson(Map<String, dynamic> json) =>
    _PlannerSource(
      line: json['line'] as String,
      ascendScale: (json['ascendScale'] as num).toDouble(),
      ele: json['ele'] as String?,
      climb: json['climb'] as String?,
    );

Map<String, dynamic> _$PlannerSourceToJson(_PlannerSource instance) =>
    <String, dynamic>{
      'line': instance.line,
      'ascendScale': instance.ascendScale,
      'ele': instance.ele,
      'climb': instance.climb,
    };
