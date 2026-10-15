// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_template_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideTemplateRequest _$RideTemplateRequestFromJson(
  Map<String, dynamic> json,
) => _RideTemplateRequest(
  name: json['name'] as String,
  markdown: json['markdown'] as String,
  visibility: json['visibility'] as String,
  status: json['status'] as String,
  groups: (json['groups'] as List<dynamic>)
      .map((e) => RideTemplateGroupRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
  tagIds: (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
  nextNumber: (json['nextNumber'] as num?)?.toInt(),
);

Map<String, dynamic> _$RideTemplateRequestToJson(
  _RideTemplateRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'markdown': instance.markdown,
  'visibility': instance.visibility,
  'status': instance.status,
  'groups': instance.groups.map((e) => e.toJson()).toList(),
  'tagIds': instance.tagIds,
  'nextNumber': instance.nextNumber,
};
