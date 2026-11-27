// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_passkey_stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminPasskeyStatsDto _$AdminPasskeyStatsDtoFromJson(
  Map<String, dynamic> json,
) => _AdminPasskeyStatsDto(
  total: (json['total'] as num).toInt(),
  usedLast30Days: (json['usedLast30Days'] as num).toInt(),
);

Map<String, dynamic> _$AdminPasskeyStatsDtoToJson(
  _AdminPasskeyStatsDto instance,
) => <String, dynamic>{
  'total': instance.total,
  'usedLast30Days': instance.usedLast30Days,
};
