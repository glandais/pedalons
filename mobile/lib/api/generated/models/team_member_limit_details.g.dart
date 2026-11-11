// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_member_limit_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamMemberLimitDetails _$TeamMemberLimitDetailsFromJson(
  Map<String, dynamic> json,
) => _TeamMemberLimitDetails(
  type: json['type'] as String,
  limit: (json['limit'] as num).toInt(),
  current: (json['current'] as num).toInt(),
);

Map<String, dynamic> _$TeamMemberLimitDetailsToJson(
  _TeamMemberLimitDetails instance,
) => <String, dynamic>{
  'type': instance.type,
  'limit': instance.limit,
  'current': instance.current,
};
