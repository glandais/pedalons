// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PostDto _$PostDtoFromJson(Map<String, dynamic> json) => _PostDto(
  type: json['type'] as String,
  team: TeamPublicationDto.fromJson(json['team'] as Map<String, dynamic>),
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
  dateTime: json['dateTime'] as String,
  timezone: json['timezone'] as String,
  status: json['status'] as String,
  visibility: json['visibility'] as String,
  deleted: json['deleted'] as bool,
  signedAsTeam: json['signedAsTeam'] as bool,
  tags: (json['tags'] as List<dynamic>)
      .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  permissions: ContentPermissionsDto.fromJson(
    json['permissions'] as Map<String, dynamic>,
  ),
  excerpt: json['excerpt'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  publishAt: json['publishAt'] as String?,
  createdAt: json['createdAt'] as String?,
  commentCount: (json['commentCount'] as num?)?.toInt(),
  createdBy: json['createdBy'] == null
      ? null
      : PublicUserDto.fromJson(json['createdBy'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PostDtoToJson(_PostDto instance) => <String, dynamic>{
  'type': instance.type,
  'team': instance.team.toJson(),
  'id': instance.id,
  'slug': instance.slug,
  'name': instance.name,
  'media': instance.media.toJson(),
  'dateTime': instance.dateTime,
  'timezone': instance.timezone,
  'status': instance.status,
  'visibility': instance.visibility,
  'deleted': instance.deleted,
  'signedAsTeam': instance.signedAsTeam,
  'tags': instance.tags.map((e) => e.toJson()).toList(),
  'permissions': instance.permissions.toJson(),
  'excerpt': instance.excerpt,
  'thumbnailUrl': instance.thumbnailUrl,
  'publishAt': instance.publishAt,
  'createdAt': instance.createdAt,
  'commentCount': instance.commentCount,
  'createdBy': instance.createdBy?.toJson(),
};
