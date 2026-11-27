// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_platform_stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminPlatformStatsDto _$AdminPlatformStatsDtoFromJson(
  Map<String, dynamic> json,
) => _AdminPlatformStatsDto(
  generatedAt: json['generatedAt'] as String,
  users: AdminUserStatsDto.fromJson(json['users'] as Map<String, dynamic>),
  authMethods: AdminAuthMethodStatsDto.fromJson(
    json['authMethods'] as Map<String, dynamic>,
  ),
  passkeys: AdminPasskeyStatsDto.fromJson(
    json['passkeys'] as Map<String, dynamic>,
  ),
  signupsByMonth: (json['signupsByMonth'] as List<dynamic>)
      .map((e) => AdminMonthCountDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  teams: AdminTeamStatsDto.fromJson(json['teams'] as Map<String, dynamic>),
  gpsServices: (json['gpsServices'] as List<dynamic>)
      .map((e) => AdminGpsServiceStatsDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  usersWithGpsService: (json['usersWithGpsService'] as num).toInt(),
  pushDevices: (json['pushDevices'] as List<dynamic>)
      .map((e) => AdminPushPlatformStatsDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  clientsLast30Days: (json['clientsLast30Days'] as List<dynamic>)
      .map((e) => AdminKeyCountDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  calendarFeeds: AdminCalendarStatsDto.fromJson(
    json['calendarFeeds'] as Map<String, dynamic>,
  ),
  domainId: json['domainId'] as String?,
);

Map<String, dynamic> _$AdminPlatformStatsDtoToJson(
  _AdminPlatformStatsDto instance,
) => <String, dynamic>{
  'generatedAt': instance.generatedAt,
  'users': instance.users.toJson(),
  'authMethods': instance.authMethods.toJson(),
  'passkeys': instance.passkeys.toJson(),
  'signupsByMonth': instance.signupsByMonth.map((e) => e.toJson()).toList(),
  'teams': instance.teams.toJson(),
  'gpsServices': instance.gpsServices.map((e) => e.toJson()).toList(),
  'usersWithGpsService': instance.usersWithGpsService,
  'pushDevices': instance.pushDevices.map((e) => e.toJson()).toList(),
  'clientsLast30Days': instance.clientsLast30Days
      .map((e) => e.toJson())
      .toList(),
  'calendarFeeds': instance.calendarFeeds.toJson(),
  'domainId': instance.domainId,
};
