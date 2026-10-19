// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'planner_source.freezed.dart';
part 'planner_source.g.dart';

@Freezed()
abstract class PlannerSource with _$PlannerSource {
  const factory PlannerSource({
    /// Polyline (precision 6, latitude then longitude) of the source track
    required String line,

    /// Factor that recalibrates the raw climb of the source on a reference ascent (1 without reference); in ]0, 100]
    required double ascendScale,

    /// One-dimension polyline (tenths of a metre), one value per point of line; absent: no elevation
    String? ele,
  }) = _PlannerSource;

  factory PlannerSource.fromJson(Map<String, Object?> json) =>
      _$PlannerSourceFromJson(json);
}
