// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incompatible_visibility_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IncompatibleVisibilityDetails _$IncompatibleVisibilityDetailsFromJson(
  Map<String, dynamic> json,
) => _IncompatibleVisibilityDetails(
  type: json['type'] as String,
  routes: (json['routes'] as List<dynamic>)
      .map((e) => IncompatibleRouteDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  usages: (json['usages'] as List<dynamic>)
      .map((e) => IncompatibleRouteUsageDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$IncompatibleVisibilityDetailsToJson(
  _IncompatibleVisibilityDetails instance,
) => <String, dynamic>{
  'type': instance.type,
  'routes': instance.routes.map((e) => e.toJson()).toList(),
  'usages': instance.usages.map((e) => e.toJson()).toList(),
};
