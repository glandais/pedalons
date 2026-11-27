// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_auth_method_stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminAuthMethodStatsDto _$AdminAuthMethodStatsDtoFromJson(
  Map<String, dynamic> json,
) => _AdminAuthMethodStatsDto(
  passwordOnly: (json['passwordOnly'] as num).toInt(),
  passkeyOnly: (json['passkeyOnly'] as num).toInt(),
  passwordAndPasskey: (json['passwordAndPasskey'] as num).toInt(),
  neither: (json['neither'] as num).toInt(),
);

Map<String, dynamic> _$AdminAuthMethodStatsDtoToJson(
  _AdminAuthMethodStatsDto instance,
) => <String, dynamic>{
  'passwordOnly': instance.passwordOnly,
  'passkeyOnly': instance.passkeyOnly,
  'passwordAndPasskey': instance.passwordAndPasskey,
  'neither': instance.neither,
};
