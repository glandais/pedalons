// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'terrain_range.freezed.dart';
part 'terrain_range.g.dart';

@Freezed()
abstract class TerrainRange with _$TerrainRange {
  const factory TerrainRange({
    @JsonKey(name: 'from_m') double? fromM,
    @JsonKey(name: 'to_m') double? toM,
    String? origin,
    bool? measured,
    @JsonKey(name: 'fallback_after_error') bool? fallbackAfterError,
  }) = _TerrainRange;

  factory TerrainRange.fromJson(Map<String, Object?> json) =>
      _$TerrainRangeFromJson(json);
}
