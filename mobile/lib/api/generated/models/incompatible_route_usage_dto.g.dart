// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incompatible_route_usage_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IncompatibleRouteUsageDto _$IncompatibleRouteUsageDtoFromJson(
  Map<String, dynamic> json,
) => _IncompatibleRouteUsageDto(
  type: json['type'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  visibility: json['visibility'] as String,
);

Map<String, dynamic> _$IncompatibleRouteUsageDtoToJson(
  _IncompatibleRouteUsageDto instance,
) => <String, dynamic>{
  'type': instance.type,
  'slug': instance.slug,
  'name': instance.name,
  'visibility': instance.visibility,
};
