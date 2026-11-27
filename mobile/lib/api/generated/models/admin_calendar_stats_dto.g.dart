// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_calendar_stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminCalendarStatsDto _$AdminCalendarStatsDtoFromJson(
  Map<String, dynamic> json,
) => _AdminCalendarStatsDto(
  tokens: (json['tokens'] as num).toInt(),
  usedEver: (json['usedEver'] as num).toInt(),
  usedLast7Days: (json['usedLast7Days'] as num).toInt(),
);

Map<String, dynamic> _$AdminCalendarStatsDtoToJson(
  _AdminCalendarStatsDto instance,
) => <String, dynamic>{
  'tokens': instance.tokens,
  'usedEver': instance.usedEver,
  'usedLast7Days': instance.usedLast7Days,
};
