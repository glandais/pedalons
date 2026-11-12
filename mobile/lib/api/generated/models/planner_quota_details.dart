// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'error_code.dart';
import 'error_details.dart';
import 'local_date.dart';
import 'planner_quota_scope.dart';

part 'planner_quota_details.freezed.dart';
part 'planner_quota_details.g.dart';

@Freezed()
abstract class PlannerQuotaDetails with _$PlannerQuotaDetails {
  const factory PlannerQuotaDetails({
    /// Type
    required String type,

    /// TEAM: the team is on the free plan and its monthly saves are spent. PERSONAL: the caller is a member of no unlocked team and their monthly saves in the GPX tools are spent.
    required String scope,

    /// Saves of a drawn track allowed per calendar month
    required int limit,

    /// Saves already counted this month
    required int current,

    /// The day the count starts again: the first day of next month, in the team's zone for TEAM, in UTC for PERSONAL
    required String resetsOn,

    /// Name of the team, for TEAM only
    String? teamName,
  }) = _PlannerQuotaDetails;

  factory PlannerQuotaDetails.fromJson(Map<String, Object?> json) =>
      _$PlannerQuotaDetailsFromJson(json);
}
