// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ad_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdDto _$AdDtoFromJson(Map<String, dynamic> json) => _AdDto(
  team: TeamPublicationDto.fromJson(json['team'] as Map<String, dynamic>),
  id: json['id'] as String,
  slug: json['slug'] as String,
  name: json['name'] as String,
  media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
  images: (json['images'] as List<dynamic>).map((e) => e as String).toList(),
  status: json['status'] as String,
  visibility: json['visibility'] as String,
  adType: json['adType'] as String,
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String,
  createdById: json['createdById'] as String,
  createdByDisplayName: json['createdByDisplayName'] as String,
  deleted: json['deleted'] as bool,
  tags: (json['tags'] as List<dynamic>)
      .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  permissions: ContentPermissionsDto.fromJson(
    json['permissions'] as Map<String, dynamic>,
  ),
  excerpt: json['excerpt'] as String?,
  thumbnailUrl: json['thumbnailUrl'] as String?,
  price: json['price'] as num?,
  rentalPeriod: json['rentalPeriod'] as String?,
  locationDescription: json['locationDescription'] as String?,
  locationGeometry: json['locationGeometry'] == null
      ? null
      : AdDtoLocationGeometry.fromJson(
          json['locationGeometry'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$AdDtoToJson(_AdDto instance) => <String, dynamic>{
  'team': instance.team.toJson(),
  'id': instance.id,
  'slug': instance.slug,
  'name': instance.name,
  'media': instance.media.toJson(),
  'images': instance.images,
  'status': instance.status,
  'visibility': instance.visibility,
  'adType': instance.adType,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'createdById': instance.createdById,
  'createdByDisplayName': instance.createdByDisplayName,
  'deleted': instance.deleted,
  'tags': instance.tags.map((e) => e.toJson()).toList(),
  'permissions': instance.permissions.toJson(),
  'excerpt': instance.excerpt,
  'thumbnailUrl': instance.thumbnailUrl,
  'price': instance.price,
  'rentalPeriod': instance.rentalPeriod,
  'locationDescription': instance.locationDescription,
  'locationGeometry': instance.locationGeometry?.toJson(),
};
