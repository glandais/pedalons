// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserDto _$UserDtoFromJson(Map<String, dynamic> json) => _UserDto(
  id: json['id'] as String,
  email: json['email'] as String,
  displayName: json['displayName'] as String,
  contactableByMembers: json['contactableByMembers'] as bool,
  emailVerified: json['emailVerified'] as bool,
  plannerQuota: PlannerQuotaDto.fromJson(
    json['plannerQuota'] as Map<String, dynamic>,
  ),
  avatarUrl: json['avatarUrl'] as String?,
  createdAt: json['createdAt'] as String?,
  unitSystem: json['unitSystem'] as String?,
  theme: json['theme'] as String?,
  language: json['language'] as String?,
  timezone: json['timezone'] as String?,
  platformRole: json['platformRole'] as String?,
  connectedServices: (json['connectedServices'] as List<dynamic>?)
      ?.map((e) => GpsServiceConnectionDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$UserDtoToJson(_UserDto instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'displayName': instance.displayName,
  'contactableByMembers': instance.contactableByMembers,
  'emailVerified': instance.emailVerified,
  'plannerQuota': instance.plannerQuota.toJson(),
  'avatarUrl': instance.avatarUrl,
  'createdAt': instance.createdAt,
  'unitSystem': instance.unitSystem,
  'theme': instance.theme,
  'language': instance.language,
  'timezone': instance.timezone,
  'platformRole': instance.platformRole,
  'connectedServices': instance.connectedServices
      ?.map((e) => e.toJson())
      .toList(),
};
