// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_piece.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannerPiece _$PlannerPieceFromJson(Map<String, dynamic> json) =>
    _PlannerPiece(
      mode: PlannerPieceMode.fromJson(json['mode'] as String),
      line: json['line'] as String?,
      ele: json['ele'] as String?,
      ascend: (json['ascend'] as num?)?.toDouble(),
      source: (json['source'] as num?)?.toInt(),
      from: (json['from'] as num?)?.toInt(),
      to: (json['to'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PlannerPieceToJson(_PlannerPiece instance) =>
    <String, dynamic>{
      'mode': instance.mode.toJson(),
      'line': instance.line,
      'ele': instance.ele,
      'ascend': instance.ascend,
      'source': instance.source,
      'from': instance.from,
      'to': instance.to,
    };
