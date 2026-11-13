// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_details_options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteDetailsOptions _$RouteDetailsOptionsFromJson(Map<String, dynamic> json) =>
    _RouteDetailsOptions(
      profile: json['profile'] == null
          ? null
          : RouteDetailsProfile.fromJson(json['profile'] as String),
      sections: (json['sections'] as List<dynamic>?)
          ?.map((e) => RouteDetailsSection.fromJson(e as String))
          .toList(),
      sampling: json['sampling'] == null
          ? null
          : Sampling.fromJson(json['sampling'] as Map<String, dynamic>),
      elevation: json['elevation'] == null
          ? null
          : Elevation.fromJson(json['elevation'] as Map<String, dynamic>),
      acceptPartial: json['accept_partial'] as bool?,
    );

Map<String, dynamic> _$RouteDetailsOptionsToJson(
  _RouteDetailsOptions instance,
) => <String, dynamic>{
  'profile': instance.profile?.toJson(),
  'sections': instance.sections?.map((e) => e.toJson()).toList(),
  'sampling': instance.sampling?.toJson(),
  'elevation': instance.elevation?.toJson(),
  'accept_partial': instance.acceptPartial,
};
