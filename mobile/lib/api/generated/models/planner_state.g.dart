// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannerState _$PlannerStateFromJson(Map<String, dynamic> json) =>
    _PlannerState(
      version: (json['version'] as num).toInt(),
      profile: RouterProfile.fromJson(json['profile'] as String),
      sources: (json['sources'] as List<dynamic>)
          .map((e) => PlannerSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      junctions: (json['junctions'] as List<dynamic>)
          .map((e) => PlannerJunction.fromJson(e as Map<String, dynamic>))
          .toList(),
      pieces: (json['pieces'] as List<dynamic>)
          .map((e) => PlannerPiece.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PlannerStateToJson(_PlannerState instance) =>
    <String, dynamic>{
      'version': instance.version,
      'profile': instance.profile.toJson(),
      'sources': instance.sources.map((e) => e.toJson()).toList(),
      'junctions': instance.junctions.map((e) => e.toJson()).toList(),
      'pieces': instance.pieces.map((e) => e.toJson()).toList(),
    };
