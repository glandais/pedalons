// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_state_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlannerStateResponse _$PlannerStateResponseFromJson(
  Map<String, dynamic> json,
) => _PlannerStateResponse(
  state: json['state'] == null
      ? null
      : PlannerState.fromJson(json['state'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PlannerStateResponseToJson(
  _PlannerStateResponse instance,
) => <String, dynamic>{'state': instance.state?.toJson()};
