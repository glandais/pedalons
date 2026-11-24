// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_retouch_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteRetouchResponse _$RouteRetouchResponseFromJson(
  Map<String, dynamic> json,
) => _RouteRetouchResponse(
  operation: json['operation'] as String,
  originalDistanceM: (json['originalDistanceM'] as num).toDouble(),
  candidates: (json['candidates'] as List<dynamic>)
      .map((e) => RetouchedRouteDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  originalAscentM: (json['originalAscentM'] as num?)?.toDouble(),
  originalDescentM: (json['originalDescentM'] as num?)?.toDouble(),
  targetDistanceM: (json['targetDistanceM'] as num?)?.toDouble(),
  networkPreparedAt: json['networkPreparedAt'] as String?,
);

Map<String, dynamic> _$RouteRetouchResponseToJson(
  _RouteRetouchResponse instance,
) => <String, dynamic>{
  'operation': instance.operation,
  'originalDistanceM': instance.originalDistanceM,
  'candidates': instance.candidates.map((e) => e.toJson()).toList(),
  'originalAscentM': instance.originalAscentM,
  'originalDescentM': instance.originalDescentM,
  'targetDistanceM': instance.targetDistanceM,
  'networkPreparedAt': instance.networkPreparedAt,
};
