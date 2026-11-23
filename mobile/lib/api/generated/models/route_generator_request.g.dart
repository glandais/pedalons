// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_generator_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteGeneratorRequest _$RouteGeneratorRequestFromJson(
  Map<String, dynamic> json,
) => _RouteGeneratorRequest(
  distanceKm: (json['distanceKm'] as num).toDouble(),
  start: json['start'] == null
      ? null
      : GeoPoint.fromJson(json['start'] as Map<String, dynamic>),
  end: json['end'] == null
      ? null
      : GeoPoint.fromJson(json['end'] as Map<String, dynamic>),
  bearing: json['bearing'] as String?,
  discovery: (json['discovery'] as num?)?.toDouble(),
  type: json['type'] as String?,
  seed: (json['seed'] as num?)?.toInt(),
  unpaved: json['unpaved'] as String?,
);

Map<String, dynamic> _$RouteGeneratorRequestToJson(
  _RouteGeneratorRequest instance,
) => <String, dynamic>{
  'distanceKm': instance.distanceKm,
  'start': instance.start?.toJson(),
  'end': instance.end?.toJson(),
  'bearing': instance.bearing,
  'discovery': instance.discovery,
  'type': instance.type,
  'seed': instance.seed,
  'unpaved': instance.unpaved,
};
