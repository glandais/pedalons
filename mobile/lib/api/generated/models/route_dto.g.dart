// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteDto _$RouteDtoFromJson(Map<String, dynamic> json) => _RouteDto(
  id: json['id'] as String,
  slug: json['slug'] as String,
  team: TeamPublicationDto.fromJson(json['team'] as Map<String, dynamic>),
  name: json['name'] as String,
  media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
  distance: (json['distance'] as num).toDouble(),
  elevationGain: (json['elevationGain'] as num).toDouble(),
  elevationLoss: (json['elevationLoss'] as num).toDouble(),
  elevationState: json['elevationState'] as String,
  surfaceType: json['surfaceType'] as String,
  visibility: json['visibility'] as String,
  createdAt: json['createdAt'] as String,
  deleted: json['deleted'] as bool,
  tags: (json['tags'] as List<dynamic>)
      .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  excerpt: json['excerpt'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  commentCount: (json['commentCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$RouteDtoToJson(_RouteDto instance) => <String, dynamic>{
  'id': instance.id,
  'slug': instance.slug,
  'team': instance.team.toJson(),
  'name': instance.name,
  'media': instance.media.toJson(),
  'distance': instance.distance,
  'elevationGain': instance.elevationGain,
  'elevationLoss': instance.elevationLoss,
  'elevationState': instance.elevationState,
  'surfaceType': instance.surfaceType,
  'visibility': instance.visibility,
  'createdAt': instance.createdAt,
  'deleted': instance.deleted,
  'tags': instance.tags.map((e) => e.toJson()).toList(),
  'excerpt': instance.excerpt,
  'thumbnailUrl': instance.thumbnailUrl,
  'commentCount': instance.commentCount,
};
