// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incompatible_route_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IncompatibleRouteDto _$IncompatibleRouteDtoFromJson(
  Map<String, dynamic> json,
) => _IncompatibleRouteDto(
  slug: json['slug'] as String,
  name: json['name'] as String,
  visibility: json['visibility'] as String,
  proposedVisibility: json['proposedVisibility'] as String,
);

Map<String, dynamic> _$IncompatibleRouteDtoToJson(
  _IncompatibleRouteDto instance,
) => <String, dynamic>{
  'slug': instance.slug,
  'name': instance.name,
  'visibility': instance.visibility,
  'proposedVisibility': instance.proposedVisibility,
};
