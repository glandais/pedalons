// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_date.dart';

part 'planner_quota_dto.freezed.dart';
part 'planner_quota_dto.g.dart';

/// Saves of a drawn track this calendar month, against the plan's quota
@Freezed()
abstract class PlannerQuotaDto with _$PlannerQuotaDto {
  const factory PlannerQuotaDto({
    /// Saves of a drawn track counted this month
    required int used,

    /// The day the count starts again: the first day of next month, in the team's zone for a team, in UTC for the personal quota
    required String resetsOn,

    /// Saves of a drawn track allowed per calendar month; null when unlimited
    int? limit,
  }) = _PlannerQuotaDto;

  factory PlannerQuotaDto.fromJson(Map<String, Object?> json) =>
      _$PlannerQuotaDtoFromJson(json);
}
