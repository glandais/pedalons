// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_generator_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteGeneratorResponse _$RouteGeneratorResponseFromJson(
  Map<String, dynamic> json,
) => _RouteGeneratorResponse(
  candidates: (json['candidates'] as List<dynamic>)
      .map((e) => GeneratedRouteDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  partialCoverage: json['partialCoverage'] as bool,
  networkPreparedAt: json['networkPreparedAt'] as String?,
);

Map<String, dynamic> _$RouteGeneratorResponseToJson(
  _RouteGeneratorResponse instance,
) => <String, dynamic>{
  'candidates': instance.candidates.map((e) => e.toJson()).toList(),
  'partialCoverage': instance.partialCoverage,
  'networkPreparedAt': instance.networkPreparedAt,
};
