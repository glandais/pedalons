// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_retouch_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteRetouchRequest _$RouteRetouchRequestFromJson(Map<String, dynamic> json) =>
    _RouteRetouchRequest(
      targetDistanceKm: (json['targetDistanceKm'] as num?)?.toDouble(),
      end: json['end'] == null
          ? null
          : RouteRetouchEnd.fromJson(json['end'] as Map<String, dynamic>),
      discovery: (json['discovery'] as num?)?.toDouble(),
      seed: (json['seed'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RouteRetouchRequestToJson(
  _RouteRetouchRequest instance,
) => <String, dynamic>{
  'targetDistanceKm': instance.targetDistanceKm,
  'end': instance.end?.toJson(),
  'discovery': instance.discovery,
  'seed': instance.seed,
};
