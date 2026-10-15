// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_template_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideTemplateDto _$RideTemplateDtoFromJson(Map<String, dynamic> json) =>
    _RideTemplateDto(
      team: TeamPublicationDto.fromJson(json['team'] as Map<String, dynamic>),
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      markdown: json['markdown'] as String,
      visibility: json['visibility'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      groupCount: (json['groupCount'] as num).toInt(),
      groups: (json['groups'] as List<dynamic>)
          .map((e) => RideTemplateGroupDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>)
          .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextNumber: (json['nextNumber'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RideTemplateDtoToJson(_RideTemplateDto instance) =>
    <String, dynamic>{
      'team': instance.team.toJson(),
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'markdown': instance.markdown,
      'visibility': instance.visibility,
      'status': instance.status,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'groupCount': instance.groupCount,
      'groups': instance.groups.map((e) => e.toJson()).toList(),
      'tags': instance.tags.map((e) => e.toJson()).toList(),
      'nextNumber': instance.nextNumber,
    };
