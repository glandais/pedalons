// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_generator_network_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteGeneratorNetworkDto _$RouteGeneratorNetworkDtoFromJson(
  Map<String, dynamic> json,
) => _RouteGeneratorNetworkDto(
  totalLengthM: (json['totalLengthM'] as num).toDouble(),
  routeCount: (json['routeCount'] as num).toInt(),
  pendingRouteCount: (json['pendingRouteCount'] as num).toInt(),
  excludedRouteCount: (json['excludedRouteCount'] as num).toInt(),
  incomplete: json['incomplete'] as bool,
  lengthM: (json['lengthM'] as num?)?.toDouble(),
);

Map<String, dynamic> _$RouteGeneratorNetworkDtoToJson(
  _RouteGeneratorNetworkDto instance,
) => <String, dynamic>{
  'totalLengthM': instance.totalLengthM,
  'routeCount': instance.routeCount,
  'pendingRouteCount': instance.pendingRouteCount,
  'excludedRouteCount': instance.excludedRouteCount,
  'incomplete': instance.incomplete,
  'lengthM': instance.lengthM,
};
