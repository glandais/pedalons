// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Meta _$MetaFromJson(Map<String, dynamic> json) => _Meta(
  apiVersion: json['api_version'] as String?,
  rulesVersion: json['rules_version'] as String?,
  profile: json['profile'] as String?,
  dataVersions: json['data_versions'] == null
      ? null
      : JsonNode.fromJson(json['data_versions'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MetaToJson(_Meta instance) => <String, dynamic>{
  'api_version': instance.apiVersion,
  'rules_version': instance.rulesVersion,
  'profile': instance.profile,
  'data_versions': instance.dataVersions?.toJson(),
};
