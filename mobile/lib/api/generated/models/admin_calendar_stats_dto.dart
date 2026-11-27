// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_calendar_stats_dto.freezed.dart';
part 'admin_calendar_stats_dto.g.dart';

/// Calendar feeds (iCal subscription links)
@Freezed()
abstract class AdminCalendarStatsDto with _$AdminCalendarStatsDto {
  const factory AdminCalendarStatsDto({
    /// Feeds created
    required int tokens,

    /// Feeds fetched at least once
    required int usedEver,

    /// Feeds fetched during the last 7 days
    required int usedLast7Days,
  }) = _AdminCalendarStatsDto;

  factory AdminCalendarStatsDto.fromJson(Map<String, Object?> json) =>
      _$AdminCalendarStatsDtoFromJson(json);
}
