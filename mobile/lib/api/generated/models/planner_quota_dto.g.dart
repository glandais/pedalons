// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_quota_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannerQuotaDto _$PlannerQuotaDtoFromJson(Map<String, dynamic> json) =>
    _PlannerQuotaDto(
      used: (json['used'] as num).toInt(),
      resetsOn: json['resetsOn'] as String,
      limit: (json['limit'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PlannerQuotaDtoToJson(_PlannerQuotaDto instance) =>
    <String, dynamic>{
      'used': instance.used,
      'resetsOn': instance.resetsOn,
      'limit': instance.limit,
    };
