// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'retouched_span_dto.freezed.dart';
part 'retouched_span_dto.g.dart';

/// The stretch of a retouched route that changed
@Freezed()
abstract class RetouchedSpanDto with _$RetouchedSpanDto {
  const factory RetouchedSpanDto({
    /// Where on the ORIGINAL route, in metres from its start, the replaced stretch begins
    required double fromM,

    /// Where on the original route the replaced stretch ends; its length for MOVE_END and TRUNCATE (the rest is dropped)
    required double toM,

    /// Length of the new stretch in metres, 0 for TRUNCATE
    required double newM,

    /// Index in the polyline of the first point of the new stretch (up to it the polyline is the original route)
    required int startIndex,

    /// Index in the polyline of the last point of the new stretch
    required int endIndex,

    /// Share of the new stretch on the team's roads, 0 to 1 (measured on that stretch alone)
    required double teamShare,

    /// Share of the new stretch off pavement, 0 to 1 (as the route page)
    required double unpavedShare,

    /// Junctions the new stretch crosses more than once
    required int crossings,
  }) = _RetouchedSpanDto;

  factory RetouchedSpanDto.fromJson(Map<String, Object?> json) =>
      _$RetouchedSpanDtoFromJson(json);
}
