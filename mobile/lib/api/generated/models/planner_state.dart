// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'planner_junction.dart';
import 'planner_piece.dart';
import 'planner_source.dart';
import 'router_profile.dart';

part 'planner_state.freezed.dart';
part 'planner_state.g.dart';

/// Editing state of the route planner
@Freezed()
abstract class PlannerState with _$PlannerState {
  const factory PlannerState({
    required int version,
    required RouterProfile profile,
    required List<PlannerSource> sources,
    required List<PlannerJunction> junctions,
    required List<PlannerPiece> pieces,
  }) = _PlannerState;

  factory PlannerState.fromJson(Map<String, Object?> json) =>
      _$PlannerStateFromJson(json);
}
