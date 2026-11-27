// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_push_platform_stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminPushPlatformStatsDto _$AdminPushPlatformStatsDtoFromJson(
  Map<String, dynamic> json,
) => _AdminPushPlatformStatsDto(
  platform: json['platform'] as String,
  devices: (json['devices'] as num).toInt(),
  users: (json['users'] as num).toInt(),
  seenLast7Days: (json['seenLast7Days'] as num).toInt(),
);

Map<String, dynamic> _$AdminPushPlatformStatsDtoToJson(
  _AdminPushPlatformStatsDto instance,
) => <String, dynamic>{
  'platform': instance.platform,
  'devices': instance.devices,
  'users': instance.users,
  'seenLast7Days': instance.seenLast7Days,
};
