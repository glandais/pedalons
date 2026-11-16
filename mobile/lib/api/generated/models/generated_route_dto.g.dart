// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generated_route_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GeneratedRouteDto _$GeneratedRouteDtoFromJson(Map<String, dynamic> json) =>
    _GeneratedRouteDto(
      polyline: json['polyline'] as String,
      distanceM: (json['distanceM'] as num).toDouble(),
      teamShare: (json['teamShare'] as num).toDouble(),
      unpavedShare: (json['unpavedShare'] as num).toDouble(),
      sharedM: (json['sharedM'] as num).toDouble(),
      crossings: (json['crossings'] as num).toInt(),
      bounds: BoundsDto.fromJson(json['bounds'] as Map<String, dynamic>),
      ascentM: (json['ascentM'] as num?)?.toDouble(),
      descentM: (json['descentM'] as num?)?.toDouble(),
      bearingDeviationDeg: (json['bearingDeviationDeg'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$GeneratedRouteDtoToJson(_GeneratedRouteDto instance) =>
    <String, dynamic>{
      'polyline': instance.polyline,
      'distanceM': instance.distanceM,
      'teamShare': instance.teamShare,
      'unpavedShare': instance.unpavedShare,
      'sharedM': instance.sharedM,
      'crossings': instance.crossings,
      'bounds': instance.bounds.toJson(),
      'ascentM': instance.ascentM,
      'descentM': instance.descentM,
      'bearingDeviationDeg': instance.bearingDeviationDeg,
    };
