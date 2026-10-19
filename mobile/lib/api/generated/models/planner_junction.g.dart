// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_junction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannerJunction _$PlannerJunctionFromJson(Map<String, dynamic> json) =>
    _PlannerJunction(
      kind: PlannerJunctionKind.fromJson(json['kind'] as String),
      lng: (json['lng'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      ele: (json['ele'] as num?)?.toDouble(),
      source: (json['source'] as num?)?.toInt(),
      idx: (json['idx'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PlannerJunctionToJson(_PlannerJunction instance) =>
    <String, dynamic>{
      'kind': instance.kind.toJson(),
      'lng': instance.lng,
      'lat': instance.lat,
      'ele': instance.ele,
      'source': instance.source,
      'idx': instance.idx,
    };
