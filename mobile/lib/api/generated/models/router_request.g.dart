// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouterRequest _$RouterRequestFromJson(Map<String, dynamic> json) =>
    _RouterRequest(
      from: GeoPoint.fromJson(json['from'] as Map<String, dynamic>),
      to: GeoPoint.fromJson(json['to'] as Map<String, dynamic>),
      profile: RouterProfile.fromJson(json['profile'] as String),
      teamSlug: json['teamSlug'] as String?,
      useHills: (json['useHills'] as num?)?.toDouble(),
      useRoads: (json['useRoads'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$RouterRequestToJson(_RouterRequest instance) =>
    <String, dynamic>{
      'from': instance.from.toJson(),
      'to': instance.to.toJson(),
      'profile': instance.profile.toJson(),
      'teamSlug': instance.teamSlug,
      'useHills': instance.useHills,
      'useRoads': instance.useRoads,
    };
