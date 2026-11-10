// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_gps_sync_status_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteGpsSyncStatusDto _$RouteGpsSyncStatusDtoFromJson(
  Map<String, dynamic> json,
) => _RouteGpsSyncStatusDto(
  serviceType: json['serviceType'] as String,
  state: json['state'] as String,
  syncedAt: json['syncedAt'] as String?,
);

Map<String, dynamic> _$RouteGpsSyncStatusDtoToJson(
  _RouteGpsSyncStatusDto instance,
) => <String, dynamic>{
  'serviceType': instance.serviceType,
  'state': instance.state,
  'syncedAt': instance.syncedAt,
};
