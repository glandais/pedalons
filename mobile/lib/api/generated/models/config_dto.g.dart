// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ConfigDto _$ConfigDtoFromJson(Map<String, dynamic> json) => _ConfigDto(
  webAuthnRpId: json['webAuthnRpId'] as String,
  appName: json['appName'] as String,
  singleTeam: json['singleTeam'] as bool,
  enableGpxPlanner: json['enableGpxPlanner'] as bool,
  mapStyles: (json['mapStyles'] as List<dynamic>)
      .map((e) => MapStyleDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  tileServerBaseUrl: json['tileServerBaseUrl'] as String,
  defaultCenter: MapCenterDto.fromJson(
    json['defaultCenter'] as Map<String, dynamic>,
  ),
  gpsAutoSyncEnabled: json['gpsAutoSyncEnabled'] as bool,
  pinnedTeamSlug: json['pinnedTeamSlug'] as String?,
  terrain: json['terrain'] == null
      ? null
      : MapTerrainDto.fromJson(json['terrain'] as Map<String, dynamic>),
  minSupportedAppVersion: json['minSupportedAppVersion'] as String?,
  webPush: json['webPush'] == null
      ? null
      : WebPushConfigDto.fromJson(json['webPush'] as Map<String, dynamic>),
  analytics: json['analytics'] == null
      ? null
      : AnalyticsConfigDto.fromJson(json['analytics'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ConfigDtoToJson(_ConfigDto instance) =>
    <String, dynamic>{
      'webAuthnRpId': instance.webAuthnRpId,
      'appName': instance.appName,
      'singleTeam': instance.singleTeam,
      'enableGpxPlanner': instance.enableGpxPlanner,
      'mapStyles': instance.mapStyles.map((e) => e.toJson()).toList(),
      'tileServerBaseUrl': instance.tileServerBaseUrl,
      'defaultCenter': instance.defaultCenter.toJson(),
      'gpsAutoSyncEnabled': instance.gpsAutoSyncEnabled,
      'pinnedTeamSlug': instance.pinnedTeamSlug,
      'terrain': instance.terrain?.toJson(),
      'minSupportedAppVersion': instance.minSupportedAppVersion,
      'webPush': instance.webPush?.toJson(),
      'analytics': instance.analytics?.toJson(),
    };
