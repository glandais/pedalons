// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_template_group_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RideTemplateGroupDto _$RideTemplateGroupDtoFromJson(
  Map<String, dynamic> json,
) => _RideTemplateGroupDto(
  id: json['id'] as String,
  name: json['name'] as String,
  sortOrder: (json['sortOrder'] as num).toInt(),
  time: json['time'] as LocalTime?,
  averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
  maxParticipants: (json['maxParticipants'] as num?)?.toInt(),
);

Map<String, dynamic> _$RideTemplateGroupDtoToJson(
  _RideTemplateGroupDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'sortOrder': instance.sortOrder,
  'time': instance.time,
  'averageSpeed': instance.averageSpeed,
  'maxParticipants': instance.maxParticipants,
};
