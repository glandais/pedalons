// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_quota_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannerQuotaDetails _$PlannerQuotaDetailsFromJson(Map<String, dynamic> json) =>
    _PlannerQuotaDetails(
      type: json['type'] as String,
      scope: json['scope'] as String,
      limit: (json['limit'] as num).toInt(),
      current: (json['current'] as num).toInt(),
      resetsOn: json['resetsOn'] as String,
      teamName: json['teamName'] as String?,
    );

Map<String, dynamic> _$PlannerQuotaDetailsToJson(
  _PlannerQuotaDetails instance,
) => <String, dynamic>{
  'type': instance.type,
  'scope': instance.scope,
  'limit': instance.limit,
  'current': instance.current,
  'resetsOn': instance.resetsOn,
  'teamName': instance.teamName,
};
