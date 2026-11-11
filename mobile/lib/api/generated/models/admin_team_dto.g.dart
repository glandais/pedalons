// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_team_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminTeamDto _$AdminTeamDtoFromJson(Map<String, dynamic> json) =>
    _AdminTeamDto(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      domainId: json['domainId'] as String,
      domainName: json['domainName'] as String,
      visibility: json['visibility'] as String,
      visibilityEditable: json['visibilityEditable'] as bool,
      joinable: json['joinable'] as bool,
      addMemberAllowed: json['addMemberAllowed'] as bool,
      enableRoutePlanner: json['enableRoutePlanner'] as bool,
      publicContentAllowed: json['publicContentAllowed'] as bool,
      tier: json['tier'] as String,
      deleted: json['deleted'] as bool,
      memberCount: (json['memberCount'] as num).toInt(),
      createdAt: json['createdAt'] as String,
      tierNote: json['tierNote'] as String?,
    );

Map<String, dynamic> _$AdminTeamDtoToJson(_AdminTeamDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'domainId': instance.domainId,
      'domainName': instance.domainName,
      'visibility': instance.visibility,
      'visibilityEditable': instance.visibilityEditable,
      'joinable': instance.joinable,
      'addMemberAllowed': instance.addMemberAllowed,
      'enableRoutePlanner': instance.enableRoutePlanner,
      'publicContentAllowed': instance.publicContentAllowed,
      'tier': instance.tier,
      'deleted': instance.deleted,
      'memberCount': instance.memberCount,
      'createdAt': instance.createdAt,
      'tierNote': instance.tierNote,
    };
