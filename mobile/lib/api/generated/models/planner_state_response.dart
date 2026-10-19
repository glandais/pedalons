// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'planner_state.dart';

part 'planner_state_response.freezed.dart';
part 'planner_state_response.g.dart';

/// Editing state of the planner of a route or a preview, if any
@Freezed()
abstract class PlannerStateResponse with _$PlannerStateResponse {
  const factory PlannerStateResponse({
    /// The state; absent when there is none to read back
    PlannerState? state,
  }) = _PlannerStateResponse;

  factory PlannerStateResponse.fromJson(Map<String, Object?> json) =>
      _$PlannerStateResponseFromJson(json);
}
