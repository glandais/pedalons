// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_routes_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceRoutesResponse _$DeviceRoutesResponseFromJson(
  Map<String, dynamic> json,
) => _DeviceRoutesResponse(
  rides: (json['rides'] as List<dynamic>)
      .map((e) => DeviceRideDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  routes: (json['routes'] as List<dynamic>)
      .map((e) => DeviceRouteDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  registeredGroups: (json['registeredGroups'] as List<dynamic>)
      .map((e) => DeviceRegisteredGroupDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DeviceRoutesResponseToJson(
  _DeviceRoutesResponse instance,
) => <String, dynamic>{
  'rides': instance.rides.map((e) => e.toJson()).toList(),
  'routes': instance.routes.map((e) => e.toJson()).toList(),
  'registeredGroups': instance.registeredGroups.map((e) => e.toJson()).toList(),
};
