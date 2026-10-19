// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'planner_junction_kind.dart';

part 'planner_junction.freezed.dart';
part 'planner_junction.g.dart';

@Freezed()
abstract class PlannerJunction with _$PlannerJunction {
  const factory PlannerJunction({
    required PlannerJunctionKind kind,
    required double lng,
    required double lat,
    double? ele,

    /// Index of the source track this point comes from; with idx or not at all
    int? source,

    /// Index of this point in that source track
    int? idx,
  }) = _PlannerJunction;

  factory PlannerJunction.fromJson(Map<String, Object?> json) =>
      _$PlannerJunctionFromJson(json);
}
