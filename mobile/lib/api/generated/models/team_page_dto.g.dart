// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_page_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamPageDto _$TeamPageDtoFromJson(Map<String, dynamic> json) => _TeamPageDto(
  team: TeamPublicationDto.fromJson(json['team'] as Map<String, dynamic>),
  id: json['id'] as String,
  title: json['title'] as String,
  slug: json['slug'] as String,
  media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
  visibility: json['visibility'] as String,
  order: (json['order'] as num).toInt(),
  deleted: json['deleted'] as bool,
  permissions: ContentPermissionsDto.fromJson(
    json['permissions'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$TeamPageDtoToJson(_TeamPageDto instance) =>
    <String, dynamic>{
      'team': instance.team.toJson(),
      'id': instance.id,
      'title': instance.title,
      'slug': instance.slug,
      'media': instance.media.toJson(),
      'visibility': instance.visibility,
      'order': instance.order,
      'deleted': instance.deleted,
      'permissions': instance.permissions.toJson(),
    };
