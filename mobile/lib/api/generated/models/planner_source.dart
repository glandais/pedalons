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

    /// One-dimension polyline (tenths of a metre), one value per point of line: the ascent accumulated up to each point, as the server measured it (dead-band, non-decreasing, within [0, 100 000 m]). Absent: the client derives it from ele. Requires ele
    String? climb,

    /// Polyline (precision 6, latitude then longitude) of the raw track of the file, as GpxImportTrack.shape gave it, never edited. An imported piece is cut out of it by projecting its junctions (from and to still index line); absent or inconsistent with line: line
    String? shape,
  }) = _PlannerSource;

  factory PlannerSource.fromJson(Map<String, Object?> json) =>
      _$PlannerSourceFromJson(json);
}
