// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_team_stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminTeamStatsDto _$AdminTeamStatsDtoFromJson(Map<String, dynamic> json) =>
    _AdminTeamStatsDto(
      active: (json['active'] as num).toInt(),
      deleted: (json['deleted'] as num).toInt(),
      byTier: (json['byTier'] as List<dynamic>)
          .map((e) => AdminKeyCountDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      membershipsByRole: (json['membershipsByRole'] as List<dynamic>)
          .map((e) => AdminKeyCountDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      usersByTeamCount: (json['usersByTeamCount'] as List<dynamic>)
          .map((e) => AdminKeyCountDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AdminTeamStatsDtoToJson(
  _AdminTeamStatsDto instance,
) => <String, dynamic>{
  'active': instance.active,
  'deleted': instance.deleted,
  'byTier': instance.byTier.map((e) => e.toJson()).toList(),
  'membershipsByRole': instance.membershipsByRole
      .map((e) => e.toJson())
      .toList(),
  'usersByTeamCount': instance.usersByTeamCount.map((e) => e.toJson()).toList(),
};
