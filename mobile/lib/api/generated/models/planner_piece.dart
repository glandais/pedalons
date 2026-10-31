// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'planner_piece_mode.dart';
import 'unpaved_span.dart';

part 'planner_piece.freezed.dart';
part 'planner_piece.g.dart';

@Freezed()
abstract class PlannerPiece with _$PlannerPiece {
  const factory PlannerPiece({
    required PlannerPieceMode mode,

    /// ROUTED and DIRECT: polyline6 of the points strictly inside the piece
    String? line,

    /// ROUTED and DIRECT: one-dimension polyline of their elevations
    String? ele,

    /// ROUTED: climb of the piece in metres
    double? ascend,

    /// IMPORTED: index of the source track
    int? source,

    /// IMPORTED: index in the source of the first junction
    int? from,

    /// IMPORTED: index in the source of the last junction
    int? to,

    /// ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown
    List<UnpavedSpan>? unpaved,

    /// ROUTED: polyline6 of the router's raw geometry of the piece, RouterResponse.shape as the router answered it, never edited (its two ends may be kept: a point within 1 m of a junction is dropped). The saved track is derived from it rather than from line; absent or inconsistent with line (ends over 50 m from the junctions, length off by over 20 % + 200 m): line. Unpaved spans keep indexing the edges of line
    String? shape,
  }) = _PlannerPiece;

  factory PlannerPiece.fromJson(Map<String, Object?> json) =>
      _$PlannerPieceFromJson(json);
}
