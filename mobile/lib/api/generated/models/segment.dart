// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'surface.dart';

part 'segment.freezed.dart';
part 'segment.g.dart';

@Freezed()
abstract class Segment with _$Segment {
  const factory Segment({
    @JsonKey(name: 'from_m') double? fromM,
    @JsonKey(name: 'to_m') double? toM,
    @JsonKey(name: 'from_index') int? fromIndex,
    @JsonKey(name: 'to_index') int? toIndex,
    String? structure,
    @JsonKey(name: 'structure_source') String? structureSource,
    Surface? surface,
    @JsonKey(name: 'way_kind') String? wayKind,
    bool? matched,
  }) = _Segment;

  factory Segment.fromJson(Map<String, Object?> json) =>
      _$SegmentFromJson(json);
}
