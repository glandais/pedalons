// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_route_sync_status_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceRouteSyncStatusDto _$DeviceRouteSyncStatusDtoFromJson(
  Map<String, dynamic> json,
) => _DeviceRouteSyncStatusDto(
  serviceType: json['serviceType'] as String,
  state: json['state'] as String,
);

Map<String, dynamic> _$DeviceRouteSyncStatusDtoToJson(
  _DeviceRouteSyncStatusDto instance,
) => <String, dynamic>{
  'serviceType': instance.serviceType,
  'state': instance.state,
};
