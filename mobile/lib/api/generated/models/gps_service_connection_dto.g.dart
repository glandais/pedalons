// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gps_service_connection_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GpsServiceConnectionDto _$GpsServiceConnectionDtoFromJson(
  Map<String, dynamic> json,
) => _GpsServiceConnectionDto(
  serviceType: json['serviceType'] as String,
  displayName: json['displayName'] as String,
  connectedAt: json['connectedAt'] as String,
  autoSync: json['autoSync'] as bool,
  autoSyncState: json['autoSyncState'] as String,
  autoSyncRouteCount: (json['autoSyncRouteCount'] as num).toInt(),
  lastAutoSyncAt: json['lastAutoSyncAt'] as String?,
);

Map<String, dynamic> _$GpsServiceConnectionDtoToJson(
  _GpsServiceConnectionDto instance,
) => <String, dynamic>{
  'serviceType': instance.serviceType,
  'displayName': instance.displayName,
  'connectedAt': instance.connectedAt,
  'autoSync': instance.autoSync,
  'autoSyncState': instance.autoSyncState,
  'autoSyncRouteCount': instance.autoSyncRouteCount,
  'lastAutoSyncAt': instance.lastAutoSyncAt,
};
