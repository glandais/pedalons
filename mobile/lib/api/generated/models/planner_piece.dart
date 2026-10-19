// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'planner_piece_mode.dart';

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
  }) = _PlannerPiece;

  factory PlannerPiece.fromJson(Map<String, Object?> json) =>
      _$PlannerPieceFromJson(json);
}
