// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_details_capabilities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteDetailsCapabilities _$RouteDetailsCapabilitiesFromJson(
  Map<String, dynamic> json,
) => _RouteDetailsCapabilities(
  apiVersion: json['api_version'] as String?,
  limits: json['limits'] == null
      ? null
      : Limits.fromJson(json['limits'] as Map<String, dynamic>),
  enums: json['enums'] == null
      ? null
      : Enums.fromJson(json['enums'] as Map<String, dynamic>),
  data: json['data'] == null
      ? null
      : Data.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$RouteDetailsCapabilitiesToJson(
  _RouteDetailsCapabilities instance,
) => <String, dynamic>{
  'api_version': instance.apiVersion,
  'limits': instance.limits?.toJson(),
  'enums': instance.enums?.toJson(),
  'data': instance.data?.toJson(),
};
