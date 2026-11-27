// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_gps_service_stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminGpsServiceStatsDto _$AdminGpsServiceStatsDtoFromJson(
  Map<String, dynamic> json,
) => _AdminGpsServiceStatsDto(
  service: json['service'] as String,
  connections: (json['connections'] as num).toInt(),
  users: (json['users'] as num).toInt(),
  autoSync: (json['autoSync'] as num).toInt(),
  reconnectRequired: (json['reconnectRequired'] as num).toInt(),
  usedLast30Days: (json['usedLast30Days'] as num).toInt(),
  routeSyncs: (json['routeSyncs'] as num).toInt(),
  routeSyncsSucceeded: (json['routeSyncsSucceeded'] as num).toInt(),
  routeSyncsFailed: (json['routeSyncsFailed'] as num).toInt(),
);

Map<String, dynamic> _$AdminGpsServiceStatsDtoToJson(
  _AdminGpsServiceStatsDto instance,
) => <String, dynamic>{
  'service': instance.service,
  'connections': instance.connections,
  'users': instance.users,
  'autoSync': instance.autoSync,
  'reconnectRequired': instance.reconnectRequired,
  'usedLast30Days': instance.usedLast30Days,
  'routeSyncs': instance.routeSyncs,
  'routeSyncsSucceeded': instance.routeSyncsSucceeded,
  'routeSyncsFailed': instance.routeSyncsFailed,
};
