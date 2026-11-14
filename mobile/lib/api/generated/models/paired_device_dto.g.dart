// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paired_device_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PairedDeviceDto _$PairedDeviceDtoFromJson(Map<String, dynamic> json) =>
    _PairedDeviceDto(
      id: json['id'] as String,
      type: json['type'] as String,
      pairedAt: json['pairedAt'] as String,
      applicationName: json['applicationName'] as String?,
      lastUsedAt: json['lastUsedAt'] as String?,
    );

Map<String, dynamic> _$PairedDeviceDtoToJson(_PairedDeviceDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'pairedAt': instance.pairedAt,
      'applicationName': instance.applicationName,
      'lastUsedAt': instance.lastUsedAt,
    };
