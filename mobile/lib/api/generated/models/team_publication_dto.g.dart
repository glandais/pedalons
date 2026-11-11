// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_publication_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamPublicationDto _$TeamPublicationDtoFromJson(Map<String, dynamic> json) =>
    _TeamPublicationDto(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      visibility: json['visibility'] as String,
      accessible: json['accessible'] as bool,
      logoUrl: json['logoUrl'] as String?,
    );

Map<String, dynamic> _$TeamPublicationDtoToJson(_TeamPublicationDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'visibility': instance.visibility,
      'accessible': instance.accessible,
      'logoUrl': instance.logoUrl,
    };
