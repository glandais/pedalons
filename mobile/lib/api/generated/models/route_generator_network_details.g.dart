// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_generator_network_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteGeneratorNetworkDetails _$RouteGeneratorNetworkDetailsFromJson(
  Map<String, dynamic> json,
) => _RouteGeneratorNetworkDetails(
  type: json['type'] as String,
  routeCount: (json['routeCount'] as num).toInt(),
  pendingRouteCount: (json['pendingRouteCount'] as num).toInt(),
  excludedRouteCount: (json['excludedRouteCount'] as num).toInt(),
  totalLengthM: (json['totalLengthM'] as num).toDouble(),
  incomplete: json['incomplete'] as bool,
);

Map<String, dynamic> _$RouteGeneratorNetworkDetailsToJson(
  _RouteGeneratorNetworkDetails instance,
) => <String, dynamic>{
  'type': instance.type,
  'routeCount': instance.routeCount,
  'pendingRouteCount': instance.pendingRouteCount,
  'excludedRouteCount': instance.excludedRouteCount,
  'totalLengthM': instance.totalLengthM,
  'incomplete': instance.incomplete,
};
