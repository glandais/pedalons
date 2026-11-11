// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_permissions_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ContentPermissionsDto _$ContentPermissionsDtoFromJson(
  Map<String, dynamic> json,
) => _ContentPermissionsDto(
  canEdit: json['canEdit'] as bool,
  canDelete: json['canDelete'] as bool,
  indexable: json['indexable'] as bool,
  canRegister: json['canRegister'] as bool?,
  canComment: json['canComment'] as bool?,
  canSeeParticipants: json['canSeeParticipants'] as bool?,
  allowedVisibilities: (json['allowedVisibilities'] as List<dynamic>?)
      ?.map((e) => Visibility.fromJson(e as String))
      .toList(),
);

Map<String, dynamic> _$ContentPermissionsDtoToJson(
  _ContentPermissionsDto instance,
) => <String, dynamic>{
  'canEdit': instance.canEdit,
  'canDelete': instance.canDelete,
  'indexable': instance.indexable,
  'canRegister': instance.canRegister,
  'canComment': instance.canComment,
  'canSeeParticipants': instance.canSeeParticipants,
  'allowedVisibilities': instance.allowedVisibilities
      ?.map((e) => e.toJson())
      .toList(),
};
